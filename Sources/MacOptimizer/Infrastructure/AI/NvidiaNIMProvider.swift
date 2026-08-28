import Foundation

/// Cloud enterprise intelligence provider powered by NVIDIA NIM microservices.
public struct NvidiaNIMProvider: AIProvider {
    public let providerId: String = "nvidia_nim"
    public let displayName: String = "NVIDIA NIM (Llama 3.3 / DeepSeek R1)"
    public let requiresNetwork: Bool = true
    
    private let config: NIMConfig
    
    public init(config: NIMConfig) {
        self.config = config
    }
    
    public func diagnose(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        hardware: HardwareInfo,
        topProcesses: [ProcessInfoModel],
        junkGroups: [JunkCategoryGroup],
        outdatedAppsCount: Int
    ) async -> [AIInsight] {
        guard config.isEnabled, !config.apiKey.isEmpty else {
            return await LocalHeuristicProvider().diagnose(
                memory: memory, cpu: cpu, disk: disk, hardware: hardware,
                topProcesses: topProcesses, junkGroups: junkGroups, outdatedAppsCount: outdatedAppsCount
            )
        }
        
        return await AIAssistantService.shared.analyzeSystemHealth(
            memory: memory, cpu: cpu, disk: disk, hardware: hardware,
            topProcesses: topProcesses, junkGroups: junkGroups, outdatedAppsCount: outdatedAppsCount,
            nimConfig: config
        )
    }
    
    public func queryCopilot(
        messages: [AIChatMessage],
        snapshotContext: String
    ) async throws -> String {
        guard let lastUser = messages.last(where: { $0.role == .user })?.content else {
            return "Size nasıl yardımcı olabilirim?"
        }
        let (reply, _) = await AIAssistantService.shared.chatWithCopilot(
            userMessage: lastUser,
            history: messages,
            systemContext: snapshotContext,
            config: config
        )
        return reply
    }
}
