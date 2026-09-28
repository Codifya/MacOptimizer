import SwiftUI

/// View for AI-powered system health diagnostics, intelligent recommendations, and interactive Copilot chat.
/// Fully responsive across compact and expanded macOS windows.
public struct AICopilotView: View {
    @ObservedObject var appState: AppState
    @State private var selectedSubTab: AISubTab = .diagnostics
    @State private var chatInputText: String = ""
    
    enum AISubTab: String, CaseIterable, Identifiable {
        case diagnostics
        case chat
        
        var id: String { rawValue }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Hero
            aiHeaderHero
            
            // Sub-tabs Picker
            Picker("", selection: $selectedSubTab) {
                ForEach(AISubTab.allCases) { tab in
                    Text(l10n: tab.rawValue == AISubTab.diagnostics.rawValue ? "Smart Diagnostics & Report" : "AI Copilot Chat", table: .ai).tag(tab)
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
        .alert(L10n.string("Terminate this process?", table: .ai), isPresented: Binding(
            get: { appState.aiKillConfirmationPID != nil },
            set: { if !$0 { appState.aiKillConfirmationPID = nil } }
        )) {
            Button("Cancel", role: .cancel) { appState.aiKillConfirmationPID = nil }
            Button("Terminate Normally", role: .destructive) { appState.confirmAIProcessTermination() }
        } message: {
            Text(L10n.string("PID: %lld. SIGTERM will be sent first.", table: .ai, Int64(appState.aiKillConfirmationPID ?? 0)))
        }
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
                        Text(l10n: "AI Advisor & Copilot", table: .ai)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        if appState.nimConfig.isEnabled && !appState.nimConfig.apiKey.isEmpty {
                            MetricBadge(text: L10n.string("NVIDIA NIM: %@", table: .ai, String(appState.nimConfig.selectedModel.split(separator: "/").last ?? "")), colorName: "green")
                        } else {
                            MetricBadge(text: L10n.string("Local AI Engine", table: .ai), colorName: "blue")
                        }
                    }
                    
                    Text(l10n: "Analyze your Mac’s performance, memory pressure, and disk usage with AI.", table: .ai)
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
                            Text(l10n: "Reviewing system telemetry...", table: .ai)
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
                                            Text(l10n: msg.role == .user ? "You" : "MacOptimizer AI", table: .ai)
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
                                        Text(l10n: "Preparing a response...", table: .ai)
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
                        QuickChip(text: L10n.string("Why is my Mac overheating?", table: .ai)) {
                            chatInputText = L10n.string("Analyze my Mac’s CPU and memory and check what may be causing it to overheat.", table: .ai)
                            sendMessage()
                        }
                        QuickChip(text: L10n.string("Scan for Junk Files", table: .ai)) {
                            chatInputText = L10n.string("Scan for unnecessary caches and logs taking up disk space.", table: .ai)
                            sendMessage()
                        }
                        QuickChip(text: L10n.string("Top 3 Resource-Using Processes", table: .ai)) {
                            chatInputText = L10n.string("List the top three apps currently using the most RAM and CPU.", table: .ai)
                            sendMessage()
                        }
                    }
                }
                
                // Input Bar
                HStack(spacing: 8) {
                    TextField(L10n.string("Ask AI a question or give a command...", table: .ai), text: $chatInputText)
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
