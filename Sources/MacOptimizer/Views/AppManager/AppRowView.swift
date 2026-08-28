import SwiftUI
import AppKit

/// Row representing a single installed macOS application
public struct AppRowView: View {
    let app: InstalledApp
    let onInspectUninstall: () -> Void
    let onUpdate: () -> Void
    
    public var body: some View {
        HStack(spacing: 12) {
            // App Icon
            appIconView
                .frame(width: 36, height: 36)
            
            // App Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    
                    MetricBadge(text: app.architecture.shortName, colorName: app.architecture.badgeColor)
                    
                    if app.isSystemApp {
                        MetricBadge(text: "Sistem", colorName: "gray")
                    }
                    
                    if app.updateInfo.hasUpdate {
                        MetricBadge(text: "Güncelleme: v\(app.updateInfo.latestVersion)", colorName: "orange")
                    }
                }
                
                HStack(spacing: 6) {
                    Text("v\(app.version)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(app.bundleIdentifier)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Size
            Text(app.sizeFormatted)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 70, alignment: .trailing)
            
            // Action Buttons
            HStack(spacing: 6) {
                if app.updateInfo.hasUpdate {
                    Button(action: onUpdate) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Güncelle")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Finder'da Göster")
                
                if !app.isSystemApp {
                    Button(action: onInspectUninstall) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Kaldır")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Kalıntılarıyla Birlikte Kaldır")
                }
            }
            .frame(minWidth: 90, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.04))
        )
    }
    
    @ViewBuilder
    private var appIconView: some View {
        let appWorkspaceIcon = NSWorkspace.shared.icon(forFile: app.path)
        Image(nsImage: appWorkspaceIcon)
            .resizable()
            .scaledToFit()
    }
}
