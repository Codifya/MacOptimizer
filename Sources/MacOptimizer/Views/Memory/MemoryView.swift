import SwiftUI

/// Dedicated RAM & Memory Management view with purge engine and active process task manager.
/// Fully responsive across all macOS window sizes.
public struct MemoryView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var metrics: LiveMetricsStore
    @State private var searchText = ""
    @State private var filterUserAppsOnly = false
    @State private var selectedProcessPID: Int32?
    @State private var showKillConfirmation = false
    @State private var processToKill: ProcessInfoModel?
    
    public init(appState: AppState) {
        self.appState = appState
        self.metrics = appState.metrics
    }
    
    private var filteredProcesses: [ProcessInfoModel] {
        metrics.runningProcesses.filter { proc in
            let matchesSearch = searchText.isEmpty ||
                proc.name.localizedCaseInsensitiveContains(searchText) ||
                "\(proc.pid)".contains(searchText)
            let matchesFilter = !filterUserAppsOnly || proc.isUserApp
            return matchesSearch && matchesFilter
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Memory pressure and process guidance
                ramHeaderHero
                
                // Memory Breakdown Bar
                MemoryBreakdownCard(stats: metrics.memoryStats)
                
                // Process Task Manager Table
                processTableSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .alert(isPresented: $showKillConfirmation) {
            Alert(
                title: Text(l10n: "Terminate Process", table: .dashboard),
                message: Text(L10n.string("Quit %@ (PID: %lld)? Unsaved data may be lost.", table: .dashboard, processToKill?.name ?? L10n.string("Selected process", table: .dashboard), Int64(processToKill?.pid ?? 0))),
                primaryButton: .destructive(Text(l10n: "Force Quit", table: .dashboard)) {
                    if let pid = processToKill?.pid {
                        appState.killProcess(pid: pid, force: true)
                    }
                },
                secondaryButton: .cancel(Text(l10n: "Cancel", table: .dashboard))
            )
        }
    }
    
    // MARK: - RAM Status
    private var ramHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 20) {
                // Circular Gauge
                CircularGaugeView(
                    percentage: metrics.memoryStats.usedPercentage,
                    title: L10n.string("Memory Usage", table: .dashboard),
                    valueText: String(format: "%.0f%%", metrics.memoryStats.usedPercentage * 100),
                    subText: "\(ByteFormatter.formatMemory(metrics.memoryStats.actualUsedBytes)) / \(ByteFormatter.formatMemory(metrics.memoryStats.totalBytes))",
                    gradient: SystemTheme.memoryGradient,
                    lineWidth: 10,
                    size: 105
                )
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(l10n: "RAM Memory Management", table: .dashboard)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        MetricBadge(
                            text: L10n.string("Pressure: %@", table: .dashboard, metrics.memoryStats.pressureLevel.localizedTitle),
                            colorName: metrics.memoryStats.pressureLevel.colorName
                        )
                    }
                    
                    Text(l10n: "If memory pressure is high, you can quit memory-heavy apps from the list below.", table: .dashboard)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                }
                
                Spacer(minLength: 12)
                
            }
        }
    }
    
    // MARK: - Process Table Section
    private var processTableSection: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Responsive Table Toolbar
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Label(L10n.string("Running Processes & Task Manager", table: .dashboard), systemImage: "cpu")
                            .font(.system(size: 14, weight: .bold))
                        
                        Spacer()
                        
                        Toggle(L10n.string("Apps Only", table: .dashboard), isOn: $filterUserAppsOnly)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))
                        
                        searchField
                            .frame(width: 180)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.string("Running Processes & Task Manager", table: .dashboard), systemImage: "cpu")
                            .font(.system(size: 14, weight: .bold))
                        
                        HStack(spacing: 12) {
                            Toggle(L10n.string("Apps Only", table: .dashboard), isOn: $filterUserAppsOnly)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                            
                            Spacer()
                            
                            searchField
                                .frame(maxWidth: 220)
                        }
                    }
                }
                
                // Table Header
                HStack {
                    Text(l10n: "App / Process", table: .dashboard)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("PID")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 55, alignment: .trailing)
                    
                    Text("CPU %")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 65, alignment: .trailing)
                    
                    Text(l10n: "Memory (RAM)", table: .dashboard)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 95, alignment: .trailing)
                    
                    Text(l10n: "Action", table: .dashboard)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Scrollable Process Rows
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredProcesses) { proc in
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: proc.isUserApp ? "app.badge.fill" : "gearshape.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(proc.isUserApp ? .blue : .secondary)
                                        .frame(width: 18, height: 18)
                                    
                                    Text(proc.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("\(proc.pid)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 55, alignment: .trailing)
                                
                                Text(proc.cpuFormatted)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(proc.cpuPercentage > 10.0 ? .orange : .secondary)
                                    .frame(width: 65, alignment: .trailing)
                                
                                Text(proc.memoryFormatted)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(width: 95, alignment: .trailing)
                                
                                HStack(spacing: 4) {
                                    if proc.isProtected {
                                        Text(l10n: "System", table: .dashboard)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .help(L10n.string("Protected macOS system process", table: .dashboard))
                                    } else {
                                        Button(L10n.string("Quit", table: .dashboard)) {
                                            processToKill = proc
                                            showKillConfirmation = true
                                        }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .frame(width: 80, alignment: .trailing)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.04))
                            )
                        }
                    }
                }
                .frame(minHeight: 260, maxHeight: .infinity)
            }
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            TextField(L10n.string("Process name or PID...", table: .dashboard), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
