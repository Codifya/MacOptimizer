import Foundation
import AppKit

/// Maintenance utilities for macOS system health, network cache, quicklook cache, LaunchServices, Spotlight, and smart optimization.
public actor MaintenanceService {
    public static let shared = MaintenanceService()

    public typealias CommandRunner = @Sendable (ApprovedExecutable, [String]) async -> CommandExecutionResult
    private let commandRunner: CommandRunner
    private let clipboardClearer: @MainActor @Sendable () -> Void

    public init(
        commandRunner: @escaping CommandRunner = { executable, arguments in await SandboxedCommandRunner.run(executable: executable, arguments: arguments) },
        clipboardClearer: @escaping @MainActor @Sendable () -> Void = { NSPasteboard.general.clearContents() }
    ) {
        self.commandRunner = commandRunner
        self.clipboardClearer = clipboardClearer
    }
    
    /// Flushes the macOS DNS & mDNSResponder cache
    public func flushDNSCache() async -> (success: Bool, message: String) {
        let cache = await commandRunner(.dscacheutil, ["-flushcache"])
        let responder = await commandRunner(.killall, ["-HUP", "mDNSResponder"])
        return Self.mapDNSResults(cache, responder)
    }

    static func mapDNSResults(_ cache: CommandExecutionResult, _ responder: CommandExecutionResult) -> (success: Bool, message: String) {
        guard cache.isSuccess && responder.isSuccess else {
            return (false, "DNS önbelleği işlemi tamamlanamadı. Yönetici izni gerekebilir (dscacheutil: \(cache.exitCode), mDNSResponder: \(responder.exitCode)).")
        }
        return (true, "DNS ve mDNSResponder önbelleği başarıyla temizlendi.")
    }
    
    /// Resets the macOS QuickLook thumbnail cache
    public func resetQuickLookCache() async -> (success: Bool, message: String) {
        let result = await commandRunner(.qlmanage, ["-r", "cache"])
        return (result.isSuccess, result.isSuccess ? "QuickLook önizleme önbelleği sıfırlandı." : "QuickLook önbelleği sıfırlanamadı (çıkış kodu: \(result.exitCode)).")
    }
    
    /// Rebuilds macOS LaunchServices database to fix broken file associations and duplicate app menu entries
    public func rebuildLaunchServices() async -> (success: Bool, message: String) {
        let result = await commandRunner(.lsregister, ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"])
        return (result.isSuccess, result.isSuccess ? "LaunchServices veri tabanı başarıyla yeniden inşa edildi." : "LaunchServices veri tabanı yeniden inşa edilemedi (çıkış kodu: \(result.exitCode)).")
    }
    
    /// Restarts the macOS CoreAudio background daemon to fix sound glitches and frozen audio devices
    public func restartAudioDaemon() async -> (success: Bool, message: String) {
        let result = await commandRunner(.killall, ["-9", "coreaudiod"])
        return (result.isSuccess, result.isSuccess ? "CoreAudio ses sistemi yeniden başlatıldı." : "CoreAudio yeniden başlatılamadı; yönetici izni gerekebilir (çıkış kodu: \(result.exitCode)).")
    }
    
    /// Re-indexes Spotlight search metadata for primary volume
    public func rebuildSpotlightIndex() async -> (success: Bool, message: String) {
        let result = await commandRunner(.mdutil, ["-E", "/"])
        return (result.isSuccess, result.isSuccess ? "Spotlight arama dizini sıfırlandı ve yeniden indeksleme başlatıldı." : "Spotlight dizini yeniden oluşturulamadı; yönetici izni gerekebilir (çıkış kodu: \(result.exitCode)).")
    }
    
    /// Clears the system clipboard history
    @MainActor
    public func clearClipboard() -> (success: Bool, message: String) {
        clipboardClearer()
        return (true, "Pano (Clipboard) içeriği güvenle temizlendi.")
    }
    
    /// Runs a comprehensive One-Click Smart Optimization
    public func runSmartOptimization(
        progressHandler: (@Sendable (String, Double) -> Void)? = nil
    ) async -> OptimizationReport {
        let startTime = Date()
        var details: [String] = []
        
        // File cleanup requires a reviewed CleaningPlan in the UI.
        
        // 3. Flush DNS Cache
        progressHandler?("Ağ ve DNS önbelleği yenileniyor...", 0.85)
        let dnsResult = await flushDNSCache()
        details.append(dnsResult.message)
        
        // 4. QuickLook cache reset
        progressHandler?("QuickLook önbelleği sıfırlanıyor...", 0.95)
        let quickLookResult = await resetQuickLookCache()
        details.append(quickLookResult.message)
        
        progressHandler?("Optimizasyon Tamamlandı!", 1.0)
        let duration = Date().timeIntervalSince(startTime)
        
        let report = OptimizationReport(
            title: "Hızlı Akıllı İyileştirme",
            freedMemoryBytes: 0,
            freedDiskBytes: 0,
            details: details,
            durationSeconds: duration
        )
        
        return report
    }
}
