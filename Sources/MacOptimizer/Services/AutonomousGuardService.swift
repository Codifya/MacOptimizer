import Foundation
import AppKit

/// Evaluation result from an autonomous rule
public struct AutonomousRuleEvaluationResult: Sendable {
    public let alert: AutonomousAlert
    public let executionRisk: OperationRisk
    
    public init(alert: AutonomousAlert, executionRisk: OperationRisk = .safe) {
        self.alert = alert
        self.executionRisk = executionRisk
    }
}

/// Protocol defining a declarative autonomous watchdog rule
public protocol AutonomousWatchdogRule: Sendable {
    var id: String { get }
    var name: String { get }
    var riskLevel: OperationRisk { get }
    func evaluate(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        processes: [ProcessInfoModel],
        config: AutonomousConfig
    ) async -> AutonomousRuleEvaluationResult?
}

/// Autonomous background watchdog that monitors macOS health, detects anomalies, and performs auto-healing safely.
/// Filters out system processes to avoid false alarms and prevent terminating critical OS services.
public actor AutonomousGuardService {
    public static let shared = AutonomousGuardService()
    
    private var consecutiveHighCPUCounts: [Int32: Int] = [:]
    private var lastThermalAlertTime: Date?
    private var lastSwapAlertTime: Date?
    private var lastDiskAlertTime: Date?
    
    public init() {}
    
    /// Evaluates current system metrics against configured thresholds and returns any triggered alerts and auto-healed actions.
    /// - Parameter processesAreFresh: `false` when `processes` is a cached list from an earlier cycle.
    ///   The runaway rule only counts fresh samples; counting a cached list three times used to raise a
    ///   "sustained high CPU" alert from a single measurement.
    public func evaluateCycle(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        processes: [ProcessInfoModel],
        config: AutonomousConfig,
        processesAreFresh: Bool = true
    ) async -> [AutonomousAlert] {
        guard config.isWatchdogActive else { return [] }
        
        var generatedAlerts: [AutonomousAlert] = []
        let now = Date()
        
        // 1. RAM Pressure & Spike Rule
        let ramPercent = memory.usedPercentage * 100.0
        if ramPercent >= config.ramThresholdPercent || memory.pressureLevel == .critical {
            generatedAlerts.append(AutonomousAlert(
                title: L10n.string("High Memory Pressure Warning", table: .services),
                message: L10n.string("RAM usage has reached %lld%%. Try closing the apps using the most memory to reduce memory pressure.", table: .services, Int(ramPercent)),
                type: .memorySpike,
                timestamp: now,
                isResolved: false,
                autoHealed: false,
                action: nil
            ))
        }
        
        // 2. Runaway Process Watchdog (>90% CPU for multiple consecutive fresh samples) - ONLY for killable non-system processes
        if processesAreFresh {
            var stillHot: Set<Int32> = []
            for proc in processes where proc.cpuPercentage >= config.cpuRunawayThresholdPercent {
                // Strictly skip protected system processes like WindowServer, kernel_task, etc.
                guard !proc.isProtected && SafetyPolicyEngine.canTerminateProcess(pid: proc.pid, name: proc.name, path: proc.path) else {
                    continue
                }
                stillHot.insert(proc.pid)
                
                let count = (consecutiveHighCPUCounts[proc.pid] ?? 0) + 1
                consecutiveHighCPUCounts[proc.pid] = count
                
                if count >= 3 { // Detected high CPU for 3 consecutive samples
                    let alert = AutonomousAlert(
                        title: L10n.string("Runaway Process: %@", table: .services, proc.name),
                        message: L10n.string("%@ (PID: %d) is continuously consuming %@%% CPU. It may be frozen or overloaded.", table: .services, proc.name, proc.pid, String(format: "%.1f", proc.cpuPercentage)),
                        type: .runawayProcess,
                        timestamp: now,
                        isResolved: false,
                        autoHealed: false,
                        action: AIAction(title: L10n.string("Terminate Process", table: .services), type: .killProcess, targetPID: proc.pid)
                    )
                    generatedAlerts.append(alert)
                    consecutiveHighCPUCounts[proc.pid] = 0 // Reset count after alert
                }
            }
            // "Consecutive" means consecutive: a sample below the threshold resets the streak. This also
            // drops dead PIDs, keeping the tracker bounded by the number of currently hot processes.
            consecutiveHighCPUCounts = consecutiveHighCPUCounts.filter { stillHot.contains($0.key) }
        }
        
        // 3. Thermal Throttling Watchdog Rule
        if (cpu.thermalState == .serious || cpu.thermalState == .critical) {
            let canAlertThermal = lastThermalAlertTime == nil || now.timeIntervalSince(lastThermalAlertTime!) > 180.0
            if canAlertThermal {
                lastThermalAlertTime = now
                let alert = AutonomousAlert(
                    title: L10n.string("Thermal Throttling / Temperature Warning", table: .services),
                    message: L10n.string("CPU temperature has reached a critical threshold (%@). Close apps with high CPU usage to protect the hardware.", table: .services, cpu.thermalState.localizedTitle),
                    type: .runawayProcess,
                    timestamp: now,
                    isResolved: false,
                    autoHealed: false,
                    action: nil
                )
                generatedAlerts.append(alert)
            }
        }
        
        // 4. Swap Memory Spike Watchdog Rule (> 2.0 GB swap used)
        if memory.swapUsedBytes > (2 * 1024 * 1024 * 1024) {
            let canAlertSwap = lastSwapAlertTime == nil || now.timeIntervalSince(lastSwapAlertTime!) > 300.0
            if canAlertSwap {
                lastSwapAlertTime = now
                let alert = AutonomousAlert(
                    title: L10n.string("High Swap Usage", table: .services),
                    message: L10n.string("%@ of virtual memory swap is in use on the system disk. Close heavy apps to reduce memory pressure.", table: .services, ByteFormatter.formatMemory(memory.swapUsedBytes)),
                    type: .memorySpike,
                    timestamp: now,
                    isResolved: false,
                    autoHealed: false,
                    action: nil
                )
                generatedAlerts.append(alert)
            }
        }
        
        // 5. Low Disk Space Watchdog Rule (< 10 GB free)
        if disk.freeBytes > 0 && disk.freeBytes < (10 * 1024 * 1024 * 1024) {
            let canAlertDisk = lastDiskAlertTime == nil || now.timeIntervalSince(lastDiskAlertTime!) > 600.0
            if canAlertDisk {
                lastDiskAlertTime = now
                let alert = AutonomousAlert(
                    title: L10n.string("Low Disk Space Warning", table: .services),
                    message: L10n.string("Only %@ of free space is left on the main disk. Clean unnecessary system caches to free up space.", table: .services, ByteFormatter.format(disk.freeBytes)),
                    type: .lowDisk,
                    timestamp: now,
                    isResolved: false,
                    autoHealed: false,
                    action: AIAction(title: L10n.string("Scan Junk Files", table: .services), type: .cleanJunk)
                )
                generatedAlerts.append(alert)
            }
        }
        
        return generatedAlerts
    }
}
