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
                    Text("Yazılım & Uygulama Güncellemeleri")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    if !appsWithUpdates.isEmpty {
                        Text("\(appsWithUpdates.count) uygulama için yeni sürüm mevcut!")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    } else {
                        Text("Yüklü macOS uygulamalarınızın en son sürümlerini kontrol edin.")
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
                    title: appState.isCheckingUpdates ? "Denetleniyor..." : "Güncellemeleri Denetle",
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
                        let icon = NSWorkspace.shared.icon(forFile: app.path)
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(1)
                                
                                MetricBadge(text: app.updateInfo.updateSource.rawValue, colorName: "purple")
                            }
                            
                            HStack(spacing: 6) {
                                Text("Mevcut: v\(app.version)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                
                                Text("Yeni: v\(app.updateInfo.latestVersion)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer(minLength: 8)
                        
                        HStack(spacing: 8) {
                            if !app.updateInfo.releaseNotesURL.isEmpty, let url = URL(string: app.updateInfo.releaseNotesURL) {
                                Button("Sürüm Notları") {
                                    NSWorkspace.shared.open(url)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                            }
                            
                            if !app.updateInfo.downloadURL.isEmpty {
                                Button {
                                    if app.updateInfo.downloadURL.hasPrefix("brew ") {
                                        Task {
                                            _ = await SystemCommandRunner.runShell(app.updateInfo.downloadURL)
                                            appState.showNotification(message: "\(app.name) Homebrew üzerinden güncelleniyor.")
                                        }
                                    } else if let url = URL(string: app.updateInfo.downloadURL) {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("Güncellemeyi Al")
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
                
                Text("Tüm Uygulamalarınız Güncel")
                    .font(.system(size: 16, weight: .bold))
                
                Text("Herhangi bir bekleyen yazılım güncellemesi bulunamadı. Yeni sürümleri denetlemek için yukarıdaki butonu kullanabilirsiniz.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
