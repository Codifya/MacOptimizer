import SwiftUI
import AppKit

/// Settings and preferences view including NVIDIA NIM API Configuration, Model Scanner, Manual Entry, and Autonomous Policies.
/// Fully responsive across all macOS window sizes.
public struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    
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
                
                // NVIDIA NIM Configuration Card
                nvidiaNIMCard
                
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
                    Text("Ayarlar & Yapay Zeka Entegrasyonu")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    Text("NVIDIA NIM API bağlantısı, model tarayıcısı, otonom koruma eşikleri ve genel tercihler.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - NVIDIA NIM Card
    private var nvidiaNIMCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("NVIDIA NIM (Yapay Zeka Servisi) Bağlantısı", systemImage: "cpu.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isNIMEnabled)
                        .toggleStyle(.switch)
                        .scaleEffect(0.9)
                        .onChange(of: isNIMEnabled) { _, _ in
                            saveNIM()
                        }
                }
                
                Text("NVIDIA NIM Inference Microservices ile Llama 3.3 70B, DeepSeek R1 veya kendi özel yerel modelinizi bağlayın.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Divider()
                
                // API Key Field
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("NVIDIA NIM API Anahtarı:")
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
                }
                
                // Base URL
                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL (Bulut veya Yerel NIM Container):")
                        .font(.system(size: 12, weight: .semibold))
                    
                    TextField("https://integrate.api.nvidia.com/v1", text: $baseURLInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Divider()
                
                // Model Selection Mode Segmented Control (Responsive ViewThatFits)
                VStack(alignment: .leading, spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("Model Belirleme Yöntemi:")
                                .font(.system(size: 12, weight: .semibold))
                            
                            Spacer()
                            
                            Picker("", selection: $modelSelectionMode) {
                                ForEach(ModelEntryMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 260)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Model Belirleme Yöntemi:")
                                .font(.system(size: 12, weight: .semibold))
                            
                            Picker("", selection: $modelSelectionMode) {
                                ForEach(ModelEntryMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .onChange(of: modelSelectionMode) { _, newMode in
                        if newMode == .manual {
                            manualModelInput = selectedModel
                        }
                        saveNIM()
                    }
                    
                    // MODE 1: PICKER FROM SCANNED/DEFAULT LIST
                    if modelSelectionMode == .picker {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Seçili Model: \(selectedModel)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                                
                                Spacer(minLength: 8)
                                
                                // Scan Models Button
                                Button {
                                    saveNIM()
                                    appState.scanRemoteNIMModels()
                                } label: {
                                    HStack(spacing: 4) {
                                        if appState.isScanningNIMModels {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                        }
                                        Text(appState.isScanningNIMModels ? "Modeller Taranıyor..." : "Modelleri API'den Tara")
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .disabled(appState.isScanningNIMModels || apiKeyInput.isEmpty)
                            }
                            
                            if !appState.nimConfig.cachedModels.isEmpty {
                                Text("✓ API'den \(appState.nimConfig.cachedModels.count) adet model başarıyla yüklendi.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                            
                            // Dropdown Picker
                            Picker("Model Listesi", selection: $selectedModel) {
                                ForEach(filteredModels) { model in
                                    Text("\(model.name)\(model.isRecommended ? " ★ (Önerilen)" : "")")
                                        .tag(model.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedModel) { _, newModel in
                                manualModelInput = newModel
                                saveNIM()
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // MODE 2: MANUAL MODEL NAME ENTRY
                    if modelSelectionMode == .manual {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model Adını Elle Girin (örn. meta/llama-3.3-70b-instruct veya yerel model kimliği):")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            TextField("Model adını yazın (örn. meta/llama-3.3-70b-instruct)", text: $manualModelInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: manualModelInput) { _, newVal in
                                    selectedModel = newVal
                                    saveNIM()
                                }
                            
                            // Quick Preset Chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    Text("Örnekler:")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    PresetChip(title: "Llama 3.3 70B", id: "meta/llama-3.3-70b-instruct") { id in
                                        manualModelInput = id
                                        selectedModel = id
                                        saveNIM()
                                    }
                                    PresetChip(title: "DeepSeek R1", id: "deepseek-ai/deepseek-r1") { id in
                                        manualModelInput = id
                                        selectedModel = id
                                        saveNIM()
                                    }
                                    PresetChip(title: "Mistral Large 2", id: "mistralai/mistral-large-2-instruct") { id in
                                        manualModelInput = id
                                        selectedModel = id
                                        saveNIM()
                                    }
                                    PresetChip(title: "Nemotron 340B", id: "nvidia/nemotron-4-340b-instruct") { id in
                                        manualModelInput = id
                                        selectedModel = id
                                        saveNIM()
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Divider()
                
                // Test & Save Controls
                HStack(spacing: 12) {
                    Button {
                        saveNIM()
                        appState.testNIMConnection()
                    } label: {
                        HStack(spacing: 6) {
                            if appState.isTestingNIM {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "bolt.horizontal.fill")
                            }
                            Text(appState.isTestingNIM ? "Test Ediliyor..." : "Bağlantıyı Test Et & Kaydet")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isTestingNIM)
                    
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
                .padding(.top, 2)
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
                    Text("MacOptimizer Pro 2.0")
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                    
                    MetricBadge(text: "Apple Silicon Native + NVIDIA NIM", colorName: "blue")
                }
                
                Text("Gelişmiş RAM optimizasyonu, derin gereksiz dosya temizliği, Sparkle/Homebrew güncelleme denetimi, 7/24 otonom koruma ve NVIDIA NIM yapay zeka danışmanı.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func saveNIM() {
        var conf = appState.nimConfig
        conf.apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        conf.baseURL = baseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let finalModel = (modelSelectionMode == .manual ? manualModelInput : selectedModel).trimmingCharacters(in: .whitespacesAndNewlines)
        conf.selectedModel = finalModel.isEmpty ? "meta/llama-3.3-70b-instruct" : finalModel
        conf.isEnabled = isNIMEnabled
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

private struct PresetChip: View {
    let title: String
    let id: String
    let onSelect: (String) -> Void
    
    var body: some View {
        Button {
            onSelect(id)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
