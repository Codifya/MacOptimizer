import SwiftUI

/// Dedicated RAM & Memory Management view with purge engine and active process task manager.
/// Fully responsive across all macOS window sizes.
public struct MemoryView: View {
    @ObservedObject var appState: AppState
    @State private var searchText = ""
    @State private var filterUserAppsOnly = false
    @State private var selectedProcessPID: Int32?
    @State private var showKillConfirmation = false
    @State private var processToKill: ProcessInfoModel?
    
    private var filteredProcesses: [ProcessInfoModel] {
        appState.runningProcesses.filter { proc in
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
                // Header & Purge RAM Hero Card
                ramHeaderHero
                
                // Memory Breakdown Bar
                MemoryBreakdownCard(stats: appState.memoryStats)
                
                // Process Task Manager Table
                processTableSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .alert(isPresented: $showKillConfirmation) {
            Alert(
                title: Text("İşlemi Sonlandır"),
                message: Text("\(processToKill?.name ?? "Seçili işlem") (PID: \(processToKill?.pid ?? 0)) kapatılsın mı? Kaydedilmemiş veriler kaybolabilir."),
                primaryButton: .destructive(Text("Zorla Kapat")) {
                    if let pid = processToKill?.pid {
                        appState.killProcess(pid: pid, force: true)
                    }
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }
    
    // MARK: - RAM Header & Purge Hero
    private var ramHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 20) {
                // Circular Gauge
                CircularGaugeView(
                    percentage: appState.memoryStats.usedPercentage,
                    title: "Bellek Kullanımı",
                    valueText: String(format: "%.0f%%", appState.memoryStats.usedPercentage * 100),
                    subText: "\(ByteFormatter.formatMemory(appState.memoryStats.actualUsedBytes)) / \(ByteFormatter.formatMemory(appState.memoryStats.totalBytes))",
                    gradient: SystemTheme.memoryGradient,
                    lineWidth: 10,
                    size: 105
                )
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text("RAM Bellek Yönetimi")
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        MetricBadge(
                            text: "Basınç: \(appState.memoryStats.pressureLevel.rawValue)",
                            colorName: appState.memoryStats.pressureLevel.colorName
                        )
                    }
                    
                    Text("Kullanılmayan önbellekleri (inactive memory) ve sistem geçici sayfalarını serbest bırakarak Mac'inizin performansını anında hızlandırın.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    if let result = appState.memoryPurgeResult, !appState.isPurgingMemory {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(result.message)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 12)
                
                ActionButton(
                    title: appState.isPurgingMemory ? "RAM Boşaltılıyor..." : "RAM'i Boşalt",
                    iconName: "memorychip.fill",
                    gradient: SystemTheme.memoryGradient,
                    isLoading: appState.isPurgingMemory
                ) {
                    appState.purgeRAM()
                }
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
                        Label("Çalışan Süreçler & Görev Yöneticisi", systemImage: "cpu")
                            .font(.system(size: 14, weight: .bold))
                        
                        Spacer()
                        
                        Toggle("Yalnızca Uygulamalar", isOn: $filterUserAppsOnly)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))
                        
                        searchField
                            .frame(width: 180)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Çalışan Süreçler & Görev Yöneticisi", systemImage: "cpu")
                            .font(.system(size: 14, weight: .bold))
                        
                        HStack(spacing: 12) {
                            Toggle("Yalnızca Uygulamalar", isOn: $filterUserAppsOnly)
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
                    Text("Uygulama / İşlem")
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
                    
                    Text("Bellek (RAM)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 95, alignment: .trailing)
                    
                    Text("Eylem")
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
                                        Text("Sistem")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .help("macOS Korunan Sistem Süreci")
                                    } else {
                                        Button("Kapat") {
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
            TextField("Süreç adı veya PID...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
