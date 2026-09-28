import SwiftUI
import AppKit

/// Deep uninstaller detail sheet showing all associated leftovers and preferences
public struct AppUninstallerDetailView: View {
    @ObservedObject var appState: AppState
    let app: InstalledApp
    let onDismiss: () -> Void
    @State private var showConfirmAlert = false
    
    private var totalSizeBytes: Int64 {
        appState.selectedAppFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 14) {
                AppIconView(path: app.path)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("Uninstalling %@", table: .cleanup, app.name))
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("v\(app.version) • \(app.bundleIdentifier)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(L10n.string("Close", table: .cleanup)) {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            if appState.isLoadingAppFiles {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(l10n: "Searching for related files and caches...", table: .cleanup)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.string("Related Files Found (%lld items)", table: .cleanup, appState.selectedAppFiles.count))
                            .font(.system(size: 13, weight: .semibold))
                        
                        Spacer()
                        
                        Text(L10n.string("Space to Reclaim: %@", table: .cleanup, ByteFormatter.format(totalSizeBytes)))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach($appState.selectedAppFiles) { $file in
                                HStack(spacing: 10) {
                                    Button {
                                        file.isSelected.toggle()
                                    } label: {
                                        Image(systemName: file.isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(file.isSelected ? .red : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(file.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            
                                            MetricBadge(text: file.locationName, colorName: file.isMainApp ? "blue" : "purple")
                                        }
                                        
                                        Text(file.path)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(file.sizeFormatted)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    
                                    Button {
                                        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                                    } label: {
                                        Image(systemName: "magnifyingglass.circle")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(minHeight: 180, maxHeight: .infinity)
                }
            }
            
            Divider()
            
            // Actions
            HStack {
                Button(L10n.string("Cancel", table: .cleanup)) {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                
                Spacer()
                
                ActionButton(
                    title: appState.isUninstalling ? L10n.string("Uninstalling...", table: .cleanup) : L10n.string("Delete All and Uninstall (%@)", table: .cleanup, ByteFormatter.format(totalSizeBytes)),
                    iconName: "trash.fill",
                    gradient: SystemTheme.dangerGradient,
                    isLoading: appState.isUninstalling
                ) {
                    showConfirmAlert = true
                }
            }
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 580, maxWidth: 700, minHeight: 360, idealHeight: 440, maxHeight: 600)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .alert(isPresented: $showConfirmAlert) {
            Alert(
                title: Text(L10n.string("Uninstall %@", table: .cleanup, app.name)),
                message: Text(l10n: "The app bundle will be moved to the Trash. Selected leftovers will also be moved to the Trash. Continue?", table: .cleanup),
                primaryButton: .destructive(Text(l10n: "Uninstall with Leftovers", table: .cleanup)) {
                    appState.performUninstall()
                    onDismiss()
                },
                secondaryButton: .cancel(Text(l10n: "Cancel", table: .cleanup))
            )
        }
    }
}
