import Foundation

/// Defines the selected AI Provider type
public enum AIProviderType: String, Codable, Sendable, CaseIterable, Identifiable {
    case localHeuristics = "local_heuristics"
    case nvidiaNIM = "nvidia_nim"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .localHeuristics: return "🛡️ " + L10n.string("Local Rule Engine (100% Offline & Secure)", table: .ai)
        case .nvidiaNIM: return "⚡ " + L10n.string("NVIDIA NIM (Cloud Llama 3.3 / DeepSeek R1)", table: .ai)
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
            description: L10n.string("Balanced, highly capable, fast-responding recommended model.", table: .ai),
            isRecommended: true
        ),
        NIMModelOption(
            id: "meta/llama-3.1-405b-instruct",
            name: "Llama 3.1 405B Instruct",
            provider: "Meta",
            description: L10n.string("Flagship model with the most comprehensive and deepest analysis capacity.", table: .ai),
            isRecommended: false
        ),
        NIMModelOption(
            id: "deepseek-ai/deepseek-r1",
            name: "DeepSeek R1",
            provider: "DeepSeek",
            description: L10n.string("Model specialized in deep reasoning and problem solving.", table: .ai),
            isRecommended: true
        ),
        NIMModelOption(
            id: "mistralai/mistral-large-2-instruct",
            name: "Mistral Large 2",
            provider: "Mistral AI",
            description: L10n.string("Advanced reasoning and code analysis.", table: .ai),
            isRecommended: false
        ),
        NIMModelOption(
            id: "nvidia/nemotron-4-340b-instruct",
            name: "NVIDIA Nemotron-4 340B",
            provider: "NVIDIA",
            description: L10n.string("Enterprise large language model trained by NVIDIA.", table: .ai),
            isRecommended: false
        ),
        NIMModelOption(
            id: "meta/llama-3.1-8b-instruct",
            name: "Llama 3.1 8B Instruct",
            provider: "Meta",
            description: L10n.string("Lightweight model for ultra-low-latency, fast system analysis.", table: .ai),
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

    private enum CodingKeys: String, CodingKey {
        case providerType, apiKey, baseURL, selectedModel, temperature, maxTokens, isEnabled, isManualEntry, cachedModels
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        providerType = (try? values.decode(AIProviderType.self, forKey: .providerType)) ?? .localHeuristics
        apiKey = (try? values.decode(String.self, forKey: .apiKey)) ?? ""
        baseURL = (try? values.decode(String.self, forKey: .baseURL)) ?? "https://integrate.api.nvidia.com/v1"
        selectedModel = (try? values.decode(String.self, forKey: .selectedModel)) ?? "meta/llama-3.3-70b-instruct"
        temperature = (try? values.decode(Double.self, forKey: .temperature)) ?? 0.3
        maxTokens = (try? values.decode(Int.self, forKey: .maxTokens)) ?? 1024
        isEnabled = (try? values.decode(Bool.self, forKey: .isEnabled)) ?? false
        isManualEntry = (try? values.decode(Bool.self, forKey: .isManualEntry)) ?? false
        cachedModels = (try? values.decode([NIMModelOption].self, forKey: .cachedModels)) ?? []
    }
    
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
