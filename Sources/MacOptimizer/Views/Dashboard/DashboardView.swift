import SwiftUI

/// Dashboard overview displaying real-time metrics, AI health status, hardware info, quick optimizer, and process list.
/// Fully responsive across compact, standard, and ultra-wide macOS displays.
///
/// State isolation: this view observes only `AppState` (user-driven, low-frequency state). Every
/// section that renders live metrics is a separate subview observing `LiveMetricsStore`, so a
/// metrics tick re-evaluates those sections only — not the AI banner, hero card or quick actions.
public struct DashboardView: View {
    @ObservedObject var appState: AppState
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header: System & Hardware Info
                headerView
                
                // AI & Autonomous Guard Banner (Responsive Grid)
                aiAndGuardStatusBanner
                
                // One-Click Smart Optimization Hero Card
                smartOptimizationHero
                
                // Real-Time Gauges Grid (RAM, CPU, Disk, Battery - Adaptive 2 to 4 columns)
                DashboardGaugesGrid(metrics: appState.metrics)
                
                // Live Observability Telemetry History Chart (Swift Charts)
                TelemetryHistoryCard(metrics: appState.metrics)
                
                // Segmented Memory Breakdown, Battery Health & Network Throughput
                DashboardLiveDetailCards(metrics: appState.metrics)
                
                // Bottom Section: Top Processes & Quick Maintenance (Responsive 1 or 2 columns)
                bottomProcessesAndUtilitiesSection
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onAppear {
            if appState.aiInsights.isEmpty {
                appState.runAIHealthAnalysis()
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center) {
            DashboardHardwareHeader(
                metrics: appState.metrics,
                aiProviderName: appState.nimConfig.isEnabled ? appState.nimConfig.providerType.displayName : nil
            )
            
            Spacer(minLength: 12)
            
            Button {
                appState.refreshMetrics(fullProcessRefresh: true)
                appState.runAIHealthAnalysis()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Metrikleri ve AI Teşhisini Yenile")
        }
    }
    
    // MARK: - AI & Autonomous Guard Status Banner (Responsive Grid)
    private var aiAndGuardStatusBanner: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 14)], spacing: 14) {
            // AI Diagnostic Summary Card
            GlassCard(cornerRadius: 14, padding: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("AI Sistem Sağlığı")
                                .font(.system(size: 13, weight: .bold))
                            
                            if let firstInsight = appState.aiInsights.first {
                                MetricBadge(text: firstInsight.severity.rawValue, colorName: firstInsight.severity.colorName)
                            }
                        }
                        
                        if let firstInsight = appState.aiInsights.first {
                            Text(firstInsight.title)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("Analiz bekleniyor...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("İncele →") {
                        appState.selectedTab = .aiCopilot
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
            
            // Autonomous Guard Status Card
            GlassCard(cornerRadius: 14, padding: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Otonom Koruma")
                                .font(.system(size: 13, weight: .bold))
                            
                            MetricBadge(
                                text: appState.autonomousConfig.isWatchdogActive ? "Aktif" : "Kapalı",
                                colorName: appState.autonomousConfig.isWatchdogActive ? "green" : "gray"
                            )
                        }
                        
                        if appState.unresolvedAlertsCount > 0 {
                            Text("\(appState.unresolvedAlertsCount) anomali incelenmeyi bekliyor")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                                .lineLimit(1)
                        } else {
                            Text("Sistem 7/24 arka planda izleniyor")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Günlük →") {
                        appState.selectedTab = .autonomousGuard
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - One-Click Smart Clean Hero
    private var smartOptimizationHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(SystemTheme.primaryGradient.opacity(0.15))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(SystemTheme.primaryGradient)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mac'inizi Tek Tıkla Optimize Edin")
                        .font(.system(size: 15, weight: .bold))
                    
                    Text("RAM önbelleğini boşaltır, sistem ve tarayıcı önbelleklerini temizler, ağ bağlantılarını yeniler.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    if appState.isOptimizingSmart {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.smartOptStatus)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                            
                            AnimatedProgressBar(progress: appState.smartOptProgress, gradient: SystemTheme.primaryGradient, height: 5)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 12)
                
                ActionButton(
                    title: appState.isOptimizingSmart ? "Optimize Ediliyor..." : "Akıllı İyileştir",
                    iconName: "bolt.fill",
                    gradient: SystemTheme.primaryGradient,
                    isLoading: appState.isOptimizingSmart
                ) {
                    appState.runSmartOptimization()
                }
            }
        }
    }
    
    // MARK: - Bottom Section (Responsive Grid)
    private var bottomProcessesAndUtilitiesSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
            LiveTopProcessesCard(
                metrics: appState.metrics,
                onKill: { pid in
                    appState.killProcess(pid: pid)
                },
                onNavigateToMemory: {
                    appState.selectedTab = .memory
                }
            )
            
            quickUtilitiesCard
        }
    }
    
    // MARK: - Quick Utilities Card
    private var quickUtilitiesCard: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Hızlı İşlemler", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                
                VStack(spacing: 8) {
                    QuickActionButton(
                        title: "RAM Belleği Boşalt",
                        subtitle: "Aktif olmayan önbellekleri serbest bırakır",
                        icon: "memorychip",
                        color: .green
                    ) {
                        appState.purgeRAM()
                    }
                    
                    QuickActionButton(
                        title: "Gereksiz Dosyaları Tara",
                        subtitle: "Önbellek, log ve kalıntıları tespit et",
                        icon: "trash.fill",
                        color: .purple
                    ) {
                        appState.selectedTab = .junkCleaner
                        appState.scanJunk()
                    }
                    
                    QuickActionButton(
                        title: "Uygulama Güncellemelerini Denetle",
                        subtitle: "Tüm yüklü uygulamaları tara",
                        icon: "arrow.triangle.2.circlepath",
                        color: .orange
                    ) {
                        appState.selectedTab = .appUpdates
                        appState.scanApps()
                        appState.checkAllAppUpdates()
                    }
                    
                    QuickActionButton(
                        title: "DNS Önbelleğini Temizle",
                        subtitle: "Ağ yanıt gecikmelerini sıfırla",
                        icon: "network",
                        color: .blue
                    ) {
                        Task {
                            let res = await MaintenanceService.shared.flushDNSCache()
                            appState.showNotification(message: res.message)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 6)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(8)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live metric sections

/// Model, chip, thermal state, OS and uptime. Badges collapse on narrow windows instead of truncating.
private struct DashboardHardwareHeader: View {
    @ObservedObject var metrics: LiveMetricsStore
    let aiProviderName: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    modelTitle
                    MetricBadge(text: metrics.hardwareInfo.chipName, colorName: "blue")
                    thermalBadge
                    if let aiProviderName {
                        MetricBadge(text: aiProviderName, colorName: "purple")
                    }
                }
                HStack(spacing: 8) {
                    modelTitle
                    thermalBadge
                }
                modelTitle
            }
            
            Text("\(metrics.hardwareInfo.osVersion) • Çalışma Süresi: \(metrics.hardwareInfo.uptimeString)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private var modelTitle: some View {
        Text(metrics.hardwareInfo.modelName)
            .font(.system(size: 20, weight: .bold))
            .lineLimit(1)
    }
    
    private var thermalBadge: some View {
        MetricBadge(text: metrics.cpuStats.thermalState.rawValue, colorName: metrics.cpuStats.thermalState.colorName)
    }
}

/// RAM, CPU, disk and battery gauges (adaptive 1–4 columns).
private struct DashboardGaugesGrid: View {
    @ObservedObject var metrics: LiveMetricsStore
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
            // RAM Gauge
            GlassCard(cornerRadius: 16, padding: 14) {
                CircularGaugeView(
                    percentage: metrics.memoryStats.usedPercentage,
                    title: "RAM Bellek",
                    valueText: String(format: "%.0f%%", metrics.memoryStats.usedPercentage * 100),
                    subText: metrics.memoryStats.swapUsedBytes > 0 ? "Swap: \(ByteFormatter.formatMemory(metrics.memoryStats.swapUsedBytes))" : "\(ByteFormatter.formatMemory(metrics.memoryStats.actualUsedBytes)) / \(ByteFormatter.formatMemory(metrics.memoryStats.totalBytes))",
                    gradient: SystemTheme.memoryGradient,
                    size: 115
                )
                .frame(maxWidth: .infinity)
            }
            
            // CPU Gauge
            GlassCard(cornerRadius: 16, padding: 14) {
                CircularGaugeView(
                    percentage: metrics.cpuStats.totalUsage / 100.0,
                    title: "İşlemci (CPU)",
                    valueText: String(format: "%.1f%%", metrics.cpuStats.totalUsage),
                    subText: "\(metrics.cpuStats.physicalCores) Çekirdek • \(metrics.cpuStats.thermalState.rawValue)",
                    gradient: SystemTheme.primaryGradient,
                    size: 115
                )
                .frame(maxWidth: .infinity)
            }
            
            // Disk Storage Gauge
            GlassCard(cornerRadius: 16, padding: 14) {
                CircularGaugeView(
                    percentage: metrics.diskStats.usedPercentage,
                    title: "Disk Depolama",
                    valueText: String(format: "%.0f%%", metrics.diskStats.usedPercentage * 100),
                    subText: "\(ByteFormatter.format(metrics.diskStats.freeBytes)) Boş",
                    gradient: SystemTheme.junkGradient,
                    size: 115
                )
                .frame(maxWidth: .infinity)
            }
            
            // Battery / Power Card
            if metrics.batteryStats.isPresent {
                GlassCard(cornerRadius: 16, padding: 14) {
                    CircularGaugeView(
                        percentage: Double(metrics.batteryStats.percentage) / 100.0,
                        title: "Pil Durumu",
                        valueText: "\(metrics.batteryStats.percentage)%",
                        subText: metrics.batteryStats.powerSource,
                        gradient: SystemTheme.updateGradient,
                        size: 115
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// Memory breakdown, battery analytics and network throughput cards.
private struct DashboardLiveDetailCards: View {
    @ObservedObject var metrics: LiveMetricsStore
    
    var body: some View {
        VStack(spacing: 20) {
            MemoryBreakdownCard(stats: metrics.memoryStats)
            
            if metrics.batteryStats.isPresent {
                BatteryAnalyticsCard(stats: metrics.batteryStats)
            }
            
            NetworkBandwidthCard(stats: metrics.networkStats)
        }
    }
}

/// Top processes card fed from the live store (processes refresh on their own 7.5 s tier).
private struct LiveTopProcessesCard: View {
    @ObservedObject var metrics: LiveMetricsStore
    let onKill: (Int32) -> Void
    let onNavigateToMemory: () -> Void
    
    var body: some View {
        TopProcessesCard(
            processes: Array(metrics.runningProcesses.prefix(5)),
            onKill: onKill,
            onNavigateToMemory: onNavigateToMemory
        )
    }
}
