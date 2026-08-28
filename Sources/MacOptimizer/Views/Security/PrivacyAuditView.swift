import SwiftUI

/// View displaying macOS security posture, SIP protection, Gatekeeper, and Firewall state.
/// Fully responsive across compact, standard, and wide macOS displays.
public struct PrivacyAuditView: View {
    @ObservedObject var appState: AppState
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Hero
                securityHeaderHero
                
                if appState.isLoadingSecurityAudit {
                    loadingView
                } else if let report = appState.securityReport {
                    // Security Score Hero Card
                    scoreSummaryCard(report: report)
                    
                    // Posture Items Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                        ForEach(report.items) { item in
                            postureItemCard(item: item)
                        }
                    }
                } else {
                    emptyAuditView
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onAppear {
            if appState.securityReport == nil {
                appState.auditSecurityPosture()
            }
        }
    }
    
    // MARK: - Header Hero
    private var securityHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Güvenlik & Gizlilik Denetimi")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    Text("macOS çekirdek koruma durumu (SIP), Gatekeeper, Güvenlik Duvarı ve sistem izinlerini denetleyin.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 12)
                
                ActionButton(
                    title: appState.isLoadingSecurityAudit ? "Denetleniyor..." : "Yeniden Denetle",
                    iconName: "arrow.clockwise",
                    gradient: SystemTheme.successGradient,
                    isLoading: appState.isLoadingSecurityAudit
                ) {
                    appState.auditSecurityPosture()
                }
            }
        }
    }
    
    // MARK: - Score Summary Card
    private func scoreSummaryCard(report: SecurityAuditReport) -> some View {
        GlassCard(cornerRadius: 16, padding: 20) {
            HStack(spacing: 20) {
                // Score Gauge Ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                        .frame(width: 72, height: 72)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(report.score) / 100.0)
                        .stroke(
                            report.score >= 80 ? Color.green : (report.score >= 60 ? Color.orange : Color.red),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)
                    
                    Text("\(report.score)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(report.ratingDescription)
                            .font(.system(size: 15, weight: .bold))
                        
                        MetricBadge(text: "/100 Puan", colorName: report.ratingColorName)
                    }
                    
                    Text("macOS yerel güvenlik mekanizmaları incelendi. Sistemin temel bütünlüğü ve yetkisiz müdahale direnci ölçüldü.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Posture Item Card
    private func postureItemCard(item: SecurityPostureItem) -> some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: item.isSecure ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(item.isSecure ? .green : .red)
                        
                        Text(item.title)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    MetricBadge(text: item.statusText, colorName: item.severity.badgeColor)
                }
                
                Text(item.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                Divider()
                
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .padding(.top, 1)
                    
                    Text(item.recommendation)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }
    
    // MARK: - Loading & Empty
    private var loadingView: some View {
        GlassCard(cornerRadius: 16, padding: 36) {
            VStack(spacing: 12) {
                ProgressView()
                Text("macOS Güvenlik Ayarları Denetleniyor...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var emptyAuditView: some View {
        GlassCard(cornerRadius: 16, padding: 36) {
            VStack(spacing: 14) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 44))
                    .foregroundStyle(SystemTheme.successGradient)
                
                Text("Güvenlik Denetimi Başlatılmadı")
                    .font(.system(size: 16, weight: .bold))
                
                ActionButton(
                    title: "Denetimi Başlat",
                    iconName: "play.fill",
                    gradient: SystemTheme.successGradient
                ) {
                    appState.auditSecurityPosture()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
