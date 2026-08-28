import SwiftUI
import AppKit

/// Settings and preferences view including Multi-Provider AI Platform (Local Heuristics, Ollama, NVIDIA NIM, OpenAI Compatible),
/// Model Scanner, Manual Entry, Autonomous Policies, and General Preferences.
/// Fully responsive across all macOS window sizes.
public struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    
    @State private var selectedProvider: AIProviderType = .localHeuristics
    @State private var apiKeyInput: String = ""
    @State private var baseURLInput: String = "https://integrate.api.nvidia.com/v1"
    @State private var selectedModel: String = "meta/llama-3.3-70b-instruct"
    @State private var manualModelInput: String = ""
    @State private var isNIMEnabled: Bool = false
    @State private var isKeyVisible: Bool = false
    @State private var modelSelectionMode: ModelEntryMode = .picker
    @State private var modelSearchQuery: String = ""
    
    @State private var isWatchdogActive: Bool = true
    @State private var autoPurgeRAM: Bool = true
    @State private var ramThreshold: Double = 85.0
    @State private var notifyOnAnomalies: Bool = true
    @State private var cpuRunawayThreshold: Double = 90.0
    
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    
    enum ModelEntryMode: String, CaseIterable, Identifiable {
        case picker = "Listeden Seç"
        case manual = "Manuel Model Adı Gir"
        
        var id: String { rawValue }
    }
    
    private var allAvailableModels: [NIMModelOption] {
        if !appState.nimConfig.cachedModels.isEmpty {
            return appState.nimConfig.cachedModels
        }
        return NIMAvailableModels.defaultModels
    }
    
    private var filteredModels: [NIMModelOption] {
        if modelSearchQuery.isEmpty {
            return allAvailableModels
        }
        return allAvailableModels.filter {
            $0.name.localizedCaseInsensitiveContains(modelSearchQuery) ||
            $0.id.localizedCaseInsensitiveContains(modelSearchQuery) ||
            $0.provider.localizedCaseInsensitiveContains(modelSearchQuery)
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Hero
                settingsHeaderHero
                
                // Multi-Provider AI Platform Card
                aiPlatformCard
                
                // Autonomous Watchdog Policies Card
                autonomousPoliciesCard
                
                // Menu Bar & Notifications Card
                generalPreferencesCard
                
                // About Card
                aboutCard
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onAppear {
            selectedProvider = appState.nimConfig.providerType
            apiKeyInput = appState.nimConfig.apiKey
            baseURLInput = appState.nimConfig.baseURL
            selectedModel = appState.nimConfig.selectedModel
            manualModelInput = appState.nimConfig.selectedModel
            isNIMEnabled = appState.nimConfig.isEnabled
            modelSelectionMode = appState.nimConfig.isManualEntry ? .manual : .picker
            
            isWatchdogActive = appState.autonomousConfig.isWatchdogActive
            autoPurgeRAM = appState.autonomousConfig.autoPurgeRAMOnSpike
            ramThreshold = appState.autonomousConfig.ramThresholdPercent
            notifyOnAnomalies = appState.autonomousConfig.notifyOnAnomalies
            cpuRunawayThreshold = appState.autonomousConfig.cpuRunawayThresholdPercent
        }
    }
    
    // MARK: - Header
    private var settingsHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ayarlar & Yapay Zeka Platformu")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    Text("Çoklu AI sağlayıcıları (Yerel/Bulut), Keychain anahtar kasası, otonom koruma eşikleri.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Multi-Provider AI Platform Card
    private var aiPlatformCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Yapay Zeka ve Teşhis Motoru", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Picker("", selection: $selectedProvider) {
                        ForEach(AIProviderType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 280)
                    .onChange(of: selectedProvider) { _, _ in
                        saveAIConfig()
                    }
                }
                
                Text("Mac'inizin sağlık teşhislerini yapacak ve Copilot sohbetini yönetecek yapay zeka sağlayıcısını seçin.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Divider()
                
                // PROVIDER 1: LOCAL HEURISTICS (100% Offline)
                if selectedProvider == .localHeuristics {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("100% Çevrimdışı ve Gizli Kural Motoru")
                                .font(.system(size: 13, weight: .bold))
                            Text("Sıfır ağ trafiği. Sistem telemetrisi doğrudan Darwin çekirdeğinden okunur ve hiçbir veri bilgisayarınızın dışına çıkmaz.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // PROVIDER 2: LOCAL OLLAMA
                if selectedProvider == .ollama {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yerel Ollama LLM Motoru (Cihaz Üzerinde)")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Mac'inizde çalışan Ollama (`localhost:11434`) üzerinden yerel açık kaynaklı yapay zeka modelleriyle etkileşime geçin.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ollama Base URL:")
                                .font(.system(size: 12, weight: .semibold))
                            TextField("http://localhost:11434", text: $baseURLInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: baseURLInput) { _, _ in saveAIConfig() }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ollama Model Adı (örn. llama3.2, deepseek-r1:8b, qwen2.5-coder):")
                                .font(.system(size: 12, weight: .semibold))
                            TextField("llama3.2", text: $selectedModel)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: selectedModel) { _, _ in saveAIConfig() }
                        }
                    }
                }
                
                // PROVIDER 3: NVIDIA NIM (Enterprise Cloud)
                if selectedProvider == .nvidiaNIM {
                    VStack(alignment: .leading, spacing: 12) {
                        // API Key Field with Keychain
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("NVIDIA NIM API Anahtarı (Keychain Korumalı):")
                                    .font(.system(size: 12, weight: .semibold))
                                
                                Spacer()
                                
                                Button("API Anahtarı Al (build.nvidia.com) ↗") {
                                    if let url = URL(string: "https://build.nvidia.com") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                            }
                            
                            HStack {
                                if isKeyVisible {
                                    TextField("nvapi-...", text: $apiKeyInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                } else {
                                    SecureField("nvapi-...", text: $apiKeyInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                }
                                
                                Button {
                                    isKeyVisible.toggle()
                                } label: {
                                    Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: apiKeyInput) { _, _ in saveAIConfig() }
                        }
                        
                        // Base URL
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NVIDIA Base URL:")
                                .font(.system(size: 12, weight: .semibold))
                            
                            TextField("https://integrate.api.nvidia.com/v1", text: $baseURLInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: baseURLInput) { _, _ in saveAIConfig() }
                        }
                        
                        // Model Selection Mode
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Model Listesi", selection: $selectedModel) {
                                ForEach(filteredModels) { model in
                                    Text("\(model.name)\(model.isRecommended ? " ★ (Önerilen)" : "")")
                                        .tag(model.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedModel) { _, newModel in
                                manualModelInput = newModel
                                saveAIConfig()
                            }
                        }
                        
                        // Test Button
                        HStack(spacing: 12) {
                            Button {
                                saveAIConfig()
                                appState.testNIMConnection()
                            } label: {
                                HStack(spacing: 6) {
                                    if appState.isTestingNIM {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "bolt.horizontal.fill")
                                    }
                                    Text(appState.isTestingNIM ? "Test Ediliyor..." : "NVIDIA NIM Bağlantısını Test Et")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.isTestingNIM || apiKeyInput.isEmpty)
                            
                            if let result = appState.nimTestResult {
                                HStack(spacing: 6) {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)
                                    Text(result.message)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(result.success ? .green : .red)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                
                // PROVIDER 4: CUSTOM OPENAI COMPATIBLE
                if selectedProvider == .customOpenAI {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Uç Nokta URL'si (Base URL):")
                                .font(.system(size: 12, weight: .semibold))
                            TextField("https://api.openai.com/v1 veya http://localhost:8000/v1", text: $baseURLInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: baseURLInput) { _, _ in saveAIConfig() }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Anahtarı (İsteğe Bağlı):")
                                .font(.system(size: 12, weight: .semibold))
                            SecureField("sk-...", text: $apiKeyInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: apiKeyInput) { _, _ in saveAIConfig() }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model Adı:")
                                .font(.system(size: 12, weight: .semibold))
                            TextField("gpt-4o / custom-model", text: $selectedModel)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: selectedModel) { _, _ in saveAIConfig() }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Autonomous Policies Card
    private var autonomousPoliciesCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Otonom İzleme & Otomatik Müdahale İlkeleri", systemImage: "shield.checkered")
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                    
                    Toggle("", isOn: $isWatchdogActive)
                        .toggleStyle(.switch)
                        .scaleEffect(0.9)
                        .onChange(of: isWatchdogActive) { _, _ in
                            saveAutonomous()
                        }
                }
                
                Toggle("RAM baskısı yükseldiğinde otomatik olarak belleği boşalt (Auto-Heal)", isOn: $autoPurgeRAM)
                    .font(.system(size: 12))
                    .onChange(of: autoPurgeRAM) { _, _ in saveAutonomous() }
                
                if autoPurgeRAM {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("RAM Otomatik Müdahale Eşiği:")
                                .font(.system(size: 12))
                            Spacer()
                            Text("%\(Int(ramThreshold))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        Slider(value: $ramThreshold, in: 70...95, step: 5)
                            .onChange(of: ramThreshold) { _, _ in saveAutonomous() }
                    }
                    .padding(.leading, 16)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Kaçak Süreç (Runaway CPU) Algılama Eşiği:")
                            .font(.system(size: 12))
                        Spacer()
                        Text("%\(Int(cpuRunawayThreshold))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Slider(value: $cpuRunawayThreshold, in: 75...98, step: 1)
                        .onChange(of: cpuRunawayThreshold) { _, _ in saveAutonomous() }
                }
                
                Toggle("Anomali tespit edildiğinde macOS bildirimi gönder", isOn: $notifyOnAnomalies)
                    .font(.system(size: 12))
                    .onChange(of: notifyOnAnomalies) { _, _ in saveAutonomous() }
            }
        }
    }
    
    // MARK: - General Preferences
    private var generalPreferencesCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Genel ve Menü Çubuğu", systemImage: "bell.fill")
                    .font(.system(size: 14, weight: .bold))
                
                Toggle("Menü Çubuğunda (Menu Bar) canlı durum simgesi göster", isOn: $showMenuBarExtra)
                    .font(.system(size: 12))
            }
        }
    }
    
    // MARK: - About Card
    private var aboutCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("MacOptimizer Pro 2.1")
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                    
                    MetricBadge(text: "Zero-Harm • Apache 2.0", colorName: "green")
                }
                
                Text("Açık kaynaklı, güvenlik öncelikli, yerel macOS sistem sağlığı ve optimizasyon araç seti.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func saveAIConfig() {
        var conf = appState.nimConfig
        conf.providerType = selectedProvider
        conf.apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        conf.baseURL = baseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let finalModel = (modelSelectionMode == .manual ? manualModelInput : selectedModel).trimmingCharacters(in: .whitespacesAndNewlines)
        conf.selectedModel = finalModel.isEmpty ? "meta/llama-3.3-70b-instruct" : finalModel
        conf.isEnabled = (selectedProvider == .nvidiaNIM || selectedProvider == .ollama || selectedProvider == .customOpenAI)
        conf.isManualEntry = (modelSelectionMode == .manual)
        appState.saveNIMConfig(conf)
    }
    
    private func saveAutonomous() {
        var conf = appState.autonomousConfig
        conf.isWatchdogActive = isWatchdogActive
        conf.autoPurgeRAMOnSpike = autoPurgeRAM
        conf.ramThresholdPercent = ramThreshold
        conf.cpuRunawayThresholdPercent = cpuRunawayThreshold
        conf.notifyOnAnomalies = notifyOnAnomalies
        appState.saveAutonomousConfig(conf)
    }
}
