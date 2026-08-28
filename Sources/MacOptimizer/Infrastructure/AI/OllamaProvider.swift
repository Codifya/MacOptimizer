import Foundation

/// Local offline AI provider utilizing a locally running Ollama instance (e.g. llama3.2, deepseek-r1).
public struct OllamaProvider: AIProvider {
    public let providerId: String = "ollama_local"
    public let displayName: String = "Yerel Ollama (100% Gizli & Cihaz Üzerinde)"
    public let requiresNetwork: Bool = false
    
    public let baseURL: String
    public let model: String
    
    public init(baseURL: String = "http://localhost:11434", model: String = "llama3.2") {
        self.baseURL = baseURL
        self.model = model
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
            memory: memory, cpu: cpu, disk: disk, hardware: hardware,
            topProcesses: topProcesses, junkGroups: junkGroups, outdatedAppsCount: outdatedAppsCount
        )
    }
    
    public func queryCopilot(
        messages: [AIChatMessage],
        snapshotContext: String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            return try await LocalHeuristicProvider().queryCopilot(messages: messages, snapshotContext: snapshotContext)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
            "model": model,
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
