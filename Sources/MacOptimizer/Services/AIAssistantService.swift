import Foundation

/// Service for generating AI-powered Mac diagnostics, chat responses, and changelog summaries
public actor AIAssistantService {
    public static let shared = AIAssistantService()
    
    public init() {}
    
    // MARK: - Generate Comprehensive System Diagnostic Insights
    public func analyzeSystemHealth(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        hardware: HardwareInfo,
        topProcesses: [ProcessInfoModel],
        junkGroups: [JunkCategoryGroup],
        outdatedAppsCount: Int,
        nimConfig: NIMConfig
    ) async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // 1. If NVIDIA NIM is enabled and has an API Key, ask the LLM for deep reasoning
        if nimConfig.isEnabled && !nimConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let aiGenerated = await queryNIMForInsights(
                memory: memory,
                cpu: cpu,
                disk: disk,
                hardware: hardware,
                topProcesses: topProcesses,
                junkGroups: junkGroups,
                outdatedAppsCount: outdatedAppsCount,
                config: nimConfig
            ) {
                return aiGenerated
            }
        }
        
        // 2. Fallback: High-Precision Local Heuristic Engine
        // Memory Analysis
        if memory.pressureLevel == .critical || memory.usedPercentage > 0.85 {
            insights.append(AIInsight(
                title: "Kritik Bellek Baskısı Tespit Edildi",
                summary: "RAM kullanımınız %\(Int(memory.usedPercentage * 100)) seviyesinde ve bellek baskısı yüksek. Uygulama geçişlerinde takılmaları önlemek için pasif önbelleklerin boşaltılması önerilir.",
                severity: .critical,
                category: "RAM",
                actions: [
                    AIAction(title: "RAM'i Boşalt", type: .purgeRAM)
                ]
            ))
        } else if memory.inactiveBytes > 2 * 1024 * 1024 * 1024 {
            insights.append(AIInsight(
                title: "Büyük Pasif RAM Önbelleği Mevcut",
                summary: "\(ByteFormatter.formatMemory(memory.inactiveBytes)) boyutunda pasif uygulama önbelleği bellekte tutuluyor. İhtiyaç halinde bu alanı geri kazanabilirsiniz.",
                severity: .recommendation,
                category: "RAM",
                actions: [
                    AIAction(title: "Önbelleği Serbest Bırak", type: .purgeRAM)
                ]
            ))
        }
        
        // CPU & Process Analysis
        if let highestCPU = topProcesses.first(where: { $0.cpuPercentage > 50.0 }) {
            var actions: [AIAction] = []
            if !highestCPU.isProtected && SafetyGuard.isProcessKillable(pid: highestCPU.pid, name: highestCPU.name, path: highestCPU.path) {
                actions.append(AIAction(title: "\(highestCPU.name) Sürecini Sonlandır", type: .killProcess, targetPID: highestCPU.pid))
            }
            
            insights.append(AIInsight(
                title: "\(highestCPU.name) Yüksek İşlemci Kullanıyor",
                summary: "Süreç PID \(highestCPU.pid) %\(highestCPU.cpuFormatted) işlemci gücü tüketiyor. \(highestCPU.isProtected ? "Bu bir macOS sistem bileşenidir ve güvenle çalışmaktadır." : "Bu durum fan gürültüsüne ve pilin hızlı tükenmesine yol açabilir.")",
                severity: highestCPU.cpuPercentage > 85.0 ? .warning : .info,
                category: "İşlemci",
                actions: actions
            ))
        }
        
        // Junk & Developer Artifacts Analysis
        let devGroup = junkGroups.first(where: { $0.type == .developerCache })
        if let dev = devGroup, dev.totalSizeBytes > 3 * 1024 * 1024 * 1024 {
            insights.append(AIInsight(
                title: "Büyük Geliştirici & Build Kalıntıları",
                summary: "Xcode DerivedData, CocoaPods veya Node önbelleklerinde \(dev.totalFormatted) boyutunda yer kaplayan eski derleme dosyaları bulundu.",
                severity: .recommendation,
                category: "Disk",
                actions: [
                    AIAction(title: "Geliştirici Önbelleğini Temizle", type: .cleanJunk)
                ]
            ))
        }
        
        // Storage Space Analysis
        if disk.freePercentage < 0.15 {
            insights.append(AIInsight(
                title: "Düşük Disk Alanı Uyarısı",
                summary: "Kullanılabilir disk alanınız %\(Int(disk.freePercentage * 100)) seviyesine düştü. macOS sanal bellek swap alanı için en az %15 boş alan önerilir.",
                severity: .warning,
                category: "Depolama",
                actions: [
                    AIAction(title: "Gereksiz Dosyaları Tara", type: .scanJunk)
                ]
            ))
        }
        
        // Outdated Apps Analysis
        if outdatedAppsCount > 0 {
            insights.append(AIInsight(
                title: "\(outdatedAppsCount) Uygulama Güncellemesi Mevcut",
                summary: "Yüklü uygulamalarınız için yeni sürümler ve güvenlik yamaları bulundu. Performans ve kararlılık için güncellemeniz önerilir.",
                severity: .info,
                category: "Yazılım",
                actions: [
                    AIAction(title: "Güncellemeleri İncele", type: .checkUpdates)
                ]
            ))
        }
        
        if insights.isEmpty {
            insights.append(AIInsight(
                title: "Sisteminiz Mükemmel Durumda",
                summary: "RAM baskısı normal, işlemci yükü dengeli ve disk alanı yeterli seviyede. Otonom izleme arka planda çalışmaya devam ediyor.",
                severity: .info,
                category: "Genel"
            ))
        }
        
        return insights
    }
    
    // MARK: - Query NVIDIA NIM for Structured Insights
    private func queryNIMForInsights(
        memory: MemoryStats,
        cpu: CPUStats,
        disk: DiskStats,
        hardware: HardwareInfo,
        topProcesses: [ProcessInfoModel],
        junkGroups: [JunkCategoryGroup],
        outdatedAppsCount: Int,
        config: NIMConfig
    ) async -> [AIInsight]? {
        let topProcSummary = topProcesses.prefix(4).map { "\($0.name) (PID: \($0.pid), RAM: \($0.memoryFormatted), CPU: \($0.cpuFormatted))" }.joined(separator: ", ")
        let totalJunk = junkGroups.reduce(0) { $0 + $1.totalSizeBytes }
        
        let systemPrompt = """
        Sen gelişmiş bir macOS Sistem Mühendisi ve Yapay Zeka Danışmanısın.
        Sana verilen macOS telemetri verilerini inceleyerek Türkçe dilinde 2-4 adet kritik tespit ve tavsiye üret.
        Her tespit için kısa başlık ve net açıklama yaz.
        """
        
        let userPrompt = """
        Mac Donanım: \(hardware.modelName) (\(hardware.chipName)), \(hardware.osVersion)
        RAM: Toplam \(ByteFormatter.formatMemory(memory.totalBytes)), Kullanılan \(ByteFormatter.formatMemory(memory.actualUsedBytes)), Pasif \(ByteFormatter.formatMemory(memory.inactiveBytes)), Basınç: \(memory.pressureLevel.rawValue) (% \(Int(memory.usedPercentage * 100)))
        CPU: Toplam Yük %\(String(format: "%.1f", cpu.totalUsage))
        Disk: Toplam \(ByteFormatter.format(disk.totalBytes)), Boş \(ByteFormatter.format(disk.freeBytes))
        Gereksiz Dosyalar: \(ByteFormatter.format(totalJunk))
        En Çok Kaynak Tüketen Süreçler: \(topProcSummary)
        Bekleyen Güncellemeler: \(outdatedAppsCount)
        
        Lütfen sistemin durumunu özetle ve optimizasyon önerilerini listele.
        """
        
        let messages = [
            ["role": "user", "content": userPrompt]
        ]
        
        do {
            let answer = try await NvidiaNIMService.shared.sendChatCompletion(
                messages: messages,
                config: config,
                systemPrompt: systemPrompt
            )
            
            var actions: [AIAction] = []
            if memory.usedPercentage > 0.70 {
                actions.append(AIAction(title: "RAM'i Boşalt", type: .purgeRAM))
            }
            if totalJunk > 1024 * 1024 * 1024 {
                actions.append(AIAction(title: "Gereksizleri Temizle", type: .cleanJunk))
            }
            if outdatedAppsCount > 0 {
                actions.append(AIAction(title: "Güncellemeleri Aç", type: .checkUpdates))
            }
            
            return [
                AIInsight(
                    title: "NVIDIA NIM (\(config.selectedModel)) Sistem Analizi",
                    summary: answer,
                    severity: memory.pressureLevel == .critical ? .critical : .recommendation,
                    category: "Yapay Zeka Raporu",
                    actions: actions
                )
            ]
        } catch {
            return nil
        }
    }
    
    // MARK: - Interactive AI Chat Copilot
    public func chatWithCopilot(
        userMessage: String,
        history: [AIChatMessage],
        systemContext: String,
        config: NIMConfig
    ) async -> (reply: String, actions: [AIAction]) {
        var actions: [AIAction] = []
        let lower = userMessage.lowercased()
        
        // Auto-detect intent for quick actions
        if lower.contains("ram") || lower.contains("bellek") || lower.contains("boşalt") {
            actions.append(AIAction(title: "RAM'i Boşalt", type: .purgeRAM))
        }
        if lower.contains("çöp") || lower.contains("önbellek") || lower.contains("gereksiz") || lower.contains("temiz") {
            actions.append(AIAction(title: "Gereksiz Dosyaları Tara", type: .scanJunk))
        }
        if lower.contains("güncelle") || lower.contains("update") || lower.contains("yeni sürüm") {
            actions.append(AIAction(title: "Güncellemeleri Denetle", type: .checkUpdates))
        }
        if lower.contains("dns") || lower.contains("ağ") || lower.contains("internet") {
            actions.append(AIAction(title: "DNS Önbelleğini Sıfırla", type: .flushDNS))
        }
        
        // 1. If NIM is available, use LLM
        if config.isEnabled && !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var messages: [[String: String]] = []
            
            for msg in history.suffix(6) {
                messages.append(["role": msg.role.rawValue, "content": msg.content])
            }
            messages.append(["role": "user", "content": userMessage])
            
            let systemPrompt = """
            Sen MacOptimizer Pro içindeki yerleşik Apple & macOS uzmanı yapay zeka asistanısın.
            Kullanıcıya Mac performansı, bellek yönetimi, arka plan servisleri, disk temizliği ve macOS optimizasyonu konularında yardımcı ol.
            Aşağıdaki anlık sistem verilerini referans al:
            \(systemContext)
            Yanıtlarını samimi, teknik olarak net, anlaşılır ve Türkçe olarak ver.
            """
            
            do {
                let answer = try await NvidiaNIMService.shared.sendChatCompletion(
                    messages: messages,
                    config: config,
                    systemPrompt: systemPrompt
                )
                return (answer, actions)
            } catch {
                // Fallback on error
                return ("NVIDIA NIM Bağlantı Hatası: \(error.localizedDescription)\n\nAncak sistem verilerinizi analiz ettim. Aşağıdaki butonlarla anında optimizasyon yapabilirsiniz.", actions)
            }
        }
        
        // 2. Intelligent Offline Heuristic Response
        var reply = "Sistem Durumu Özeti:\n"
        if lower.contains("ram") || lower.contains("bellek") {
            reply += "Mac'inizin RAM bellek durumunu analiz ettim. Aktif olmayan önbellekleri boşaltmak sistem yanıt sürelerini hızlandıracaktır. Aşağıdaki 'RAM'i Boşalt' butonu ile tek tıkla bellek temizliği yapabilirsiniz."
        } else if lower.contains("disk") || lower.contains("alan") || lower.contains("temiz") {
            reply += "Disk alanınızı geri kazanmak için sistem önbelleklerini, Xcode derleme kalıntılarını ve tarayıcı verilerini temizleyebilirsiniz. 'Gereksiz Dosyaları Tara' butonunu kullanarak tarama başlatabilirsiniz."
        } else if lower.contains("güncelle") {
            reply += "Yüklü uygulamalarınızın güncellemeleri taranabilir ve yeni sürümler güvenle indirilebilir."
        } else {
            reply += "MacOptimizer yapay zeka asistanı hizmetinizde. RAM boşaltma, gereksiz dosya temizleme, güncelleme denetimi veya süreç sonlandırma konularında bana komut verebilirsiniz. Daha derin yapay zeka analizleri için Ayarlar sayfasından NVIDIA NIM API anahtarınızı ekleyebilirsiniz."
        }
        
        return (reply, actions)
    }
}
