import Foundation

/// Generic OpenAI-compatible endpoint provider (vLLM, LM Studio, OpenAI, etc.)
public struct OpenAICompatibleProvider: AIProvider {
    public let providerId: String = "openai_compatible"
    public let displayName: String = "Özel / OpenAI Uyumlu Uç Nokta"
    public let requiresNetwork: Bool
    
    public let baseURL: String
    public let apiKey: String
    public let model: String
    
    public init(baseURL: String, apiKey: String, model: String) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requiresNetwork = !baseURL.contains("localhost") && !baseURL.contains("127.0.0.1")
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
        return await LocalHeuristicProvider().diagnose(
            memory: memory,
            cpu: cpu,
            disk: disk,
            hardware: hardware,
            topProcesses: topProcesses,
            junkGroups: junkGroups,
            outdatedAppsCount: outdatedAppsCount
        )
    }
    
    public func queryCopilot(
        messages: [AIChatMessage],
        snapshotContext: String
    ) async throws -> String {
        let endpoint = baseURL.hasSuffix("/v1") ? "\(baseURL)/chat/completions" : "\(baseURL)/v1/chat/completions"
        guard let url = URL(string: endpoint) else {
            return try await LocalHeuristicProvider().queryCopilot(messages: messages, snapshotContext: snapshotContext)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30.0
        
        var chatPayload: [[String: String]] = [
            [
                "role": "system",
                "content": "Sen macOS uzmanı bir yapay zeka asistanısın. Kullanıcıya Mac sağlığı ve optimizasyonu konusunda Türkçe yardımcı oluyorsun.\n\nSistem Durumu:\n\(snapshotContext)"
            ]
        ]
        
        for msg in messages {
            chatPayload.append([
                "role": msg.role.rawValue,
                "content": msg.content
            ])
        }
        
        let bodyObj: [String: Any] = [
            "model": model.isEmpty ? "default" : model,
            "messages": chatPayload,
            "temperature": 0.3
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyObj)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                return try await LocalHeuristicProvider().queryCopilot(messages: messages, snapshotContext: snapshotContext)
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            return try await LocalHeuristicProvider().queryCopilot(messages: messages, snapshotContext: snapshotContext)
        }
        
        return try await LocalHeuristicProvider().queryCopilot(messages: messages, snapshotContext: snapshotContext)
    }
}
