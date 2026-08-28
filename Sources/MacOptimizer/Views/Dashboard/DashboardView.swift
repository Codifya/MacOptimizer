import SwiftUI

/// Dashboard overview displaying real-time metrics, AI health status, hardware info, quick optimizer, and process list.
/// Fully responsive across compact, standard, and ultra-wide macOS displays.
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
                gaugesRow
                
                // Live Observability Telemetry History Chart (Swift Charts)
                TelemetryHistoryCard(appState: appState)
                
                // Segmented Memory Breakdown
                MemoryBreakdownCard(stats: appState.memoryStats)
                
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(appState.hardwareInfo.modelName)
                        .font(.system(size: 20, weight: .bold))
                        .lineLimit(1)
                    
                    MetricBadge(text: appState.hardwareInfo.chipName, colorName: "blue")
                    
                    if appState.nimConfig.isEnabled {
                        MetricBadge(text: "NVIDIA NIM Aktif", colorName: "green")
                    }
                }
                
                Text("\(appState.hardwareInfo.osVersion) • Çalışma Süresi: \(appState.hardwareInfo.uptimeString)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
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
    
    // MARK: - Gauges Row (Adaptive Grid)
    private var gaugesRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
            // RAM Gauge
            GlassCard(cornerRadius: 16, padding: 14) {
                CircularGaugeView(
                    percentage: appState.memoryStats.usedPercentage,
                    title: "RAM Bellek",
                    valueText: String(format: "%.0f%%", appState.memoryStats.usedPercentage * 100),
                    subText: "\(ByteFormatter.formatMemory(appState.memoryStats.actualUsedBytes)) / \(ByteFormatter.formatMemory(appState.memoryStats.totalBytes))",
                    gradient: SystemTheme.memoryGradient,
                    size: 115
                )
                .frame(maxWidth: .infinity)
            }
            
            // CPU Gauge
            GlassCard(cornerRadius: 16, padding: 14) {
                CircularGaugeView(
                    percentage: appState.cpuStats.totalUsage / 100.0,
                    title: "İşlemci (CPU)",
                    valueText: String(format: "%.1f%%", appState.cpuStats.totalUsage),
                    subText: "\(appState.cpuStats.physicalCores) Çekirdek Aktif",
                    gradient: SystemTheme.primaryGradient,
                    size: 115
                )
                .frame(maxWidth: .infinity)
            }
            
            // Disk Storage Gauge
            GlassCard(cornerRadius: 16, padding: 14) {
                CircularGaugeView(
                    percentage: appState.diskStats.usedPercentage,
                    title: "Disk Depolama",
                    valueText: String(format: "%.0f%%", appState.diskStats.usedPercentage * 100),
                    subText: "\(ByteFormatter.format(appState.diskStats.freeBytes)) Boş",
                    gradient: SystemTheme.junkGradient,
                    size: 115
                )
                .frame(maxWidth: .infinity)
            }
            
            // Battery / Power Card
            if appState.batteryStats.isPresent {
                GlassCard(cornerRadius: 16, padding: 14) {
                    CircularGaugeView(
                        percentage: Double(appState.batteryStats.percentage) / 100.0,
                        title: "Pil Durumu",
                        valueText: "\(appState.batteryStats.percentage)%",
                        subText: appState.batteryStats.powerSource,
                        gradient: SystemTheme.updateGradient,
                        size: 115
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Bottom Section (Responsive Grid)
    private var bottomProcessesAndUtilitiesSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
            TopProcessesCard(
                processes: appState.runningProcesses,
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
