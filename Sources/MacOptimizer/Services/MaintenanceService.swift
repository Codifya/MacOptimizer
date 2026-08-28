import Foundation
import AppKit

/// Maintenance utilities for macOS system health, network cache, quicklook cache, LaunchServices, Spotlight, and smart optimization.
public actor MaintenanceService {
    public static let shared = MaintenanceService()
    
    public init() {}
    
    /// Flushes the macOS DNS & mDNSResponder cache
    public func flushDNSCache() async -> (success: Bool, message: String) {
        _ = await SandboxedCommandRunner.run(executable: .dscacheutil, arguments: ["-flushcache"])
        _ = await SandboxedCommandRunner.run(executable: .killall, arguments: ["-HUP", "mDNSResponder"])
        return (true, "DNS ve mDNSResponder önbelleği başarıyla temizlendi.")
    }
    
    /// Resets the macOS QuickLook thumbnail cache
    public func resetQuickLookCache() async -> (success: Bool, message: String) {
        let result = await SandboxedCommandRunner.run(executable: .qlmanage, arguments: ["-r", "cache"])
        return (result.isSuccess, "QuickLook önizleme önbelleği sıfırlandı.")
    }
    
    /// Rebuilds macOS LaunchServices database to fix broken file associations and duplicate app menu entries
    public func rebuildLaunchServices() async -> (success: Bool, message: String) {
        let result = await SandboxedCommandRunner.run(
            executable: .lsregister,
            arguments: ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        )
        return (result.isSuccess, "LaunchServices veri tabanı başarıyla yeniden inşa edildi.")
    }
    
    /// Restarts the macOS CoreAudio background daemon to fix sound glitches and frozen audio devices
    public func restartAudioDaemon() async -> (success: Bool, message: String) {
        let result = await SandboxedCommandRunner.run(executable: .killall, arguments: ["-9", "coreaudiod"])
        return (result.isSuccess, "CoreAudio ses sistemi yeniden başlatıldı.")
    }
    
    /// Re-indexes Spotlight search metadata for primary volume
    public func rebuildSpotlightIndex() async -> (success: Bool, message: String) {
        let result = await SandboxedCommandRunner.run(executable: .mdutil, arguments: ["-E", "/"])
        return (result.isSuccess, "Spotlight arama dizini sıfırlandı ve yeniden indeksleme başlatıldı.")
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
