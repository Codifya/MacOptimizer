import SwiftUI

/// View for AI-powered system health diagnostics, intelligent recommendations, and interactive Copilot chat.
/// Fully responsive across compact and expanded macOS windows.
public struct AICopilotView: View {
    @ObservedObject var appState: AppState
    @State private var selectedSubTab: AISubTab = .diagnostics
    @State private var chatInputText: String = ""
    
    enum AISubTab: String, CaseIterable, Identifiable {
        case diagnostics = "Akıllı Teşhis & Rapor"
        case chat = "AI Copilot Sohbet"
        
        var id: String { rawValue }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Hero
            aiHeaderHero
            
            // Sub-tabs Picker
            Picker("", selection: $selectedSubTab) {
                ForEach(AISubTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            
            // Sub-view Content
            if selectedSubTab == .diagnostics {
                diagnosticsSection
            } else {
                chatSection
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onAppear {
            if appState.aiInsights.isEmpty {
                appState.runAIHealthAnalysis()
            }
        }
    }
    
    // MARK: - Header Hero
    private var aiHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(SystemTheme.primaryGradient.opacity(0.15))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(SystemTheme.primaryGradient)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Yapay Zeka Danışmanı & Copilot")
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        if appState.nimConfig.isEnabled && !appState.nimConfig.apiKey.isEmpty {
                            MetricBadge(text: "NVIDIA NIM: \(appState.nimConfig.selectedModel.split(separator: "/").last ?? "")", colorName: "green")
                        } else {
                            MetricBadge(text: "Yerel AI Motoru", colorName: "blue")
                        }
                    }
                    
                    Text("Mac'inizin performansını, bellek darboğazlarını ve disk birikimlerini yapay zeka ile analiz edin.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 12)
                
                ActionButton(
                    title: appState.isAnalyzingAI ? "Analiz Ediliyor..." : "Sistemi Yeniden Analiz Et",
                    iconName: "sparkles",
                    gradient: SystemTheme.primaryGradient,
                    isLoading: appState.isAnalyzingAI
                ) {
                    appState.runAIHealthAnalysis()
                }
            }
        }
    }
    
    // MARK: - Diagnostics Section
    private var diagnosticsSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                if appState.aiInsights.isEmpty && !appState.isAnalyzingAI {
                    GlassCard(cornerRadius: 16, padding: 36) {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Sistem telemetrisi inceleniyor...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    ForEach(appState.aiInsights) { insight in
                        GlassCard(cornerRadius: 14, padding: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: insight.severity.iconName)
                                        .font(.system(size: 16))
                                        .foregroundColor(colorForSeverity(insight.severity))
                                    
                                    Text(insight.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    MetricBadge(text: insight.category, colorName: "purple")
                                    MetricBadge(text: insight.severity.rawValue, colorName: insight.severity.colorName)
                                }
                                
                                Text(insight.summary)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.85))
                                    .lineSpacing(2)
                                
                                if !insight.actions.isEmpty {
                                    HStack(spacing: 8) {
                                        ForEach(insight.actions) { action in
                                            Button {
                                                appState.executeAIAction(action)
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Image(systemName: action.type.iconName)
                                                    Text(action.title)
                                                }
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(SystemTheme.primaryGradient)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Interactive Chat Section
    private var chatSection: some View {
        GlassCard(cornerRadius: 16, padding: 12) {
            VStack(spacing: 10) {
                // Chat Message Bubbles
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.chatMessages) { msg in
                                HStack {
                                    if msg.role == .user { Spacer() }
                                    
                                    VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            if msg.role == .assistant {
                                                Image(systemName: "sparkles")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 11))
                                            }
                                            Text(msg.role == .user ? "Siz" : "MacOptimizer AI")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(msg.content)
                                            .font(.system(size: 13))
                                            .foregroundColor(msg.role == .user ? .white : .primary)
                                            .padding(10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(msg.role == .user ? Color.blue : Color.secondary.opacity(0.12))
                                            )
                                        
                                        if !msg.actions.isEmpty {
                                            HStack(spacing: 6) {
                                                ForEach(msg.actions) { action in
                                                    Button {
                                                        appState.executeAIAction(action)
                                                    } label: {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: action.type.iconName)
                                                            Text(action.title)
                                                        }
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(SystemTheme.primaryGradient)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: 580, alignment: msg.role == .user ? .trailing : .leading)
                                    
                                    if msg.role == .assistant { Spacer() }
                                }
                                .id(msg.id)
                            }
                            
                            if appState.isChatThinking {
                                HStack {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                        Text("Yapay zeka yanıtı hazırlıyor...")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: appState.chatMessages.count) { _, _ in
                        if let last = appState.chatMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Quick Suggestion Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        QuickChip(text: "RAM'i Boşalt") {
                            chatInputText = "Mac'imin RAM belleğini boşalt ve optimize et."
                            sendMessage()
                        }
                        QuickChip(text: "Neden Mac'im ısınıyor?") {
                            chatInputText = "Mac'imin işlemci ve bellek durumunu analiz et, ısınma sebebi var mı?"
                            sendMessage()
                        }
                        QuickChip(text: "Gereksiz Dosyaları Tara") {
                            chatInputText = "Disk alanımı dolduran gereksiz önbellek ve günlükleri tara."
                            sendMessage()
                        }
                        QuickChip(text: "En Çok Kaynak Kullanan 3 Süreç") {
                            chatInputText = "Şu anda en çok RAM ve CPU harcayan ilk 3 uygulamayı listele."
                            sendMessage()
                        }
                    }
                }
                
                // Input Bar
                HStack(spacing: 8) {
                    TextField("Yapay Zekaya bir soru sorun veya komut verin...", text: $chatInputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isChatThinking)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func sendMessage() {
        guard !chatInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = chatInputText
        chatInputText = ""
        appState.sendChatMessage(text)
    }
    
    private func colorForSeverity(_ sev: AIInsight.Severity) -> Color {
        switch sev {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        case .recommendation: return .green
        }
    }
}

private struct QuickChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
