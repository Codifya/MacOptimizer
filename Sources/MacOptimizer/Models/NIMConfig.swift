import Foundation

/// Defines the selected AI Provider type
public enum AIProviderType: String, Codable, Sendable, CaseIterable, Identifiable {
    case localHeuristics = "local_heuristics"
    case ollama = "ollama"
    case nvidiaNIM = "nvidia_nim"
    case customOpenAI = "custom_openai"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .localHeuristics: return "🛡️ Yerel Kural Motoru (100% Çevrimdışı & Güvenli)"
        case .ollama: return "🦙 Yerel Ollama (Cihaz Üzerinde LLM)"
        case .nvidiaNIM: return "⚡ NVIDIA NIM (Bulut Llama 3.3 / DeepSeek R1)"
        case .customOpenAI: return "🌐 Özel / OpenAI Uyumlu Uç Nokta"
        }
    }
}

/// NVIDIA NIM Model definition and settings
public struct NIMModelOption: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let provider: String
    public let description: String
    public let isRecommended: Bool
    
    public init(id: String, name: String, provider: String = "NVIDIA NIM", description: String = "", isRecommended: Bool = false) {
        self.id = id
        self.name = name
        self.provider = provider
        self.description = description
        self.isRecommended = isRecommended
    }
}

/// Built-in recommended fallback models for NVIDIA NIM
public enum NIMAvailableModels {
    public static let defaultModels: [NIMModelOption] = [
        NIMModelOption(
            id: "meta/llama-3.3-70b-instruct",
            name: "Llama 3.3 70B Instruct",
            provider: "Meta",
            description: "Dengeli, yüksek zekâ ve hızlı yanıt veren önerilen model.",
            isRecommended: true
        ),
        NIMModelOption(
            id: "meta/llama-3.1-405b-instruct",
            name: "Llama 3.1 405B Instruct",
            provider: "Meta",
            description: "En kapsamlı ve en derin analiz kapasitesine sahip amiral gemisi model.",
            isRecommended: false
        ),
        NIMModelOption(
            id: "deepseek-ai/deepseek-r1",
            name: "DeepSeek R1",
            provider: "DeepSeek",
            description: "Derin akıl yürütme ve problem çözmede uzmanlaşmış model.",
            isRecommended: true
        ),
        NIMModelOption(
            id: "mistralai/mistral-large-2-instruct",
            name: "Mistral Large 2",
            provider: "Mistral AI",
            description: "İleri düzey mantık yürütme ve kod analizi.",
            isRecommended: false
        ),
        NIMModelOption(
            id: "nvidia/nemotron-4-340b-instruct",
            name: "NVIDIA Nemotron-4 340B",
            provider: "NVIDIA",
            description: "NVIDIA tarafından eğitilmiş kurumsal büyük dil modeli.",
            isRecommended: false
        ),
        NIMModelOption(
            id: "meta/llama-3.1-8b-instruct",
            name: "Llama 3.1 8B Instruct",
            provider: "Meta",
            description: "Ultra düşük gecikmeli, hızlı sistem analizi için hafif model.",
            isRecommended: false
        )
    ]
}

/// Configuration settings for AI providers & NVIDIA NIM API integration
public struct NIMConfig: Codable, Sendable, Equatable {
    public var providerType: AIProviderType
    public var apiKey: String
    public var baseURL: String
    public var selectedModel: String
    public var temperature: Double
    public var maxTokens: Int
    public var isEnabled: Bool
    public var isManualEntry: Bool
    public var cachedModels: [NIMModelOption]
    
    public init(
        providerType: AIProviderType = .localHeuristics,
        apiKey: String = "",
        baseURL: String = "https://integrate.api.nvidia.com/v1",
        selectedModel: String = "meta/llama-3.3-70b-instruct",
        temperature: Double = 0.3,
        maxTokens: Int = 1024,
        isEnabled: Bool = false,
        isManualEntry: Bool = false,
        cachedModels: [NIMModelOption] = []
    ) {
        self.providerType = providerType
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.selectedModel = selectedModel
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.isEnabled = isEnabled
        self.isManualEntry = isManualEntry
        self.cachedModels = cachedModels
    }
}
