import SwiftUI

/// View for Autonomous Watchdog system, live anomaly detection radar, and auto-healing activity feed.
/// Fully responsive across all macOS window dimensions.
public struct AutonomousGuardView: View {
    @ObservedObject var appState: AppState
    @State private var isRadarPulsing = false
    
    private var resolvedCount: Int {
        appState.autonomousAlerts.filter { $0.isResolved || $0.autoHealed }.count
    }
    
    private var autoHealedCount: Int {
        appState.autonomousAlerts.filter { $0.autoHealed }.count
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Radar & Status Hero
                guardHeaderHero
                
                // Metrics Overview (Responsive Grid)
                metricsRow
                
                // Anomaly & Auto-Heal Activity Feed
                activityFeedSection
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isRadarPulsing = true
            }
        }
    }
    
    // MARK: - Header Hero
    private var guardHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: isRadarPulsing ? 10 : 2)
                        .scaleEffect(isRadarPulsing ? 1.15 : 0.95)
                        .frame(width: 56, height: 56)
                    
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Otonom Sistem Koruması & Watchdog")
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        MetricBadge(
                            text: appState.autonomousConfig.isWatchdogActive ? "Aktif" : "Devre Dışı",
                            colorName: appState.autonomousConfig.isWatchdogActive ? "green" : "gray"
                        )
                    }
                    
                    Text("Bellek baskılarını, donan arka plan süreçlerini ve disk tıkanıklıklarını sürekli gözlemler; gerektiğinde otomatik müdahale eder.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 12)
                
                Toggle("", isOn: Binding(
                    get: { appState.autonomousConfig.isWatchdogActive },
                    set: { val in
                        var newConf = appState.autonomousConfig
                        newConf.isWatchdogActive = val
                        appState.saveAutonomousConfig(newConf)
                    }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.9)
            }
        }
    }
    
    // MARK: - Metrics Row (Responsive Adaptive Grid)
    private var metricsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            GlassCard(cornerRadius: 14, padding: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.green)
                        Text("Otomatik İyileştirme")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Text("\(autoHealedCount) Olay")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GlassCard(cornerRadius: 14, padding: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Bekleyen Uyarılar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Text("\(appState.unresolvedAlertsCount) Bekliyor")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(appState.unresolvedAlertsCount > 0 ? .orange : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GlassCard(cornerRadius: 14, padding: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Çözülen Olaylar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Text("\(resolvedCount) Çözüldü")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Activity Feed
    private var activityFeedSection: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Otonom İzleme & Anomali Günlüğü", systemImage: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                    
                    if !appState.autonomousAlerts.isEmpty {
                        Button("Günlüğü Temizle") {
                            appState.clearAutonomousAlerts()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }
                }
                
                if appState.autonomousAlerts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green.opacity(0.8))
                        
                        Text("Sistemde Herhangi Bir Anomali Yok")
                            .font(.system(size: 14, weight: .bold))
                        
                        Text("Arka plan denetleyicisi sistemi izliyor. Olağandışı bir durum veya bellek baskısı olduğunda burada listelenecektir.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    VStack(spacing: 8) {
                        ForEach(appState.autonomousAlerts) { alert in
                            HStack(spacing: 12) {
                                Image(systemName: alert.type.iconName)
                                    .font(.system(size: 16))
                                    .foregroundColor(colorForAlert(alert.type))
                                    .frame(width: 30, height: 30)
                                    .background(colorForAlert(alert.type).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(alert.title)
                                            .font(.system(size: 12, weight: .bold))
                                            .lineLimit(1)
                                        
                                        if alert.autoHealed {
                                            MetricBadge(text: "Otomatik İyileştirildi", colorName: "green")
                                        } else if alert.isResolved {
                                            MetricBadge(text: "Çözüldü", colorName: "blue")
                                        } else {
                                            MetricBadge(text: "Aktif Uyarı", colorName: "orange")
                                        }
                                    }
                                    
                                    Text(alert.message)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer(minLength: 6)
                                
                                Text(alert.formattedTime)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                
                                if let action = alert.action, !alert.isResolved {
                                    Button {
                                        appState.executeAIAction(action)
                                        appState.resolveAutonomousAlert(id: alert.id)
                                    } label: {
                                        Text(action.title)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(SystemTheme.primaryGradient)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func colorForAlert(_ type: AutonomousAlert.AlertType) -> Color {
        switch type {
        case .memorySpike: return .orange
        case .runawayProcess: return .red
        case .lowDisk: return .pink
        case .batteryDrain: return .yellow
        case .outdatedSecurity: return .purple
        case .routineMaintenance: return .blue
        }
    }
}
