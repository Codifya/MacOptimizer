import Foundation

public struct NvidiaNIMProvider: AIProvider {
    public let providerId = "nvidia_nim"
    public let displayName = "NVIDIA NIM (Bulut)"
    public let requiresNetwork = true
    private let config: NIMConfig

    public init(config: NIMConfig) { self.config = config }

    public nonisolated static func cloudContext(_ base: String, processNames: [String], includeProcesses: Bool) -> String {
        guard includeProcesses, !processNames.isEmpty else { return base }
        return base + "\nÇalışan uygulamalar: " + processNames.joined(separator: ", ")
    }

    public func diagnose(memory: MemoryStats, cpu: CPUStats, disk: DiskStats, hardware: HardwareInfo,
                         topProcesses: [ProcessInfoModel], junkGroups: [JunkCategoryGroup], outdatedAppsCount: Int) async -> [AIInsight] {
        let totalJunk = junkGroups.reduce(0) { $0 + $1.totalSizeBytes }
        let base = "Mac: \(hardware.modelName), \(hardware.chipName), \(hardware.osVersion). RAM %\(Int(memory.usedPercentage * 100)), CPU %\(cpu.totalUsage), Boş disk %\(Int(disk.freePercentage * 100)), Gereksiz dosyalar \(ByteFormatter.format(totalJunk)), Güncelleme bekleyen uygulama: \(outdatedAppsCount). Türkçe kısa sistem önerileri ver."
        let prompt = Self.cloudContext(base, processNames: topProcesses.prefix(4).map { "\($0.name) (PID: \($0.pid))" }, includeProcesses: UserDefaults.standard.bool(forKey: "MacOptimizer_IncludeRunningAppNames"))
        do {
            let answer = try await NvidiaNIMService.shared.sendChatCompletion(messages: [["role": "user", "content": prompt]], config: config)
            return [AIInsight(title: "NVIDIA NIM Sistem Analizi", summary: answer, severity: .recommendation, category: "Yapay Zeka Raporu")]
        } catch {
            return await LocalHeuristicProvider().diagnose(memory: memory, cpu: cpu, disk: disk, hardware: hardware,
                topProcesses: topProcesses, junkGroups: junkGroups, outdatedAppsCount: outdatedAppsCount)
        }
    }

    public func queryCopilot(messages: [AIChatMessage], snapshotContext: String) async throws -> String {
        let system = "MacOptimizer Pro macOS asistanısın. Türkçe yanıt ver; sadece öneri sun, eylem çalıştırma. Sistem özeti: \(snapshotContext)"
        let chat = messages.suffix(6).map { ["role": $0.role.rawValue, "content": $0.content] }
        return try await NvidiaNIMService.shared.sendChatCompletion(messages: chat, config: config, systemPrompt: system)
    }
}
