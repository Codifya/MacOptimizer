import Foundation

/// 100% Offline, zero-network rule-based diagnostic and intelligence provider.
public struct LocalHeuristicProvider: AIProvider {
    public let providerId: String = "local_heuristics"
    public let displayName: String = "Yerel Kural Motoru (Çevrimdışı & Güvenli)"
    public let requiresNetwork: Bool = false
    
    public init() {}
    
    public func diagnose(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        hardware: HardwareInfo,
        topProcesses: [ProcessInfoModel],
        junkGroups: [JunkCategoryGroup],
        outdatedAppsCount: Int
    ) async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // 1. Memory Pressure Evaluation
        if memory.pressureLevel == .critical || memory.usedPercentage > 0.88 {
            insights.append(AIInsight(
                title: "Kritik Bellek Baskısı Tespit Edildi",
                summary: "RAM kullanımınız %\(Int(memory.usedPercentage * 100)) seviyesinde ve sistem bellek sayfalarını diske sıkıştırmaya başladı. Aktif olmayan önbellekleri boşaltmak yanıt süresini iyileştirir.",
                severity: .critical,
                category: "RAM",
                actions: [
                    AIAction(title: "RAM'i Boşalt", type: .purgeRAM)
                ]
            ))
        } else if memory.pressureLevel == .warning || memory.usedPercentage > 0.75 {
            insights.append(AIInsight(
                title: "Orta Düzey Bellek Yoğunluğu",
                summary: "Bellek doluluğu %\(Int(memory.usedPercentage * 100)). Bazı pasif uygulamalar RAM önbelleğinde tutuluyor.",
                severity: .warning,
                category: "RAM",
                actions: [
                    AIAction(title: "RAM'i Optimize Et", type: .purgeRAM)
                ]
            ))
        }
        
        // 2. High CPU / Runaway Process Evaluation
        let heavyProcs = topProcesses.filter { $0.cpuPercentage > 75.0 && !$0.isProtected }
        if let runaway = heavyProcs.first {
            insights.append(AIInsight(
                title: "Yüksek CPU Tüketen Süreç: \(runaway.name)",
                summary: "\(runaway.name) (PID: \(runaway.pid)) tek başına %\(String(format: "%.1f", runaway.cpuPercentage)) CPU tüketiyor. Bu durum fan gürültüsüne ve pilin hızlı tükenmesine yol açabilir.",
                severity: .warning,
                category: "İşlemci",
                actions: [
                    AIAction(title: "\(runaway.name) Kapat", type: .killProcess, targetPID: runaway.pid)
                ]
            ))
        }
        
        // 3. Disk Storage & Junk Evaluation
        let totalJunk = junkGroups.reduce(0) { $0 + $1.totalSizeBytes }
        if totalJunk > 3 * 1024 * 1024 * 1024 {
            insights.append(AIInsight(
                title: "\(ByteFormatter.format(totalJunk)) Gereksiz Önbellek Birikimi",
                summary: "Xcode DerivedData, sistem logları ve tarayıcı önbelleklerinde önemli miktarda yer kazanılabilir alan tespit edildi.",
                severity: .recommendation,
                category: "Disk",
                actions: [
                    AIAction(title: "Gereksiz Dosyaları Temizle", type: .cleanJunk)
                ]
            ))
        }
        
        // 4. Software Updates
        if outdatedAppsCount > 0 {
            insights.append(AIInsight(
                title: "\(outdatedAppsCount) Uygulama Güncellemesi Mevcut",
                summary: "Yüklü uygulamalarınızın yeni sürümleri yayınlandı. En son güvenlik yamaları ve performans iyileştirmeleri için güncellemeniz önerilir.",
                severity: .info,
                category: "Yazılım",
                actions: [
                    AIAction(title: "Güncellemeleri İncele", type: .checkUpdates)
                ]
            ))
        }
        
        // 5. Default Healthy State
        if insights.isEmpty {
            insights.append(AIInsight(
                title: "Mac'iniz Harika Durumda",
                summary: "Bellek baskısı normal seviyede, olağandışı kaçak CPU süreci bulunmuyor ve disk alanınız dengeli.",
                severity: .info,
                category: "Genel"
            ))
        }
        
        return insights
    }
    
    public func queryCopilot(
        messages: [AIChatMessage],
        snapshotContext: String
    ) async throws -> String {
        guard let lastUserMsg = messages.last(where: { $0.role == .user })?.content.lowercased() else {
            return "Size nasıl yardımcı olabilirim?"
        }
        
        if lastUserMsg.contains("ram") || lastUserMsg.contains("bellek") {
            return "Mac'inizin bellek durumunu inceledim. Gereksiz önbellek sayfalarını boşaltarak RAM'i rahatlatmak için 'RAM'i Boşalt' komutunu kullanabilirsiniz.\n\nSistem Bilgisi:\n\(snapshotContext)"
        } else if lastUserMsg.contains("ısın") || lastUserMsg.contains("cpu") || lastUserMsg.contains("fan") {
            return "İşlemci ve donanım telemetrisine göre en çok kaynak tüketen süreçleri Görev Yöneticisi'nden kontrol edebilir, askıda kalan kullanıcı uygulamalarını güvenle sonlandırabilirsiniz."
        } else if lastUserMsg.contains("temiz") || lastUserMsg.contains("disk") || lastUserMsg.contains("yer") {
            return "Disk Temizleyici modülü ile sistem önbelleklerini, derleme kalıntılarını (Xcode DerivedData) ve tarayıcı verilerini güvenle temizleyebilirsiniz."
        } else {
            return "MacOptimizer Pro yerel yapay zeka motoru devrede. Mac'inizin performansı, bellek yönetimi ve sistem sağlığı hakkında dilediğiniz soruyu sorabilirsiniz."
        }
    }
}
