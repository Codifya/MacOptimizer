import Foundation
import AppKit

/// Autonomous background watchdog that monitors macOS health, detects anomalies, and performs auto-healing safely.
/// Filters out system processes to avoid false alarms and prevent terminating critical OS services.
public actor AutonomousGuardService {
    public static let shared = AutonomousGuardService()
    
    private var consecutiveHighCPUCounts: [Int32: Int] = [:]
    private var lastAutoPurgeTime: Date?
    
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
        
        // 1. RAM Pressure & Spike Watchdog
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
            guard !proc.isProtected && SafetyGuard.isProcessKillable(pid: proc.pid, name: proc.name, path: proc.path) else {
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
        
        // Clean up dead PIDs from tracker
        let activePIDs = Set(processes.map { $0.pid })
        consecutiveHighCPUCounts = consecutiveHighCPUCounts.filter { activePIDs.contains($0.key) }
        
        // 3. Low Disk Watchdog
        if disk.freePercentage < 0.10 && disk.freeBytes < 20 * 1024 * 1024 * 1024 {
            let alert = AutonomousAlert(
                title: "Kritik Disk Alanı Uyarısı",
                message: "Kullanılabilir disk alanınız kritik seviyede (% \(Int(disk.freePercentage * 100)) / \(ByteFormatter.format(disk.freeBytes))). macOS sistem performansı etkilenebilir.",
                type: .lowDisk,
                timestamp: now,
                isResolved: false,
                autoHealed: false,
                action: AIAction(title: "Gereksiz Dosyaları Temizle", type: .cleanJunk)
            )
            generatedAlerts.append(alert)
        }
        
        return generatedAlerts
    }
}
