import SwiftUI
import AppKit

/// Dedicated view displaying applications with available updates.
/// Fully responsive across all macOS window dimensions.
public struct AppUpdatesView: View {
    @ObservedObject var appState: AppState
    
    private var appsWithUpdates: [InstalledApp] {
        appState.installedApps.filter { $0.updateInfo.hasUpdate }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header Hero
                updatesHeaderHero
                
                if appsWithUpdates.isEmpty && !appState.isCheckingUpdates {
                    allUpToDateView
                } else {
                    updatesListView
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Header Hero
    private var updatesHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(SystemTheme.updateGradient.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(SystemTheme.updateGradient)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n: "Software & App Updates", table: .cleanup)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    if !appsWithUpdates.isEmpty {
                        Text(L10n.string("New versions available for %lld apps!", table: .cleanup, appsWithUpdates.count))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    } else {
                        Text(l10n: "Check for the latest versions of your installed macOS apps.", table: .cleanup)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if appState.isCheckingUpdates {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(appState.appStatusMessage)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                                .lineLimit(1)
                            
                            AnimatedProgressBar(progress: appState.appScanProgress, gradient: SystemTheme.updateGradient, height: 5)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 12)
                
                ActionButton(
                    title: appState.isCheckingUpdates ? L10n.string("Checking...", table: .cleanup) : L10n.string("Check for Updates", table: .cleanup),
                    iconName: "arrow.triangle.2.circlepath",
                    gradient: SystemTheme.updateGradient,
                    isLoading: appState.isCheckingUpdates
                ) {
                    if appState.installedApps.isEmpty {
                        appState.scanApps()
                    }
                    appState.checkAllAppUpdates()
                }
            }
        }
    }
    
    // MARK: - Updates List
    private var updatesListView: some View {
        VStack(spacing: 10) {
            ForEach(appsWithUpdates) { app in
                GlassCard(cornerRadius: 14, padding: 12) {
                    HStack(spacing: 12) {
                        AppIconView(path: app.path)
                            .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)
                                
                                MetricBadge(text: app.updateInfo.updateSource.localizedTitle, colorName: "purple")
                            }
                            
                            HStack(spacing: 6) {
                                Text(L10n.string("Current: v%@", table: .cleanup, app.version))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                
                                Text(L10n.string("New: v%@", table: .cleanup, app.updateInfo.latestVersion))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer(minLength: 8)
                        
                        HStack(spacing: 8) {
                            if !app.updateInfo.releaseNotesURL.isEmpty, let url = URL(string: app.updateInfo.releaseNotesURL) {
                                Button(L10n.string("Release Notes", table: .cleanup)) {
                                    NSWorkspace.shared.open(url)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                            }
                            
                            if !app.updateInfo.downloadURL.isEmpty {
                                Button {
                                    if app.updateInfo.updateSource == .homebrew {
                                        // Only Homebrew-sourced entries may run brew, and only with a validated token.
                                        if let token = AppUpdateCheckerService.caskToken(fromUpgradeCommand: app.updateInfo.downloadURL) {
                                            appState.showNotification(message: L10n.string("Updating %@ via Homebrew.", table: .cleanup, app.name))
                                            Task {
                                                let result = await AppUpdateCheckerService.shared.upgradeHomebrewCask(token: token)
                                                appState.showNotification(message: result.message)
                                            }
                                        }
                                    } else if let url = URL(string: app.updateInfo.downloadURL),
                                              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text(l10n: "Get Update", table: .cleanup)
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(SystemTheme.updateGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Up to Date View
    private var allUpToDateView: some View {
        GlassCard(cornerRadius: 16, padding: 36) {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(SystemTheme.memoryGradient)
                
                Text(l10n: "All Your Apps Are Up to Date", table: .cleanup)
                    .font(.system(size: 16, weight: .bold))
                
                Text(l10n: "No pending software updates were found. Use the button above to check for new versions.", table: .cleanup)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
