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
                let icon = NSWorkspace.shared.icon(forFile: app.path)
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(app.name) Kaldırılıyor")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("v\(app.version) • \(app.bundleIdentifier)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Kapat") {
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
                    Text("İlişkili dosyalar ve önbellekler aranıyor...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Bulunan İlişkili Dosyalar (\(appState.selectedAppFiles.count) öğe)")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Spacer()
                        
                        Text("Kazanılacak Alan: \(ByteFormatter.format(totalSizeBytes))")
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
                Button("Vazgeç") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                
                Spacer()
                
                ActionButton(
                    title: appState.isUninstalling ? "Kaldırılıyor..." : "Tümünü Sil ve Kaldır (\(ByteFormatter.format(totalSizeBytes)))",
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
                title: Text("\(app.name) Uygulamasını Kaldır"),
                message: Text("Seçili tüm dosyalar ve uygulama kalıntıları kalıcı olarak silinecektir. Devam edilsin mi?"),
                primaryButton: .destructive(Text("Kalıntılarıyla Kaldır")) {
                    appState.performUninstall()
                    onDismiss()
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }
}
