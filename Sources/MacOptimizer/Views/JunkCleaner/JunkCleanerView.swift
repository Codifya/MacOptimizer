import SwiftUI

/// Main Junk Cleaner view for scanning and removing system caches, logs, trash, developer leftovers.
/// Fully responsive across all macOS window sizes.
public struct JunkCleanerView: View {
    @ObservedObject var appState: AppState
    @State private var showConfirmClean = false
    
    private var totalJunkBytes: Int64 {
        appState.junkGroups.reduce(0) { $0 + $1.totalSizeBytes }
    }
    
    private var selectedJunkBytes: Int64 {
        appState.junkGroups.reduce(0) { $0 + $1.selectedSizeBytes }
    }
    
    private var selectedItemCount: Int {
        appState.junkGroups.reduce(0) { $0 + $1.selectedCount }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header & Action Card
                cleanerHeaderHero
                
                // Content: Empty State, Loading, or Category List
                if appState.junkGroups.isEmpty && !appState.isScanningJunk {
                    emptyStateView
                } else {
                    categoryListView
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .sheet(isPresented: Binding(
            get: { appState.activeCleaningPlan != nil },
            set: { if !$0 { appState.activeCleaningPlan = nil } }
        )) {
            if let plan = appState.activeCleaningPlan {
                CleaningPlanPreviewModalView(
                    appState: appState,
                    plan: plan,
                    onDismiss: { appState.activeCleaningPlan = nil }
                )
            }
        }
    }
    
    // MARK: - Header Hero
    private var cleanerHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(SystemTheme.junkGradient.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "sparkles.square.filled.on.square")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(SystemTheme.junkGradient)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n: "Junk File & Disk Cleaner", table: .cleanup)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    if totalJunkBytes > 0 {
                        Text(L10n.string("Total Found: %@ • Selected: %@", table: .cleanup, ByteFormatter.format(totalJunkBytes), ByteFormatter.format(selectedJunkBytes)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.purple)
                            .lineLimit(1)
                    } else {
                        Text(l10n: "Scan system caches, Xcode leftovers, logs, and browser data.", table: .cleanup)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if appState.isScanningJunk || appState.isCleaningJunk {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(appState.junkStatusMessage)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.purple)
                                .lineLimit(1)
                            
                            AnimatedProgressBar(progress: appState.junkScanProgress, gradient: SystemTheme.junkGradient, height: 5)
                            
                            if appState.isScanningJunk {
                                Button(L10n.string("Cancel Scan", table: .cleanup)) {
                                    appState.cancelJunkScan()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 12)
                
                HStack(spacing: 10) {
                    Button {
                        appState.scanJunk()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text(l10n: "Scan", table: .cleanup)
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isScanningJunk || appState.isCleaningJunk)
                    
                    if selectedJunkBytes > 0 {
                        ActionButton(
                            title: appState.isCleaningJunk ? L10n.string("Cleaning...", table: .cleanup) : L10n.string("Clean (%@)", table: .cleanup, ByteFormatter.format(selectedJunkBytes)),
                            iconName: "trash.fill",
                            gradient: SystemTheme.junkGradient,
                            isLoading: appState.isCleaningJunk
                        ) {
                            appState.prepareCleaningPlan()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Category List
    private var categoryListView: some View {
        VStack(spacing: 10) {
            ForEach(appState.junkGroups) { group in
                JunkCategoryCard(
                    group: group,
                    onToggleSelectAll: {
                        appState.toggleJunkGroupSelection(type: group.type)
                    },
                    onToggleItem: { itemId in
                        appState.toggleJunkItemSelection(itemId: itemId)
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        GlassCard(cornerRadius: 16, padding: 36) {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(SystemTheme.junkGradient)
                
                Text(l10n: "Junk Files Not Scanned Yet", table: .cleanup)
                    .font(.system(size: 16, weight: .bold))
                
                Text(l10n: "Scan system caches, build leftovers, and logs to reclaim disk space.", table: .cleanup)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                ActionButton(
                    title: L10n.string("Start Scan", table: .cleanup),
                    iconName: "magnifyingglass",
                    gradient: SystemTheme.junkGradient
                ) {
                    appState.scanJunk()
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
