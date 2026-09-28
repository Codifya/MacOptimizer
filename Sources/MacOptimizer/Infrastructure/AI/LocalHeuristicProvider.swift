import Foundation

/// 100% Offline, zero-network rule-based diagnostic and intelligence provider.
public struct LocalHeuristicProvider: AIProvider {
    public let providerId: String = "local_heuristics"
    public let displayName: String = L10n.string("Local Rule Engine (100% Offline & Secure)", table: .ai)
    public let requiresNetwork: Bool = false

    /// Telemetry shown to the user in offline replies. The English cloud snapshot is model input only.
    public struct SystemSnapshot: Sendable {
        public let hardware: HardwareInfo
        public let memory: MemoryStats
        public let cpu: CPUStats
        public let disk: DiskStats

        public init(hardware: HardwareInfo, memory: MemoryStats, cpu: CPUStats, disk: DiskStats) {
            self.hardware = hardware
            self.memory = memory
            self.cpu = cpu
            self.disk = disk
        }
    }

    private let snapshot: SystemSnapshot?

    public init(snapshot: SystemSnapshot? = nil) {
        self.snapshot = snapshot
    }

    /// Localized system summary for the user (never the English cloud snapshot text).
    static func localizedSummary(_ snapshot: SystemSnapshot) -> String {
        [
            L10n.string("Mac model: %@ (%@), macOS version: %@", table: .ai,
                        snapshot.hardware.modelName, snapshot.hardware.chipName, snapshot.hardware.osVersion),
            L10n.string("RAM: %lld%%", table: .ai, Int(snapshot.memory.usedPercentage * 100)),
            L10n.string("CPU: %@%%, Free disk: %lld%%", table: .ai,
                        String(format: "%.1f", snapshot.cpu.totalUsage), Int(snapshot.disk.freePercentage * 100))
        ].joined(separator: "\n")
    }

    public func diagnose(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        hardware: HardwareInfo,
        topProcesses: [ProcessInfoModel],
        junkGroups: [JunkCategoryGroup],
        outdatedAppsCount: Int
    ) async -> [AIInsight] {
        var insights: [AIInsight] = []
        let heaviestApps = topProcesses.filter { $0.isUserApp && !$0.isProtected }.prefix(3)
        let memoryAdvice = heaviestApps.isEmpty
            ? L10n.string("Try closing the apps using the most memory.", table: .ai)
            : L10n.string("To reduce memory usage, try closing these heavy apps: %@.", table: .ai, heaviestApps.map { "\($0.name) (\($0.memoryFormatted))" }.joined(separator: ", "))
        
        // 1. Memory Pressure Evaluation
        if memory.pressureLevel == .critical || memory.usedPercentage > 0.88 {
            insights.append(AIInsight(
                title: L10n.string("Critical Memory Pressure Detected", table: .ai),
                summary: L10n.string("RAM usage is at %lld%%. %@", table: .ai, Int(memory.usedPercentage * 100), memoryAdvice),
                severity: .critical,
                category: "RAM",
                actions: []
            ))
        } else if memory.pressureLevel == .warning || memory.usedPercentage > 0.75 {
            insights.append(AIInsight(
                title: L10n.string("Moderate Memory Load", table: .ai),
                summary: L10n.string("Memory usage is %lld%%. %@", table: .ai, Int(memory.usedPercentage * 100), memoryAdvice),
                severity: .warning,
                category: "RAM",
                actions: []
            ))
        }
        
        // 2. High CPU / Runaway Process Evaluation
        let heavyProcs = topProcesses.filter { $0.cpuPercentage > 75.0 && !$0.isProtected }
        if let runaway = heavyProcs.first {
            insights.append(AIInsight(
                title: L10n.string("High CPU Process: %@", table: .ai, runaway.name),
                summary: L10n.string("%@ (PID: %d) alone is using CPU at %@%%. This can cause fan noise and fast battery drain.", table: .ai, runaway.name, runaway.pid, String(format: "%.1f", runaway.cpuPercentage)),
                severity: .warning,
                category: L10n.string("CPU", table: .ai),
                actions: [
                    AIAction(title: L10n.string("Quit %@", table: .ai, runaway.name), type: .killProcess, targetPID: runaway.pid)
                ]
            ))
        }
        
        // 3. Disk Storage & Junk Evaluation
        let totalJunk = junkGroups.reduce(0) { $0 + $1.totalSizeBytes }
        if totalJunk > 3 * 1024 * 1024 * 1024 {
            insights.append(AIInsight(
                title: L10n.string("%@ of Unneeded Cache Buildup", table: .ai, ByteFormatter.format(totalJunk)),
                summary: L10n.string("A significant amount of reclaimable space was found in Xcode DerivedData, system logs, and browser caches.", table: .ai),
                severity: .recommendation,
                category: L10n.string("Disk", table: .ai),
                actions: [
                    AIAction(title: L10n.string("Clean Junk Files", table: .ai), type: .cleanJunk)
                ]
            ))
        }
        
        // 4. Software Updates
        if outdatedAppsCount > 0 {
            insights.append(AIInsight(
                title: L10n.string("%lld App Updates Available", table: .ai, outdatedAppsCount),
                summary: L10n.string("New versions of your installed apps have been released. Updating is recommended for the latest security patches and performance improvements.", table: .ai),
                severity: .info,
                category: L10n.string("Software", table: .ai),
                actions: [
                    AIAction(title: L10n.string("Review Updates", table: .ai), type: .checkUpdates)
                ]
            ))
        }
        
        // 5. Default Healthy State
        if insights.isEmpty {
            insights.append(AIInsight(
                title: L10n.string("Your Mac Is in Great Shape", table: .ai),
                summary: L10n.string("Memory pressure is normal, there is no unusual runaway CPU process, and your disk space is balanced.", table: .ai),
                severity: .info,
                category: L10n.string("General", table: .ai)
            ))
        }
        
        return insights
    }
    
    public func queryCopilot(
        messages: [AIChatMessage],
        snapshotContext: String
    ) async throws -> String {
        guard let lastUserMsg = messages.last(where: { $0.role == .user })?.content.lowercased() else {
            return L10n.string("How can I help you?", table: .ai)
        }
        
        // Keyword lists cover both Turkish and English user input.
        if lastUserMsg.contains("ram") || lastUserMsg.contains("bellek") || lastUserMsg.contains("memory") {
            // `snapshotContext` is the English cloud model input; the user sees the localized summary instead.
            guard let snapshot else {
                return L10n.string("I reviewed your Mac’s memory status. To reduce memory pressure, you can try closing the most demanding apps.", table: .ai)
            }
            return L10n.string("I reviewed your Mac’s memory status. To reduce memory pressure, you can try closing the most demanding apps.\n\nSystem Info:\n%@", table: .ai, Self.localizedSummary(snapshot))
        } else if lastUserMsg.contains("ısın") || lastUserMsg.contains("cpu") || lastUserMsg.contains("fan") || lastUserMsg.contains("heat") {
            return L10n.string("Based on processor and hardware telemetry, you can check the most resource-hungry processes in Task Manager and safely terminate unresponsive user apps.", table: .ai)
        } else if lastUserMsg.contains("temiz") || lastUserMsg.contains("disk") || lastUserMsg.contains("yer")
                    || lastUserMsg.contains("clean") || lastUserMsg.contains("space") || lastUserMsg.contains("storage") {
            return L10n.string("With the Disk Cleaner module, you can safely clean system caches, build leftovers (Xcode DerivedData), and browser data.", table: .ai)
        } else {
            return L10n.string("The MacOptimizer Pro local AI engine is active. Ask any question about your Mac’s performance, memory management, and system health.", table: .ai)
        }
    }
}
