import Foundation

/// Unified abstraction protocol for AI diagnostic and Copilot intelligence providers.
public protocol AIProvider: Sendable {
    var providerId: String { get }
    var displayName: String { get }
    var requiresNetwork: Bool { get }
    
    /// Analyzes current telemetry and produces structured insight recommendations.
    func diagnose(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        hardware: HardwareInfo,
        topProcesses: [ProcessInfoModel],
        junkGroups: [JunkCategoryGroup],
        outdatedAppsCount: Int
    ) async -> [AIInsight]
    
    /// Answers user queries in interactive Copilot chat with system context.
    func queryCopilot(
        messages: [AIChatMessage],
        snapshotContext: String
    ) async throws -> String
}
