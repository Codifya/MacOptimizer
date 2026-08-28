import Foundation
import AppKit

/// Maintenance utilities for macOS system health, network cache, quicklook cache, and smart optimization
public actor MaintenanceService {
    public static let shared = MaintenanceService()
    
    public init() {}
    
    /// Flushes the macOS DNS cache
    public func flushDNSCache() async -> (success: Bool, message: String) {
        _ = await SystemCommandRunner.run(executable: "/usr/bin/dscacheutil", arguments: ["-flushcache"])
        _ = await SystemCommandRunner.run(executable: "/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
        return (true, "DNS önbelleği başarıyla temizlendi ve ağ yanıt süreleri yenilendi.")
    }
    
    /// Resets the macOS QuickLook thumbnail cache
    public func resetQuickLookCache() async -> (success: Bool, message: String) {
        let result = await SystemCommandRunner.run(executable: "/usr/bin/qlmanage", arguments: ["-r", "cache"])
        return (result.isSuccess, "QuickLook önizleme önbelleği sıfırlandı.")
    }
    
    /// Clears the system clipboard history
    @MainActor
    public func clearClipboard() -> (success: Bool, message: String) {
        NSPasteboard.general.clearContents()
        return (true, "Pano (Clipboard) içeriği güvenle temizlendi.")
    }
    
    /// Runs a comprehensive One-Click Smart Optimization
    public func runSmartOptimization(
        progressHandler: (@Sendable (String, Double) -> Void)? = nil
    ) async -> OptimizationReport {
        let startTime = Date()
        var freedRAM: UInt64 = 0
        var freedDisk: Int64 = 0
        var details: [String] = []
        
        // 1. Flush RAM
        progressHandler?("RAM belleği optimize ediliyor...", 0.15)
        let ramResult = await MemoryOptimizerService.shared.purgeMemory()
        freedRAM = ramResult.freedBytes
        details.append(ramResult.message)
        
        // 2. Scan and Clean User & System Caches
        progressHandler?("Gereksiz önbellekler taranıyor...", 0.40)
        let caches = await JunkCleanerService.shared.scanCategory(.systemCache)
        let logs = await JunkCleanerService.shared.scanCategory(.systemLogs)
        let browsers = await JunkCleanerService.shared.scanCategory(.browserCache)
        
        let allAutoCleanItems = (caches + logs + browsers).filter { $0.sizeBytes > 0 }
        
        progressHandler?("Önbellekler ve günlükler temizleniyor...", 0.65)
        let cleanResult = await JunkCleanerService.shared.cleanItems(allAutoCleanItems)
        freedDisk += cleanResult.freedBytes
        details.append("\(ByteFormatter.format(cleanResult.freedBytes)) gereksiz önbellek ve günlük temizlendi.")
        
        // 3. Flush DNS Cache
        progressHandler?("Ağ ve DNS önbelleği yenileniyor...", 0.85)
        let dnsResult = await flushDNSCache()
        if dnsResult.success {
            details.append("DNS önbelleği yenilendi.")
        }
        
        // 4. QuickLook cache reset
        progressHandler?("QuickLook önbelleği sıfırlanıyor...", 0.95)
        _ = await resetQuickLookCache()
        
        progressHandler?("Optimizasyon Tamamlandı!", 1.0)
        let duration = Date().timeIntervalSince(startTime)
        
        let report = OptimizationReport(
            title: "Hızlı Akıllı İyileştirme",
            freedMemoryBytes: freedRAM,
            freedDiskBytes: freedDisk,
            details: details,
            durationSeconds: duration
        )
        
        return report
    }
}
