import Foundation

/// Headless CLI Command Runner for Terminal usage (`macopt` / `MacOptimizer status|clean|version|--help`).
public struct CLICommandRunner {

    public static func executionRequestedWithoutConfirmation(_ args: [String]) -> Bool {
        args.contains("--execute") && !args.contains("--yes")
    }
    
    public static func shouldHandleCLI(arguments: [String] = CommandLine.arguments) -> Bool {
        guard arguments.count > 1 else { return false }
        let firstArg = arguments[1].lowercased()
        if ["status", "clean", "version", "help", "-v", "--version", "-h", "--help"].contains(firstArg) {
            return true
        }
        return !firstArg.hasPrefix("-") && !firstArg.contains("xctest") && !firstArg.hasSuffix(".xctest")
    }
    
    public static func runCLI() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first?.lowercased() ?? "--help"
        
        switch command {
        case "status":
            await printSystemStatus()
            
        case "clean":
            let execute = args.contains("--execute")
            if executionRequestedWithoutConfirmation(args) {
                print("For safety, --yes is required with --execute.")
                exit(2)
            }
            await runJunkClean(dryRun: !execute, includeTrash: args.contains("--include-trash"))
            
        case "version", "-v", "--version":
            printVersion()
            
        case "help", "-h", "--help":
            printHelp()
            
        default:
            print("⚠️ Unknown command: \(command)")
            printHelp()
            exit(1)
        }
        
        exit(0)
    }
    
    private static func printSystemStatus() async {
        let mem = await SystemMonitorService.shared.fetchMemoryStats()
        _ = await SystemMonitorService.shared.fetchCPUStats()
        try? await Task.sleep(nanoseconds: 200_000_000)
        let cpu = await SystemMonitorService.shared.fetchCPUStats()
        let disk = await SystemMonitorService.shared.fetchDiskStats()
        let batt = await SystemMonitorService.shared.fetchBatteryStats()
        let hw = await SystemMonitorService.shared.fetchHardwareInfo()

        print(statusReport(memory: mem, cpu: cpu, disk: disk, battery: batt, hardware: hw))
    }

    /// English-only status text. The CLI never uses `L10n`; model raw values are not display text.
    static func statusReport(memory mem: MemoryStats, cpu: CPUStats, disk: DiskStats, battery batt: BatteryStats, hardware hw: HardwareInfo) -> String {
        """
        ========================================================
        ⚡ MacOptimizer Pro System Status
        ========================================================
        💻 Hardware:     \(hw.modelName) (\(hw.chipName))
        🍏 macOS:        \(hw.osVersion)
        ⏱️  Uptime:       \(hw.uptimeString)
        
        🧠 Memory Used:  \(ByteFormatter.formatMemory(mem.actualUsedBytes)) / \(ByteFormatter.formatMemory(mem.totalBytes)) (\(Int(mem.usedPercentage * 100))%)
        📊 Memory Pressure: \(englishLabel(for: mem.pressureLevel))
        💾 Swap Used:    \(ByteFormatter.formatMemory(mem.swapUsedBytes)) / \(ByteFormatter.formatMemory(mem.swapTotalBytes))
        
        🔥 CPU Usage:    \(String(format: "%.1f", cpu.totalUsage))% (\(cpu.physicalCores) cores)
        🌡️ Thermal State: \(englishLabel(for: cpu.thermalState))

        💽 Disk:         \(ByteFormatter.format(disk.usedBytes)) used / \(ByteFormatter.format(disk.freeBytes)) free
        🔋 Battery:      \(batt.percentage)% (\(batt.powerSource))
        ========================================================
        """
    }

    static func englishLabel(for level: MemoryStats.MemoryPressureLevel) -> String {
        switch level {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    static func englishLabel(for state: CPUStats.ThermalState) -> String {
        switch state {
        case .nominal: return "Normal (Cool)"
        case .fair: return "Slightly Warm"
        case .serious: return "High Temperature (Throttling Risk)"
        case .critical: return "Critical Temperature (Fans at Maximum)"
        }
    }
    
    private static func runJunkClean(dryRun: Bool, includeTrash: Bool) async {
        print("🔍 Scanning for junk files and caches...")
        let groups = await JunkCleanerService.shared.scanAll()
        let trashItems = groups.first(where: { $0.type == .trashBin })?.items ?? []
        var plan = await JunkCleanerService.shared.generateCleaningPlan(from: groups)
        if !includeTrash { plan.items = plan.items.filter { $0.category != .trashBin } }
        
        print("\n📊 Junk Files Found:")
        print("--------------------------------------------------------")
        for group in groups {
            let totalGroupBytes = group.items.reduce(0) { $0 + $1.sizeBytes }
            print("• \(categoryName(group.type)): \(group.items.count) items (\(ByteFormatter.format(totalGroupBytes)))")
        }
        print("--------------------------------------------------------")
        print("Total Recoverable Space: \(ByteFormatter.format(plan.selectedEstimatedBytes))")
        print("Maximum Risk Level:      \(plan.maxRiskLevel.rawValue)")
        print("Zero-Harm Safety:        Active (system root paths protected)")
        if includeTrash {
            print("Trash: \(trashItems.count) items (\(ByteFormatter.format(trashItems.reduce(0) { $0 + $1.sizeBytes }))) — included separately for permanent deletion.")
        }
        for item in plan.items where item.isSelected {
            print("  • \(item.name) — \(item.path) (\(item.sizeFormatted))")
        }
        
        if dryRun {
            print("\n💡 This was a dry run. To execute the cleanup:")
            print("   MacOptimizer clean --execute --yes")
        } else {
            print("\n🚀 Starting the approved plan...")
            let confirmation = SafeOperationExecutor.confirm(plan)
            let result = await JunkCleanerService.shared.executeCleaningPlan(plan, confirmation: confirmation)
            if includeTrash {
                let result = SafeOperationExecutor.emptyTrash(trashItems.map { URL(fileURLWithPath: $0.path) }, confirmation: confirmation)
                print("Trash: removed \(result.removedCount), skipped \(result.skippedCount), freed \(ByteFormatter.format(result.bytesFreed)).")
            }
            print("✨ Cleanup complete! Recovered \(ByteFormatter.format(result.totalFreedBytes)).")
        }
    }
    
    private static func printVersion() {
        // TODO(TASK-009): share the bundle version with the SwiftPM executable target.
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? "Unknown"
        print("MacOptimizer Pro v\(version)")
        print("Apache License 2.0 • https://github.com/Codifya/MacOptimizer")
    }
    
    private static func printHelp() {
        print(helpText)
    }

    static let helpText = """
        MacOptimizer Pro CLI Help & Usage:
        CLI output is English only and does not use localization catalogs.
        
        Usage:
          MacOptimizer <command> [options]
        
        Commands:
          status           Print current CPU, memory, thermal, swap, and disk telemetry.
          clean            Scan for junk files (default: --dry-run).
          clean --execute --yes  Print the plan and move approved items to Trash.
          --include-trash       Include Trash items in the plan (requires extra confirmation).
          version          Print version and license information.
          help             Show this help menu.
        
        Examples:
          MacOptimizer status
          MacOptimizer clean --dry-run
        """

    private static func categoryName(_ category: JunkCategoryType) -> String {
        switch category {
        case .systemCache: "System and App Caches"
        case .systemLogs: "System and Error Logs"
        case .developerCache: "Developer and Build Caches"
        case .browserCache: "Browser Caches"
        case .trashBin: "Trash"
        case .largeFiles: "Large and Old Files"
        case .appLeftovers: "App Leftovers"
        }
    }
}
