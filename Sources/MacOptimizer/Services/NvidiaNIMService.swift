import Foundation

/// Service for communicating with NVIDIA NIM (Inference Microservice) Cloud API or local NIM endpoints.
/// Security-hardened against API key leakage and plaintext transport over public networks.
public actor NvidiaNIMService {
    public static let shared = NvidiaNIMService()
    
    private let urlSession: URLSession
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20.0
        config.timeoutIntervalForResource = 30.0
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Safe Base URL Validator
    private func validateAndFormatBaseURL(_ rawBase: String) throws -> String {
        var base = rawBase.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") {
            base.removeLast()
        }
        
        guard let url = URL(string: base), let scheme = url.scheme?.lowercased() else {
            throw NSError(domain: "NvidiaNIM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Geçersiz Base URL formatı."])
        }
        
        let host = url.host?.lowercased() ?? ""
        let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1"
        
        // Disallow insecure HTTP over non-localhost to protect API keys in transit
        if scheme == "http" && !isLocalhost {
            throw NSError(domain: "NvidiaNIM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Güvenlik Uyarısı: Uzak API bağlantıları için HTTPS zorunludur."])
        }
        
        guard scheme == "https" || (scheme == "http" && isLocalhost) else {
            throw NSError(domain: "NvidiaNIM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Desteklenmeyen URL protokolü. (https:// kullanın)"])
        }
        
        return base
    }
    
    // MARK: - Fetch Models from NVIDIA NIM API (/v1/models)
    public func fetchAvailableModels(config: NIMConfig) async throws -> [NIMModelOption] {
        let trimmedKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "NvidiaNIM", code: 401, userInfo: [NSLocalizedDescriptionKey: "NVIDIA NIM API Anahtarı eksik. Lütfen anahtarınızı girin."])
        }
        
        let base = try validateAndFormatBaseURL(config.baseURL)
        guard let url = URL(string: "\(base)/models") else {
            throw NSError(domain: "NvidiaNIM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Geçersiz /models URL'si."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MacOptimizer/2.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NvidiaNIM", code: 500, userInfo: [NSLocalizedDescriptionKey: "Sunucudan geçersiz HTTP yanıtı alındı."])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = (errorJson["error"] as? [String: Any])?["message"] as? String ?? errorJson["message"] as? String {
                throw NSError(domain: "NvidiaNIM", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "NVIDIA NIM Hatası (\(httpResponse.statusCode)): \(message)"])
            }
            throw NSError(domain: "NvidiaNIM", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Hata Kodu: \(httpResponse.statusCode)"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw NSError(domain: "NvidiaNIM", code: 500, userInfo: [NSLocalizedDescriptionKey: "Model listesi ayrıştırılamadı."])
        }
        
        var models: [NIMModelOption] = []
        
        for item in dataArray {
            guard let modelId = item["id"] as? String, !modelId.isEmpty else { continue }
            
            // Format display name and provider
            let parts = modelId.split(separator: "/")
            let providerName: String
            let cleanName: String
            
            if parts.count >= 2 {
                providerName = String(parts[0]).capitalized
                cleanName = String(parts[1])
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
            } else {
                providerName = (item["owned_by"] as? String)?.capitalized ?? "NVIDIA NIM"
                cleanName = modelId
            }
            
            let isRec = modelId.contains("llama-3.3-70b") || modelId.contains("deepseek-r1") || modelId.contains("nemotron")
            
            models.append(NIMModelOption(
                id: modelId,
                name: "\(cleanName) (\(modelId))",
                provider: providerName,
                description: "NVIDIA NIM üzerinden taranmış model.",
                isRecommended: isRec
            ))
        }
        
        // Sort: Recommended first, then alphabetical
        return models.sorted {
            if $0.isRecommended != $1.isRecommended {
                return $0.isRecommended && !$1.isRecommended
            }
            return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }
    }
    
    // MARK: - Test API Connection
    public func testConnection(config: NIMConfig) async -> (success: Bool, message: String) {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (false, "NVIDIA NIM API Anahtarı girilmedi. Lütfen 'nvapi-...' ile başlayan anahtarınızı girin.")
        }
        
        // Try testing with models endpoint first, then chat probe
        do {
            let models = try await fetchAvailableModels(config: config)
            return (true, "NVIDIA NIM bağlantısı başarılı! \(models.count) adet model tarandı.")
        } catch {
            // Fallback to chat test
            let testPrompt = "Test"
            let messages = [["role": "user", "content": testPrompt]]
            do {
                _ = try await sendChatCompletion(messages: messages, config: config, systemPrompt: "Kısa yanıt ver.")
                return (true, "NVIDIA NIM bağlantısı ve model ('\(config.selectedModel)') doğrulandı!")
            } catch {
                return (false, "Bağlantı hatası: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Send Chat Completion
    public func sendChatCompletion(
        messages: [[String: String]],
        config: NIMConfig,
        systemPrompt: String = ""
    ) async throws -> String {
        let trimmedKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "NvidiaNIM", code: 401, userInfo: [NSLocalizedDescriptionKey: "NVIDIA NIM API Anahtarı eksik."])
        }
        
        let base = try validateAndFormatBaseURL(config.baseURL)
        guard let url = URL(string: "\(base)/chat/completions") else {
            throw NSError(domain: "NvidiaNIM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Geçersiz /chat/completions URL formatı."])
        }
        
        var allMessages: [[String: String]] = []
        if !systemPrompt.isEmpty {
            allMessages.append(["role": "system", "content": systemPrompt])
        }
        allMessages.append(contentsOf: messages)
        
        let payload: [String: Any] = [
            "model": config.selectedModel,
            "messages": allMessages,
            "temperature": config.temperature,
            "max_tokens": config.maxTokens,
            "top_p": 0.95,
            "stream": false
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("MacOptimizer/2.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NvidiaNIM", code: 500, userInfo: [NSLocalizedDescriptionKey: "Sunucudan geçersiz HTTP yanıtı alındı."])
        }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = (errorJson["error"] as? [String: Any])?["message"] as? String ?? errorJson["message"] as? String {
                throw NSError(domain: "NvidiaNIM", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "NVIDIA NIM Hatası (\(httpResponse.statusCode)): \(message)"])
            }
            throw NSError(domain: "NvidiaNIM", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Hata Kodu: \(httpResponse.statusCode)"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "NvidiaNIM", code: 500, userInfo: [NSLocalizedDescriptionKey: "API yanıtı ayrıştırılamadı."])
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
