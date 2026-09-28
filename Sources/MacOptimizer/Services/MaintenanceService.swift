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
            return (false, L10n.string("DNS cache could not be flushed. Administrator permission may be required (dscacheutil: %lld, mDNSResponder: %lld).", table: .services, cache.exitCode, responder.exitCode))
        }
        return (true, L10n.string("DNS and mDNSResponder caches were flushed successfully.", table: .services))
    }
    
    /// Resets the macOS QuickLook thumbnail cache
    public func resetQuickLookCache() async -> (success: Bool, message: String) {
        let result = await commandRunner(.qlmanage, ["-r", "cache"])
        return (result.isSuccess, result.isSuccess ? L10n.string("QuickLook preview cache was reset.", table: .services) : L10n.string("QuickLook cache could not be reset (exit code: %lld).", table: .services, result.exitCode))
    }
    
    /// Rebuilds macOS LaunchServices database to fix broken file associations and duplicate app menu entries
    public func rebuildLaunchServices() async -> (success: Bool, message: String) {
        let result = await commandRunner(.lsregister, ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"])
        return (result.isSuccess, result.isSuccess ? L10n.string("LaunchServices database was rebuilt successfully.", table: .services) : L10n.string("LaunchServices database could not be rebuilt (exit code: %lld).", table: .services, result.exitCode))
    }
    
    /// Restarts the macOS CoreAudio background daemon to fix sound glitches and frozen audio devices
    public func restartAudioDaemon() async -> (success: Bool, message: String) {
        let result = await commandRunner(.killall, ["-9", "coreaudiod"])
        return (result.isSuccess, result.isSuccess ? L10n.string("CoreAudio was restarted.", table: .services) : L10n.string("CoreAudio could not be restarted; administrator permission may be required (exit code: %lld).", table: .services, result.exitCode))
    }
    
    /// Re-indexes Spotlight search metadata for primary volume
    public func rebuildSpotlightIndex() async -> (success: Bool, message: String) {
        let result = await commandRunner(.mdutil, ["-E", "/"])
        return (result.isSuccess, result.isSuccess ? L10n.string("Spotlight search index was reset and reindexing started.", table: .services) : L10n.string("Spotlight index could not be rebuilt; administrator permission may be required (exit code: %lld).", table: .services, result.exitCode))
    }
    
    /// Clears the system clipboard history
    @MainActor
    public func clearClipboard() -> (success: Bool, message: String) {
        clipboardClearer()
        return (true, L10n.string("Clipboard contents were cleared safely.", table: .services))
    }
    
    /// Runs a comprehensive One-Click Smart Optimization
    public func runSmartOptimization(
        progressHandler: (@Sendable (String, Double) -> Void)? = nil
    ) async -> OptimizationReport {
        let startTime = Date()
        var details: [String] = []
        
        // File cleanup requires a reviewed CleaningPlan in the UI.
        
        // 3. Flush DNS Cache
        progressHandler?(L10n.string("Refreshing network and DNS caches...", table: .services), 0.85)
        let dnsResult = await flushDNSCache()
        details.append(dnsResult.message)
        
        // 4. QuickLook cache reset
        progressHandler?(L10n.string("Resetting QuickLook cache...", table: .services), 0.95)
        let quickLookResult = await resetQuickLookCache()
        details.append(quickLookResult.message)
        
        progressHandler?(L10n.string("Optimization complete!", table: .services), 1.0)
        let duration = Date().timeIntervalSince(startTime)
        
        let report = OptimizationReport(
            title: L10n.string("Quick Smart Optimization", table: .services),
            freedMemoryBytes: 0,
            freedDiskBytes: 0,
            details: details,
            durationSeconds: duration
        )
        
        return report
    }
}
