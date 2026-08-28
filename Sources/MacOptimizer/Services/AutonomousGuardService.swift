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
    private var lastAutoPurgeTime: Date?
    private var lastThermalAlertTime: Date?
    private var lastSwapAlertTime: Date?
    private var lastDiskAlertTime: Date?
    
    public init() {}
    
    /// Evaluates current system metrics against configured thresholds and returns any triggered alerts and auto-healed actions
    public func evaluateCycle(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        processes: [ProcessInfoModel],
        config: AutonomousConfig
    ) async -> [AutonomousAlert] {
        guard config.isWatchdogActive else { return [] }
        
        var generatedAlerts: [AutonomousAlert] = []
        let now = Date()
        
        // 1. RAM Pressure & Spike Rule
        let ramPercent = memory.usedPercentage * 100.0
        if ramPercent >= config.ramThresholdPercent || memory.pressureLevel == .critical {
            let canAutoPurge = lastAutoPurgeTime == nil || now.timeIntervalSince(lastAutoPurgeTime!) > 60.0 // Cooldown of 60s
            
            if config.autoPurgeRAMOnSpike && canAutoPurge {
                lastAutoPurgeTime = now
                let purgeResult = await MemoryOptimizerService.shared.purgeMemory()
                
                let alert = AutonomousAlert(
                    title: "Otonom RAM Kurtarma Devreye Girdi",
                    message: "RAM kullanımı %\(Int(ramPercent)) eşiğini aştı. Otonom motor pasif önbellekleri boşaltarak \(ByteFormatter.formatMemory(purgeResult.freedBytes)) bellek kazandırdı.",
                    type: .memorySpike,
                    timestamp: now,
                    isResolved: true,
                    autoHealed: true,
                    action: nil
                )
                generatedAlerts.append(alert)
            } else if !config.autoPurgeRAMOnSpike {
                let alert = AutonomousAlert(
                    title: "Yüksek Bellek Baskısı Uyarısı",
                    message: "RAM kullanımı %\(Int(ramPercent)) seviyesine ulaştı. Performans kaybını önlemek için RAM'i boşaltın.",
                    type: .memorySpike,
                    timestamp: now,
                    isResolved: false,
                    autoHealed: false,
                    action: AIAction(title: "RAM'i Boşalt", type: .purgeRAM)
                )
                generatedAlerts.append(alert)
            }
        }
        
        // 2. Runaway Process Watchdog (>90% CPU for multiple cycles) - ONLY for killable non-system processes
        for proc in processes where proc.cpuPercentage >= config.cpuRunawayThresholdPercent {
            // Strictly skip protected system processes like WindowServer, kernel_task, etc.
            guard !proc.isProtected && SafetyPolicyEngine.canTerminateProcess(pid: proc.pid, name: proc.name, path: proc.path) else {
                continue
            }
            
            let count = (consecutiveHighCPUCounts[proc.pid] ?? 0) + 1
            consecutiveHighCPUCounts[proc.pid] = count
            
            if count >= 3 { // Detected high CPU for 3 consecutive cycles
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
                    action: AIAction(title: "RAM'i Boşalt", type: .purgeRAM)
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
                    message: "Sistem diski üzerinde \(ByteFormatter.formatMemory(memory.swapUsedBytes)) sanal bellek takası kullanılıyor. Bellek tıkanıklığını gidermek için RAM optimizasyonu önerilir.",
                    type: .memorySpike,
                    timestamp: now,
                    isResolved: false,
                    autoHealed: false,
                    action: AIAction(title: "RAM'i Boşalt", type: .purgeRAM)
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
        
        // Clean up dead PIDs from tracker
        let livePIDs = Set(processes.map { $0.pid })
        for pid in consecutiveHighCPUCounts.keys {
            if !livePIDs.contains(pid) {
                consecutiveHighCPUCounts.removeValue(forKey: pid)
            }
        }
        
        return generatedAlerts
    }
}
