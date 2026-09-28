import Foundation

public actor AIAssistantService {
    public static let shared = AIAssistantService()
    public init() {}

    private func provider(for config: NIMConfig) -> any AIProvider {
        guard config.isEnabled, config.providerType == .nvidiaNIM,
              UserDefaults.standard.bool(forKey: "MacOptimizer_NIMDisclosureAccepted"),
              !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return LocalHeuristicProvider() }
        return NvidiaNIMProvider(config: config)
    }

    public func analyzeSystemHealth(memory: MemoryStats, cpu: CPUStats, disk: DiskStats, hardware: HardwareInfo,
                                   topProcesses: [ProcessInfoModel], junkGroups: [JunkCategoryGroup],
                                   outdatedAppsCount: Int, nimConfig: NIMConfig) async -> [AIInsight] {
        await provider(for: nimConfig).diagnose(memory: memory, cpu: cpu, disk: disk, hardware: hardware,
            topProcesses: topProcesses, junkGroups: junkGroups, outdatedAppsCount: outdatedAppsCount)
    }

    public func chatWithCopilot(userMessage: String, history: [AIChatMessage], systemContext: String,
                                config: NIMConfig) async -> (reply: String, actions: [AIAction]) {
        let lower = userMessage.lowercased()
        var actions: [AIAction] = []
        if lower.contains("çöp") || lower.contains("önbellek") || lower.contains("gereksiz") || lower.contains("temiz") { actions.append(AIAction(title: "Gereksiz Dosyaları Tara", type: .scanJunk)) }
        if lower.contains("güncelle") || lower.contains("update") || lower.contains("yeni sürüm") { actions.append(AIAction(title: "Güncellemeleri Denetle", type: .checkUpdates)) }
        if lower.contains("dns") || lower.contains("ağ") || lower.contains("internet") { actions.append(AIAction(title: "DNS Önbelleğini Sıfırla", type: .flushDNS)) }
        do {
            let reply = try await provider(for: config).queryCopilot(messages: Array(history.suffix(6)), snapshotContext: systemContext)
            return (reply, actions)
        } catch {
            return ("NVIDIA NIM bağlantı hatası. Yerel öneriler aşağıdaki eylem düğmelerinde sunuluyor.", actions)
        }
    }
}
