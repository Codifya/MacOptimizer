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
        case all = "All"
        case user = "User Services"
        case system = "System Services"
        case daemons = "Background (Daemons)"

        var id: String { rawValue }

        var label: String { L10n.string(rawValue, table: .cleanup) }
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
                Picker(L10n.string("Filter", table: .cleanup), selection: $selectedFilter) {
                    ForEach(LaunchFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
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
                .help(L10n.string("Refresh Startup Services", table: .cleanup))
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
                title: Text(l10n: "Delete Startup Item", table: .cleanup),
                message: Text(L10n.string("%@ will be permanently removed from the startup list. Do you confirm?", table: .cleanup, itemToRemove?.label ?? L10n.string("Selected service", table: .cleanup))),
                primaryButton: .destructive(Text(L10n.string("Delete", table: .cleanup))) {
                    if let item = itemToRemove {
                        appState.removeStartupItem(item)
                    }
                },
                secondaryButton: .cancel(Text(L10n.string("Cancel", table: .cleanup)))
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
                    Text(l10n: "Startup & Background Items", table: .cleanup)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)

                    Text(l10n: "Speed up boot time by disabling services that run automatically when your Mac starts.", table: .cleanup)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                ActionButton(
                    title: L10n.string(appState.isLoadingStartup ? "Scanning..." : "Scan Services", table: .cleanup),
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
                                        text: L10n.string(item.isEnabled ? "Enabled" : "Disabled", table: .cleanup),
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
                                    MetricBadge(text: L10n.string("System", table: .cleanup), colorName: "gray")
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
                
                Text(l10n: "Startup Services Not Scanned", table: .cleanup)
                    .font(.system(size: 16, weight: .bold))

                Text(l10n: "Start a scan to see the services and startup apps running in the background.", table: .cleanup)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)

                ActionButton(
                    title: L10n.string("Scan Services", table: .cleanup),
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
