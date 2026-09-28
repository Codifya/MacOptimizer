import SwiftUI
import AppKit

/// Settings and preferences view including local and NVIDIA NIM AI providers,
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
    @State private var showCloudDisclosure = false
    @AppStorage("MacOptimizer_NIMDisclosureAccepted") private var cloudDisclosureAccepted = false
    @AppStorage("MacOptimizer_IncludeRunningAppNames") private var includeRunningAppNames = false
    
    @State private var isWatchdogActive: Bool = true
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
        .sheet(isPresented: $showCloudDisclosure) {
            VStack(alignment: .leading, spacing: 14) {
                Text(l10n: "NVIDIA NIM data sharing", table: .ai).font(.headline)
                Text(l10n: "When the cloud provider is enabled, NVIDIA NIM receives: Mac hardware model, chip, macOS version, RAM/CPU/disk percentages, junk file size, and your chat messages.", table: .ai)
                Text(l10n: "Running app names are not sent by default. If you turn this on, app names and process IDs are also sent to NVIDIA NIM.", table: .ai)
                HStack {
                    Button(L10n.string("Cancel", table: .ai)) { selectedProvider = .localHeuristics; saveAIConfig(); showCloudDisclosure = false }
                    Spacer()
                    Button(L10n.string("Enable", table: .ai)) { cloudDisclosureAccepted = true; saveAIConfig(); showCloudDisclosure = false }.keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 460)
        }
        .onAppear {
            selectedProvider = appState.nimConfig.providerType
            apiKeyInput = appState.nimConfig.apiKey
            baseURLInput = appState.nimConfig.baseURL
            selectedModel = appState.nimConfig.selectedModel
            manualModelInput = appState.nimConfig.selectedModel
            isNIMEnabled = appState.nimConfig.isEnabled
            modelSelectionMode = appState.nimConfig.isManualEntry ? .manual : .picker
            
            isWatchdogActive = appState.autonomousConfig.isWatchdogActive
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
                    Text(l10n: "Settings & AI Platform", table: .ai)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    Text(l10n: "Multiple AI providers (local/cloud), Keychain key vault, autonomous protection thresholds.", table: .ai)
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
                    Label(L10n.string("AI & Diagnostics Engine", table: .ai), systemImage: "sparkles")
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
                    .onChange(of: selectedProvider) { _, value in
                        if value == .nvidiaNIM && !cloudDisclosureAccepted { showCloudDisclosure = true }
                        saveAIConfig()
                    }
                }
                
                Text(l10n: "Choose the AI provider that will run your Mac’s health diagnostics and manage the Copilot chat.", table: .ai)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                if selectedProvider == .nvidiaNIM {
                    Text(l10n: "NVIDIA NIM receives: hardware model, chip, macOS version, RAM/CPU/disk percentages, junk file size, and chat messages.", table: .ai)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    Toggle(L10n.string("Include running app names", table: .ai), isOn: $includeRunningAppNames)
                        .font(.system(size: 12))
                }
                Divider()
                
                // PROVIDER 1: LOCAL HEURISTICS (100% Offline)
                if selectedProvider == .localHeuristics {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(l10n: "100% Offline and Private Rule Engine", table: .ai)
                                .font(.system(size: 13, weight: .bold))
                            Text(l10n: "Zero network traffic. System telemetry is read directly from the Darwin kernel and no data ever leaves your computer.", table: .ai)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // PROVIDER 3: NVIDIA NIM (Enterprise Cloud)
                if selectedProvider == .nvidiaNIM {
                    VStack(alignment: .leading, spacing: 12) {
                        // API Key Field with Keychain
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(l10n: "NVIDIA NIM API Key (Keychain Protected):", table: .ai)
                                    .font(.system(size: 12, weight: .semibold))
                                
                                Spacer()
                                
                                Button(L10n.string("Get API Key (build.nvidia.com) ↗", table: .ai)) {
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
                            Text(l10n: "NVIDIA Base URL:", table: .ai)
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
                            Picker(L10n.string("Model List", table: .ai), selection: $selectedModel) {
                                ForEach(filteredModels) { model in
                                    Text(verbatim: model.isRecommended ? L10n.string("%@ ★ (Recommended)", table: .ai, model.name) : model.name)
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
                                    Text(l10n: appState.isTestingNIM ? "Testing..." : "Test NVIDIA NIM Connection", table: .ai)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.isTestingNIM || apiKeyInput.isEmpty || !cloudDisclosureAccepted)
                            
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
                

            }
        }
    }
    
    // MARK: - Autonomous Policies Card
    private var autonomousPoliciesCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(L10n.string("Autonomous Monitoring & Automatic Intervention Policies", table: .ai), systemImage: "shield.checkered")
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                    
                    Toggle("", isOn: $isWatchdogActive)
                        .toggleStyle(.switch)
                        .scaleEffect(0.9)
                        .onChange(of: isWatchdogActive) { _, _ in
                            saveAutonomous()
                        }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l10n: "Memory Pressure Warning Threshold:", table: .ai)
                            .font(.system(size: 12))
                        Spacer()
                        Text(verbatim: L10n.string("%lld%%", table: .ai, Int64(ramThreshold)))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    Slider(value: $ramThreshold, in: 70...95, step: 5)
                        .onChange(of: ramThreshold) { _, _ in saveAutonomous() }
                }
                .padding(.leading, 16)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l10n: "Runaway Process (CPU) Detection Threshold:", table: .ai)
                            .font(.system(size: 12))
                        Spacer()
                        Text(verbatim: L10n.string("%lld%%", table: .ai, Int64(cpuRunawayThreshold)))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Slider(value: $cpuRunawayThreshold, in: 75...98, step: 1)
                        .onChange(of: cpuRunawayThreshold) { _, _ in saveAutonomous() }
                }
                
                Toggle(L10n.string("Send a macOS notification when an anomaly is detected", table: .ai), isOn: $notifyOnAnomalies)
                    .font(.system(size: 12))
                    .onChange(of: notifyOnAnomalies) { _, _ in saveAutonomous() }
            }
        }
    }
    
    // MARK: - General Preferences
    private var generalPreferencesCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.string("General & Menu Bar", table: .ai), systemImage: "bell.fill")
                    .font(.system(size: 14, weight: .bold))
                
                Toggle(L10n.string("Show live status icon in the menu bar", table: .ai), isOn: $showMenuBarExtra)
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
                
                Text(l10n: "Open-source, security-first, local macOS system health and optimization toolkit.", table: .ai)
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
        conf.isEnabled = (selectedProvider == .nvidiaNIM && cloudDisclosureAccepted)
        conf.isManualEntry = (modelSelectionMode == .manual)
        appState.saveNIMConfig(conf)
    }
    
    private func saveAutonomous() {
        var conf = appState.autonomousConfig
        conf.isWatchdogActive = isWatchdogActive
        conf.ramThresholdPercent = ramThreshold
        conf.cpuRunawayThresholdPercent = cpuRunawayThreshold
        conf.notifyOnAnomalies = notifyOnAnomalies
        appState.saveAutonomousConfig(conf)
    }
}
