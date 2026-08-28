import SwiftUI
import AppKit

/// View for managing macOS Startup services, LaunchAgents, and LaunchDaemons.
/// Fully responsive across all macOS window dimensions.
public struct StartupManagerView: View {
    @ObservedObject var appState: AppState
    @State private var selectedFilter: LaunchFilter = .all
    @State private var itemToRemove: LaunchAgentItem?
    @State private var showConfirmRemove = false
    
    enum LaunchFilter: String, CaseIterable, Identifiable {
        case all = "Tümü"
        case user = "Kullanıcı Servisleri"
        case system = "Sistem Servisleri"
        case daemons = "Arka Plan (Daemons)"
        
        var id: String { rawValue }
    }
    
    private var filteredItems: [LaunchAgentItem] {
        appState.startupItems.filter { item in
            switch selectedFilter {
            case .all:
                return true
            case .user:
                return item.itemType == .userAgent
            case .system:
                return item.itemType == .systemAgent
            case .daemons:
                return item.itemType == .systemDaemon
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Hero
            startupHeaderHero
            
            // Filter Bar
            HStack(spacing: 10) {
                Picker("Filtrele", selection: $selectedFilter) {
                    ForEach(LaunchFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                
                Spacer(minLength: 8)
                
                Button {
                    appState.scanStartupItems()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Başlangıç Servislerini Yenile")
            }
            
            // List
            if appState.startupItems.isEmpty && !appState.isLoadingStartup {
                emptyStartupView
            } else {
                startupListView
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .alert(isPresented: $showConfirmRemove) {
            Alert(
                title: Text("Başlangıç Öğesini Sil"),
                message: Text("\(itemToRemove?.label ?? "Seçili servis") başlangıç listesinden kalıcı olarak kaldırılacaktır. Onaylıyor musunuz?"),
                primaryButton: .destructive(Text("Sil")) {
                    if let item = itemToRemove {
                        appState.removeStartupItem(item)
                    }
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }
    
    // MARK: - Header Hero
    private var startupHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Başlangıç & Arka Plan Öğeleri")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    Text("Mac'iniz açıldığında otomatik olarak çalışan servisleri devre dışı bırakarak açılış süresini hızlandırın.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 12)
                
                ActionButton(
                    title: appState.isLoadingStartup ? "Taranıyor..." : "Servisleri Tara",
                    iconName: "arrow.clockwise",
                    gradient: SystemTheme.updateGradient,
                    isLoading: appState.isLoadingStartup
                ) {
                    appState.scanStartupItems()
                }
            }
        }
    }
    
    // MARK: - List
    private var startupListView: some View {
        GlassCard(cornerRadius: 16, padding: 10) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredItems) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isEnabled ? "power.circle.fill" : "power.circle")
                                .font(.system(size: 18))
                                .foregroundColor(item.isEnabled ? .green : .secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.label)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                    
                                    MetricBadge(
                                        text: item.isEnabled ? "Etkin" : "Devre Dışı",
                                        colorName: item.isEnabled ? "green" : "gray"
                                    )
                                }
                                
                                Text(item.path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 6)
                            
                            HStack(spacing: 6) {
                                if item.isProtected {
                                    MetricBadge(text: "Sistem", colorName: "gray")
                                }
                                
                                Toggle("", isOn: Binding(
                                    get: { item.isEnabled },
                                    set: { _ in appState.toggleStartupItem(item) }
                                ))
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                                .disabled(item.isProtected && item.itemType != .userAgent)
                                
                                Button {
                                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                } label: {
                                    Image(systemName: "magnifyingglass.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                
                                if !item.isProtected && item.itemType == .userAgent {
                                    Button {
                                        itemToRemove = item
                                        showConfirmRemove = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(3)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Empty
    private var emptyStartupView: some View {
        GlassCard(cornerRadius: 16, padding: 36) {
            VStack(spacing: 14) {
                Image(systemName: "bolt.badge.clock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(SystemTheme.updateGradient)
                
                Text("Başlangıç Servisleri Taranmadı")
                    .font(.system(size: 16, weight: .bold))
                
                Text("Arka planda çalışan servisleri ve başlangıç uygulamalarını görmek için taramayı başlatın.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                ActionButton(
                    title: "Servisleri Tara",
                    iconName: "magnifyingglass",
                    gradient: SystemTheme.updateGradient
                ) {
                    appState.scanStartupItems()
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
