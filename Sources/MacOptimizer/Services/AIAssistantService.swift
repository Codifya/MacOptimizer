import Foundation

public actor AIAssistantService {
    public static let shared = AIAssistantService()
    public init() {}

    private func provider(for config: NIMConfig, localSnapshot: LocalHeuristicProvider.SystemSnapshot? = nil) -> any AIProvider {
        guard config.isEnabled, config.providerType == .nvidiaNIM,
              UserDefaults.standard.bool(forKey: "MacOptimizer_NIMDisclosureAccepted"),
              !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return LocalHeuristicProvider(snapshot: localSnapshot) }
        return NvidiaNIMProvider(config: config)
    }

    public func analyzeSystemHealth(memory: MemoryStats, cpu: CPUStats, disk: DiskStats, hardware: HardwareInfo,
                                   topProcesses: [ProcessInfoModel], junkGroups: [JunkCategoryGroup],
                                   outdatedAppsCount: Int, nimConfig: NIMConfig) async -> [AIInsight] {
        await provider(for: nimConfig).diagnose(memory: memory, cpu: cpu, disk: disk, hardware: hardware,
            topProcesses: topProcesses, junkGroups: junkGroups, outdatedAppsCount: outdatedAppsCount)
    }

    public func chatWithCopilot(userMessage: String, history: [AIChatMessage], systemContext: String,
                                localSnapshot: LocalHeuristicProvider.SystemSnapshot? = nil,
                                config: NIMConfig) async -> (reply: String, actions: [AIAction]) {
        let lower = userMessage.lowercased()
        var actions: [AIAction] = []
        // Keyword lists cover both Turkish and English user input.
        if lower.contains("çöp") || lower.contains("önbellek") || lower.contains("gereksiz") || lower.contains("temiz")
            || lower.contains("junk") || lower.contains("cache") || lower.contains("clean") { actions.append(AIAction(title: L10n.string("Scan for Junk Files", table: .ai), type: .scanJunk)) }
        if lower.contains("güncelle") || lower.contains("update") || lower.contains("yeni sürüm") || lower.contains("new version") { actions.append(AIAction(title: L10n.string("Check for Updates", table: .ai), type: .checkUpdates)) }
        if lower.contains("dns") || lower.contains("ağ") || lower.contains("internet") || lower.contains("network") { actions.append(AIAction(title: L10n.string("Reset DNS Cache", table: .ai), type: .flushDNS)) }
        do {
            let reply = try await provider(for: config, localSnapshot: localSnapshot).queryCopilot(messages: Array(history.suffix(6)), snapshotContext: systemContext)
            return (reply, actions)
        } catch {
            return (L10n.string("NVIDIA NIM connection error. Local suggestions are offered in the action buttons below.", table: .ai), actions)
        }
    }
}
