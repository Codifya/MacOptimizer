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
                title: "Yüksek Bellek Baskısı Uyarısı",
                message: "RAM kullanımı %\(Int(ramPercent)) seviyesine ulaştı. Bellek baskısını azaltmak için en çok bellek kullanan uygulamaları kapatmayı deneyin.",
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
                        title: "Kaçak Süreç: \(proc.name)",
                        message: "\(proc.name) (PID: \(proc.pid)) sürekli olarak %\(proc.cpuFormatted) işlemci tüketiyor. Donmuş veya aşırı yüklenmiş olabilir.",
                        type: .runawayProcess,
                        timestamp: now,
                        isResolved: false,
                        autoHealed: false,
                        action: AIAction(title: "İşlemi Sonlandır", type: .killProcess, targetPID: proc.pid)
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
                    title: "Termal Kısılma / Sıcaklık Uyarısı",
                    message: "İşlemci sıcaklığı kritik eşiğe ulaştı (\(cpu.thermalState.rawValue)). Donanımı korumak için yüksek işlemci kullanan uygulamaları kapatın.",
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
                    title: "Yüksek Swap (Takas Alanı) Kullanımı",
                    message: "Sistem diski üzerinde \(ByteFormatter.formatMemory(memory.swapUsedBytes)) sanal bellek takası kullanılıyor. Bellek baskısını azaltmak için yoğun uygulamaları kapatın.",
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
                    title: "Düşük Disk Alanı Uyarısı",
                    message: "Ana disk üzerinde yalnızca \(ByteFormatter.format(disk.freeBytes)) boş alan kaldı. Alan kazanmak için gereksiz sistem önbelleklerini temizleyin.",
                    type: .lowDisk,
                    timestamp: now,
                    isResolved: false,
                    autoHealed: false,
                    action: AIAction(title: "Gereksiz Dosyaları Tara", type: .cleanJunk)
                )
                generatedAlerts.append(alert)
            }
        }
        
        return generatedAlerts
    }
}
