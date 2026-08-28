import SwiftUI

/// Root View featuring NavigationSplitView with Liquid Glass sidebar, AI Copilot, and Autonomous Guard
public struct MainView: View {
    @StateObject private var appState = AppState.shared
    
    private var updatesCount: Int {
        appState.installedApps.filter { $0.updateInfo.hasUpdate }.count
    }
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 520)
        .alert(isPresented: $appState.showAlert) {
            Alert(
                title: Text("MacOptimizer"),
                message: Text(appState.activeAlertMessage ?? ""),
                dismissButton: .default(Text("Tamam"))
            )
        }
    }
    
    // MARK: - Sidebar
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // App Brand Header
            HStack(spacing: 10) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(SystemTheme.primaryGradient)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("MacOptimizer Pro")
                        .font(.system(size: 15, weight: .bold))
                    
                    HStack(spacing: 4) {
                        Text("AI & Otonom 2.0")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 12)
                .opacity(0.5)
            
            // Navigation List
            List(selection: $appState.selectedTab) {
                Section(header: Text("YAPAY ZEKA & OTONOM").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                    NavigationLink(value: NavigationTab.dashboard) {
                        Label(NavigationTab.dashboard.title, systemImage: NavigationTab.dashboard.iconName)
                    }
                    
                    NavigationLink(value: NavigationTab.aiCopilot) {
                        HStack {
                            Label(NavigationTab.aiCopilot.title, systemImage: NavigationTab.aiCopilot.iconName)
                            Spacer()
                            if appState.nimConfig.isEnabled {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 7, height: 7)
                            }
                        }
                    }
                    
                    NavigationLink(value: NavigationTab.autonomousGuard) {
                        HStack {
                            Label(NavigationTab.autonomousGuard.title, systemImage: NavigationTab.autonomousGuard.iconName)
                            Spacer()
                            if appState.unresolvedAlertsCount > 0 {
                                Text("\(appState.unresolvedAlertsCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Section(header: Text("OPTİMİZASYON").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                    NavigationLink(value: NavigationTab.memory) {
                        HStack {
                            Label(NavigationTab.memory.title, systemImage: NavigationTab.memory.iconName)
                            Spacer()
                            Text(String(format: "%.0f%%", appState.memoryStats.usedPercentage * 100))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(appState.memoryStats.pressureLevel == .critical ? .red : .secondary)
                        }
                    }
                    
                    NavigationLink(value: NavigationTab.junkCleaner) {
                        Label(NavigationTab.junkCleaner.title, systemImage: NavigationTab.junkCleaner.iconName)
                    }
                }
                
                Section(header: Text("UYGULAMALAR").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                    NavigationLink(value: NavigationTab.appManager) {
                        Label(NavigationTab.appManager.title, systemImage: NavigationTab.appManager.iconName)
                    }
                    
                    NavigationLink(value: NavigationTab.appUpdates) {
                        HStack {
                            Label(NavigationTab.appUpdates.title, systemImage: NavigationTab.appUpdates.iconName)
                            Spacer()
                            if updatesCount > 0 {
                                Text("\(updatesCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    NavigationLink(value: NavigationTab.startupManager) {
                        Label(NavigationTab.startupManager.title, systemImage: NavigationTab.startupManager.iconName)
                    }
                }
                
                Section(header: Text("SİSTEM").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                    NavigationLink(value: NavigationTab.maintenance) {
                        Label(NavigationTab.maintenance.title, systemImage: NavigationTab.maintenance.iconName)
                    }
                    
                    NavigationLink(value: NavigationTab.history) {
                        Label(NavigationTab.history.title, systemImage: NavigationTab.history.iconName)
                    }
                    
                    NavigationLink(value: NavigationTab.settings) {
                        Label(NavigationTab.settings.title, systemImage: NavigationTab.settings.iconName)
                    }
                }
            }
            .listStyle(.sidebar)
            
            Spacer()
            
            // Bottom Sidebar Live Memory Widget
            sidebarMemoryWidget
        }
    }
    
    // MARK: - Sidebar Memory Widget
    private var sidebarMemoryWidget: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal, 12)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kullanılabilir RAM")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.formatMemory(appState.memoryStats.freeAndInactiveBytes))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                Button {
                    appState.purgeRAM()
                } label: {
                    if appState.isPurgingMemory {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                            .padding(6)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .help("Hızlı RAM Boşalt")
                .disabled(appState.isPurgingMemory)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Detail View Router
    @ViewBuilder
    private var detailContent: some View {
        switch appState.selectedTab {
        case .dashboard:
            DashboardView(appState: appState)
        case .aiCopilot:
            AICopilotView(appState: appState)
        case .autonomousGuard:
            AutonomousGuardView(appState: appState)
        case .memory:
            MemoryView(appState: appState)
        case .junkCleaner:
            JunkCleanerView(appState: appState)
        case .appManager:
            AppManagerView(appState: appState)
        case .appUpdates:
            AppUpdatesView(appState: appState)
        case .startupManager:
            StartupManagerView(appState: appState)
        case .maintenance:
            MaintenanceView(appState: appState)
        case .history:
            HistoryView(appState: appState)
        case .settings:
            SettingsView()
        }
    }
}
