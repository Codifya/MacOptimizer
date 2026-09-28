import Foundation

public struct NvidiaNIMProvider: AIProvider {
    public let providerId = "nvidia_nim"
    public let displayName = L10n.string("NVIDIA NIM (Cloud)", table: .ai)
    public let requiresNetwork = true
    private let config: NIMConfig

    public init(config: NIMConfig) { self.config = config }

    public nonisolated static func cloudContext(_ base: String, processNames: [String], includeProcesses: Bool) -> String {
        guard includeProcesses, !processNames.isEmpty else { return base }
        return base + "\nRunning apps: " + processNames.joined(separator: ", ")
    }

    /// Model instructions are always English; the reply language follows the app's UI language.
    public nonisolated static func diagnosisPrompt(_ metrics: String, replyLanguage: String) -> String {
        metrics + " Give short system recommendations. Reply in \(replyLanguage)."
    }

    public nonisolated static func copilotSystemPrompt(snapshotContext: String, replyLanguage: String) -> String {
        "You are the MacOptimizer Pro macOS assistant. Reply in \(replyLanguage); only offer recommendations, never execute actions. System summary: \(snapshotContext)"
    }

    public func diagnose(memory: MemoryStats, cpu: CPUStats, disk: DiskStats, hardware: HardwareInfo,
                         topProcesses: [ProcessInfoModel], junkGroups: [JunkCategoryGroup], outdatedAppsCount: Int) async -> [AIInsight] {
        let totalJunk = junkGroups.reduce(0) { $0 + $1.totalSizeBytes }
        let metrics = "Mac: \(hardware.modelName), \(hardware.chipName), \(hardware.osVersion). RAM \(Int(memory.usedPercentage * 100))%, CPU \(cpu.totalUsage)%, Free disk \(Int(disk.freePercentage * 100))%, Junk files \(ByteFormatter.format(totalJunk)), Apps with pending updates: \(outdatedAppsCount)."
        let base = Self.diagnosisPrompt(metrics, replyLanguage: L10n.currentLanguageEnglishName())
        let prompt = Self.cloudContext(base, processNames: topProcesses.prefix(4).map { "\($0.name) (PID: \($0.pid))" }, includeProcesses: UserDefaults.standard.bool(forKey: "MacOptimizer_IncludeRunningAppNames"))
        do {
            let answer = try await NvidiaNIMService.shared.sendChatCompletion(messages: [["role": "user", "content": prompt]], config: config)
            return [AIInsight(title: L10n.string("NVIDIA NIM System Analysis", table: .ai), summary: answer, severity: .recommendation, category: L10n.string("AI Report", table: .ai))]
        } catch {
            return await LocalHeuristicProvider().diagnose(memory: memory, cpu: cpu, disk: disk, hardware: hardware,
                topProcesses: topProcesses, junkGroups: junkGroups, outdatedAppsCount: outdatedAppsCount)
        }
    }

    public func queryCopilot(messages: [AIChatMessage], snapshotContext: String) async throws -> String {
        let system = Self.copilotSystemPrompt(snapshotContext: snapshotContext, replyLanguage: L10n.currentLanguageEnglishName())
        let chat = messages.suffix(6).map { ["role": $0.role.rawValue, "content": $0.content] }
        return try await NvidiaNIMService.shared.sendChatCompletion(messages: chat, config: config, systemPrompt: system)
    }
}
