import SwiftUI

/// View with specialized macOS maintenance scripts, cache flushes, and repair actions.
/// Fully responsive across compact, standard, and large screens.
public struct MaintenanceView: View {
    @ObservedObject var appState: AppState
    @State private var runningTaskName: String?
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                maintenanceHeaderHero
                
                // Utilities Grid (Responsive Adaptive Columns)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    MaintenanceToolCard(
                        title: "DNS Önbelleğini Sıfırla",
                        description: "Ağ ve DNS çözümleme gecikmelerini giderir, web sitelerinin en güncel IP adresleriyle yüklenmesini sağlar.",
                        icon: "network",
                        color: .blue,
                        isLoading: runningTaskName == "dns"
                    ) {
                        runTask(id: "dns") {
                            let res = await MaintenanceService.shared.flushDNSCache()
                            appState.showNotification(message: res.message)
                        }
                    }
                    
                    MaintenanceToolCard(
                        title: "QuickLook Önbelleğini Sıfırla",
                        description: "Finder dosya önizlemelerinde (Space tuşu) oluşan donma veya hatalı küçük resim önbelleklerini onarır.",
                        icon: "eye.fill",
                        color: .purple,
                        isLoading: runningTaskName == "quicklook"
                    ) {
                        runTask(id: "quicklook") {
                            let res = await MaintenanceService.shared.resetQuickLookCache()
                            appState.showNotification(message: res.message)
                        }
                    }
                    
                    MaintenanceToolCard(
                        title: "Pano Geçmişini Temizle",
                        description: "Kopyalanmış hassas metin, şifre ve görselleri sistem panosundan (Clipboard) kalıcı olarak siler.",
                        icon: "doc.on.clipboard.fill",
                        color: .teal,
                        isLoading: runningTaskName == "clipboard"
                    ) {
                        let res = MaintenanceService.shared.clearClipboard()
                        appState.showNotification(message: res.message)
                    }
                    
                    MaintenanceToolCard(
                        title: "RAM Önbelleğini Boşalt",
                        description: "macOS sanal bellek sayfalarını ve pasif uygulama kalıntılarını anında serbest bırakır.",
                        icon: "memorychip.fill",
                        color: .green,
                        isLoading: appState.isPurgingMemory
                    ) {
                        appState.purgeRAM()
                    }
                    
                    MaintenanceToolCard(
                        title: "Spotlight İndeksini Yenile",
                        description: "Dosya arama sistemini sıfırlayarak Spotlight indeksini baştan optimize eder.",
                        icon: "magnifyingglass",
                        color: .orange,
                        isLoading: runningTaskName == "spotlight"
                    ) {
                        runTask(id: "spotlight") {
                            _ = await SystemCommandRunner.run(executable: "/usr/bin/mdutil", arguments: ["-E", "/"])
                            appState.showNotification(message: "Spotlight arama indeksi yenilenmeye başladı.")
                        }
                    }
                    
                    MaintenanceToolCard(
                        title: "Çöp Kutusunu Boşalt",
                        description: "Kullanıcı çöp sepetinde biriken tüm dosyaları güvenli ve kalıcı şekilde siler.",
                        icon: "trash.fill",
                        color: .red,
                        isLoading: runningTaskName == "trash"
                    ) {
                        runTask(id: "trash") {
                            let trashItems = await JunkCleanerService.shared.scanCategory(.trashBin)
                            let res = await JunkCleanerService.shared.cleanItems(trashItems)
                            appState.refreshMetrics()
                            appState.showNotification(message: "Çöp kutusu boşaltıldı (\(ByteFormatter.format(res.freedBytes)) kazanıldı).")
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
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
                    Text("Sistem Bakımı & Onarım")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    Text("Sık karşılaşılan macOS performans tıkanıklıklarını, DNS gecikmelerini ve önbellek kilitlenmelerini tek tıkla çözün.")
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
                            Text(isLoading ? "Çalıştırılıyor..." : "Çalıştır")
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
