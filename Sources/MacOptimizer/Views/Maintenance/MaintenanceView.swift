import SwiftUI

/// View with specialized macOS maintenance scripts, cache flushes, and repair actions.
/// Fully responsive across compact, standard, and large screens.
public struct MaintenanceView: View {
    @ObservedObject var appState: AppState
    @State private var runningTaskName: String?
    @State private var trashConfirmation = false
    @State private var pendingTrash: [URL] = []
    @State private var pendingTrashBytes: Int64 = 0
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                maintenanceHeaderHero
                
                // Utilities Grid (Responsive Adaptive Columns)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    // 1. DNS & Network Resolver
                    MaintenanceToolCard(
                        title: L10n.string("Reset DNS & Network Resolver", table: .cleanup),
                        description: L10n.string("Fixes network and DNS resolution delays so websites load with their most up-to-date IP addresses.", table: .cleanup),
                        icon: "network",
                        color: .blue,
                        isLoading: runningTaskName == "dns"
                    ) {
                        runTask(id: "dns") {
                            let res = await MaintenanceService.shared.flushDNSCache()
                            appState.showNotification(message: res.message)
                        }
                    }
                    
                    // 2. LaunchServices Rebuild
                    MaintenanceToolCard(
                        title: L10n.string("Repair LaunchServices Database", table: .cleanup),
                        description: L10n.string("Repairs duplicated or broken app icons and file associations in the Open With menu.", table: .cleanup),
                        icon: "app.badge.checkmark",
                        color: .indigo,
                        isLoading: runningTaskName == "launchservices"
                    ) {
                        runTask(id: "launchservices") {
                            let res = await MaintenanceService.shared.rebuildLaunchServices()
                            appState.showNotification(message: res.message)
                        }
                    }
                    
                    // 3. QuickLook Cache Reset
                    MaintenanceToolCard(
                        title: L10n.string("Reset QuickLook Cache", table: .cleanup),
                        description: L10n.string("Repairs the frozen or incorrect thumbnail caches created in Finder file previews (Space bar).", table: .cleanup),
                        icon: "eye.fill",
                        color: .purple,
                        isLoading: runningTaskName == "quicklook"
                    ) {
                        runTask(id: "quicklook") {
                            let res = await MaintenanceService.shared.resetQuickLookCache()
                            appState.showNotification(message: res.message)
                        }
                    }
                    
                    // 4. CoreAudio Restart
                    MaintenanceToolCard(
                        title: L10n.string("Refresh CoreAudio System", table: .cleanup),
                        description: L10n.string("Resets stuck microphone and headphone connections, audio crackling, and unresponsive audio devices.", table: .cleanup),
                        icon: "speaker.wave.2.fill",
                        color: .orange,
                        isLoading: runningTaskName == "audio"
                    ) {
                        runTask(id: "audio") {
                            let res = await MaintenanceService.shared.restartAudioDaemon()
                            appState.showNotification(message: res.message)
                        }
                    }
                    
                    // 5. Spotlight Rebuild
                    MaintenanceToolCard(
                        title: L10n.string("Refresh Spotlight Index", table: .cleanup),
                        description: L10n.string("Resets the file search system to optimize the Spotlight index from scratch.", table: .cleanup),
                        icon: "magnifyingglass",
                        color: .yellow,
                        isLoading: runningTaskName == "spotlight"
                    ) {
                        runTask(id: "spotlight") {
                            let res = await MaintenanceService.shared.rebuildSpotlightIndex()
                            appState.showNotification(message: res.message)
                        }
                    }
                    
                    // 7. Clipboard Clear
                    MaintenanceToolCard(
                        title: L10n.string("Clear Clipboard History", table: .cleanup),
                        description: L10n.string("Permanently erases copied sensitive text, passwords, and images from the system clipboard.", table: .cleanup),
                        icon: "doc.on.clipboard.fill",
                        color: .teal,
                        isLoading: runningTaskName == "clipboard"
                    ) {
                        let res = MaintenanceService.shared.clearClipboard()
                        appState.showNotification(message: res.message)
                    }
                    
                    // 8. Empty Trash
                    MaintenanceToolCard(
                        title: L10n.string("Empty Trash", table: .cleanup),
                        description: L10n.string("Safely and permanently deletes every file accumulated in the user trash bin.", table: .cleanup),
                        icon: "trash.fill",
                        color: .red,
                        isLoading: runningTaskName == "trash"
                    ) {
                        runTask(id: "trash") {
                            let trashItems = await JunkCleanerService.shared.scanCategory(.trashBin)
                            pendingTrash = trashItems.map { URL(fileURLWithPath: $0.path) }
                            pendingTrashBytes = trashItems.reduce(0) { $0 + $1.sizeBytes }
                            trashConfirmation = !trashItems.isEmpty
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .alert(L10n.string("Empty the trash bin permanently?", table: .cleanup), isPresented: $trashConfirmation) {
            Button(L10n.string("Cancel", table: .cleanup), role: .cancel) {}
            Button(L10n.string("Delete Permanently", table: .cleanup), role: .destructive) {
                let result = SafeOperationExecutor.emptyTrash(pendingTrash, confirmation: SafeOperationExecutor.confirm(CleaningPlan()))
                appState.refreshMetrics()
                appState.showNotification(message: L10n.string("Removed: %lld, skipped: %lld, freed: %@.", table: .cleanup, Int64(result.removedCount), Int64(result.skippedCount), ByteFormatter.format(result.bytesFreed)))
            }
        } message: {
            Text(L10n.string("%lld items, %@ in total. This action cannot be undone.", table: .cleanup, Int64(pendingTrash.count), ByteFormatter.format(pendingTrashBytes)))
        }
    }
    
    private var maintenanceHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.teal)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n: "System Maintenance & Repair", table: .cleanup)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)

                    Text(l10n: "Fix common macOS performance bottlenecks, DNS delays, audio locks, and cache errors in one click.", table: .cleanup)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
    }
    
    private func runTask(id: String, block: @escaping () async -> Void) {
        runningTaskName = id
        Task {
            await block()
            await MainActor.run {
                runningTaskName = nil
            }
        }
    }
}

private struct MaintenanceToolCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(minHeight: 38, alignment: .topLeading)
                
                HStack {
                    Spacer()
                    
                    Button(action: action) {
                        HStack(spacing: 6) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                            }
                            Text(l10n: isLoading ? "Running..." : "Run", table: .cleanup)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }
        }
    }
}
