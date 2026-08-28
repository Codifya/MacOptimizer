import Foundation
import SwiftUI
import Combine

/// Navigation tabs in the sidebar
public enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case aiCopilot = "aiCopilot"
    case autonomousGuard = "autonomousGuard"
    case memory = "memory"
    case junkCleaner = "junkCleaner"
    case duplicateFinder = "duplicateFinder"
    case appManager = "appManager"
    case appUpdates = "appUpdates"
    case startupManager = "startupManager"
    case maintenance = "maintenance"
    case security = "security"
    case history = "history"
    case settings = "settings"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .dashboard: return "Genel Bakış"
        case .aiCopilot: return "AI Asistan & Danışman"
        case .autonomousGuard: return "Otonom Koruma"
        case .memory: return "RAM & Bellek"
        case .junkCleaner: return "Gereksiz Dosyalar"
        case .duplicateFinder: return "Yinelenen Dosyalar"
        case .appManager: return "Uygulama Yöneticisi"
        case .appUpdates: return "Güncellemeler"
        case .startupManager: return "Başlangıç Öğeleri"
        case .maintenance: return "Sistem Bakımı"
        case .security: return "Güvenlik & Gizlilik"
        case .history: return "Raporlar & Geçmiş"
        case .settings: return "Ayarlar & Yapay Zeka Hub'ı"
        }
    }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "gauge.with.needle.fill"
        case .aiCopilot: return "sparkles.rectangle.stack.fill"
        case .autonomousGuard: return "shield.checkered"
        case .memory: return "memorychip.fill"
        case .junkCleaner: return "sparkles.square.filled.on.square"
        case .duplicateFinder: return "doc.on.doc.fill"
        case .appManager: return "square.grid.2x2.fill"
        case .appUpdates: return "arrow.triangle.2.circlepath.circle.fill"
        case .startupManager: return "bolt.horizontal.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .security: return "lock.shield.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Global Application State for MacOptimizer
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var selectedTab: NavigationTab = .dashboard
    
    // Live Hardware & Metrics
    @Published public var memoryStats = MemoryStats()
    @Published public var cpuStats = CPUStats()
    @Published public var diskStats = DiskStats()
    @Published public var batteryStats = BatteryStats()
    @Published public var hardwareInfo = HardwareInfo()
    @Published public var runningProcesses: [ProcessInfoModel] = []
    
    // AI & NVIDIA NIM State
    @Published public var nimConfig = NIMConfig()
    @Published public var aiInsights: [AIInsight] = []
    @Published public var isAnalyzingAI = false
    @Published public var chatMessages: [AIChatMessage] = []
    @Published public var isChatThinking = false
    @Published public var nimTestResult: (success: Bool, message: String)?
    @Published public var isTestingNIM = false
    @Published public var isScanningNIMModels = false
    
    // Autonomous Guard & Watchdog State
    @Published public var autonomousConfig = AutonomousConfig()
    @Published public var autonomousAlerts: [AutonomousAlert] = []
    
    // Junk Cleaner State
    @Published public var junkGroups: [JunkCategoryGroup] = []
    @Published public var activeCleaningPlan: CleaningPlan? = nil
    @Published public var isScanningJunk = false
    @Published public var isCleaningJunk = false
    @Published public var junkScanProgress: Double = 0.0
    @Published public var junkStatusMessage: String = ""
    
    // Duplicate Finder State
    @Published public var duplicateGroups: [DuplicateFileGroup] = []
    @Published public var isScanningDuplicates = false
    @Published public var isCleaningDuplicates = false
    @Published public var duplicateScanProgress: Double = 0.0
    @Published public var duplicateStatusMessage: String = ""
    
    // App Manager & Updates State
    @Published public var installedApps: [InstalledApp] = []
    @Published public var isScanningApps = false
    @Published public var isCheckingUpdates = false
    @Published public var appScanProgress: Double = 0.0
    @Published public var appStatusMessage: String = ""
    @Published public var selectedAppForDetail: InstalledApp?
    @Published public var selectedAppFiles: [AppUninstallerService.AppFileItem] = []
    @Published public var isLoadingAppFiles = false
    @Published public var isUninstalling = false
    
    // Startup Items State
    @Published public var startupItems: [LaunchAgentItem] = []
    @Published public var isLoadingStartup = false
    
    // Smart Optimization State
    @Published public var isOptimizingSmart = false
    @Published public var smartOptProgress: Double = 0.0
    @Published public var smartOptStatus: String = ""
    @Published public var latestReport: OptimizationReport?
    @Published public var optimizationHistory: [OptimizationReport] = []
    
    // Memory Purge State
    @Published public var isPurgingMemory = false
    @Published public var memoryPurgeResult: MemoryOptimizerService.OptimizationResult?
    
    // Security & Privacy Audit State
    @Published public var securityReport: SecurityAuditReport?
    @Published public var isLoadingSecurityAudit = false
    
    // Alert / Notification State
    @Published public var activeAlertMessage: String?
    @Published public var showAlert = false
    
    public var unresolvedAlertsCount: Int {
        autonomousAlerts.filter { !$0.isResolved }.count
    }
    
    private var timer: Timer?
    
    public init() {
        loadConfigs()
        startMonitoring()
        loadHistory()
        initDefaultChat()
    }
    
    private func initDefaultChat() {
        if chatMessages.isEmpty {
            chatMessages.append(AIChatMessage(
                role: .assistant,
                content: "Merhaba! Ben MacOptimizer Yapay Zeka Asistanınız. Sisteminizin durumunu analiz edebilir, RAM boşaltabilir, gereksiz dosyaları temizleyebilir ve uygulama güncellemelerinizi denetleyebilirim. Size nasıl yardımcı olabilirim?",
                actions: [
                    AIAction(title: "Sistem Durumunu Analiz Et", type: .purgeRAM),
                    AIAction(title: "Gereksiz Dosyaları Tara", type: .scanJunk)
                ]
            ))
        }
    }
    
    private var timerCycleCount = 0
    
    // MARK: - Live System Monitoring & Autonomous Loop
    public func startMonitoring() {
        refreshMetrics(fullProcessRefresh: true)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.timerCycleCount += 1
                // Refresh processes every 3 cycles (7.5s) or if list is empty, keeping fast Mach VM calls at 2.5s
                let shouldFetchProcs = (self.timerCycleCount % 3 == 0) || self.runningProcesses.isEmpty
                self.refreshMetrics(fullProcessRefresh: shouldFetchProcs)
            }
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    public func refreshMetrics(fullProcessRefresh: Bool = false) {
        Task {
            let mem = await SystemMonitorService.shared.fetchMemoryStats()
            let cpu = await SystemMonitorService.shared.fetchCPUStats()
            let disk = await SystemMonitorService.shared.fetchDiskStats()
            let batt = await SystemMonitorService.shared.fetchBatteryStats()
            let hw = await SystemMonitorService.shared.fetchHardwareInfo()
            let procs = await SystemMonitorService.shared.fetchRunningProcesses(forceRefresh: fullProcessRefresh)
            
            // Evaluate Autonomous Watchdog Cycle
            let newAlerts = await AutonomousGuardService.shared.evaluateCycle(
                memory: mem,
                cpu: cpu,
                disk: disk,
                processes: procs,
                config: self.autonomousConfig
            )
            
            await MainActor.run {
                self.memoryStats = mem
                self.cpuStats = cpu
                self.diskStats = disk
                self.batteryStats = batt
                self.hardwareInfo = hw
                self.runningProcesses = procs
                
                if !newAlerts.isEmpty {
                    for alert in newAlerts {
                        if !self.autonomousAlerts.contains(where: { $0.title == alert.title && Date().timeIntervalSince($0.timestamp) < 30.0 }) {
                            self.autonomousAlerts.insert(alert, at: 0)
                            if self.autonomousConfig.notifyOnAnomalies && !alert.autoHealed {
                                self.showNotification(message: "\(alert.title): \(alert.message)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - AI Health Analysis & NVIDIA NIM
    public func runAIHealthAnalysis() {
        guard !isAnalyzingAI else { return }
        isAnalyzingAI = true
        
        Task {
            let insights = await AIAssistantService.shared.analyzeSystemHealth(
                memory: self.memoryStats,
                cpu: self.cpuStats,
                disk: self.diskStats,
                hardware: self.hardwareInfo,
                topProcesses: self.runningProcesses,
                junkGroups: self.junkGroups,
                outdatedAppsCount: self.installedApps.filter { $0.updateInfo.hasUpdate }.count,
                nimConfig: self.nimConfig
            )
            
            await MainActor.run {
                self.aiInsights = insights
                self.isAnalyzingAI = false
            }
        }
    }
    
    public func sendChatMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isChatThinking else { return }
        
        let userMsg = AIChatMessage(role: .user, content: trimmed)
        chatMessages.append(userMsg)
        isChatThinking = true
        
        let context = """
        Mac Modeli: \(hardwareInfo.modelName) (\(hardwareInfo.chipName)), macOS Sürümü: \(hardwareInfo.osVersion)
        RAM: Toplam \(ByteFormatter.formatMemory(memoryStats.totalBytes)), Kullanılan %\(Int(memoryStats.usedPercentage * 100)) (\(ByteFormatter.formatMemory(memoryStats.actualUsedBytes))), Pasif \(ByteFormatter.formatMemory(memoryStats.inactiveBytes))
        CPU: %\(String(format: "%.1f", cpuStats.totalUsage)), Boş Disk: \(ByteFormatter.format(diskStats.freeBytes))
        """
        
        Task {
            let result = await AIAssistantService.shared.chatWithCopilot(
                userMessage: trimmed,
                history: self.chatMessages,
                systemContext: context,
                config: self.nimConfig
            )
            
            await MainActor.run {
                self.isChatThinking = false
                let assistantMsg = AIChatMessage(
                    role: .assistant,
                    content: result.reply,
                    actions: result.actions
                )
                self.chatMessages.append(assistantMsg)
            }
        }
    }
    
    public func executeAIAction(_ action: AIAction) {
        switch action.type {
        case .purgeRAM:
            purgeRAM()
        case .scanJunk:
            selectedTab = .junkCleaner
            scanJunk()
        case .cleanJunk:
            selectedTab = .junkCleaner
            cleanSelectedJunk()
        case .checkUpdates:
            selectedTab = .appUpdates
            if installedApps.isEmpty { scanApps() }
            checkAllAppUpdates()
        case .flushDNS:
            Task {
                let res = await MaintenanceService.shared.flushDNSCache()
                self.showNotification(message: res.message)
            }
        case .resetQuickLook:
            Task {
                let res = await MaintenanceService.shared.resetQuickLookCache()
                self.showNotification(message: res.message)
            }
        case .killProcess:
            if let pid = action.targetPID {
                killProcess(pid: pid, force: true)
                showNotification(message: "PID \(pid) süreci sonlandırıldı.")
            }
        }
    }
    
    public func testNIMConnection() {
        guard !isTestingNIM else { return }
        isTestingNIM = true
        nimTestResult = nil
        
        Task {
            let result = await NvidiaNIMService.shared.testConnection(config: self.nimConfig)
            await MainActor.run {
                self.isTestingNIM = false
                self.nimTestResult = result
            }
        }
    }
    
    public func scanRemoteNIMModels() {
        guard !isScanningNIMModels else { return }
        isScanningNIMModels = true
        
        Task {
            do {
                let models = try await NvidiaNIMService.shared.fetchAvailableModels(config: self.nimConfig)
                await MainActor.run {
                    self.isScanningNIMModels = false
                    var updatedConfig = self.nimConfig
                    updatedConfig.cachedModels = models
                    self.saveNIMConfig(updatedConfig)
                    self.showNotification(message: "NVIDIA NIM üzerinden \(models.count) adet model başarıyla tarandı ve listelendi!")
                }
            } catch {
                await MainActor.run {
                    self.isScanningNIMModels = false
                    self.showNotification(message: "Model tarama hatası: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func resolveAutonomousAlert(id: UUID) {
        if let index = autonomousAlerts.firstIndex(where: { $0.id == id }) {
            autonomousAlerts[index].isResolved = true
        }
    }
    
    public func clearAutonomousAlerts() {
        autonomousAlerts.removeAll()
    }
    
    // MARK: - RAM Freeing / Optimization
    public func purgeRAM() {
        guard !isPurgingMemory else { return }
        isPurgingMemory = true
        
        Task {
            let result = await MemoryOptimizerService.shared.purgeMemory()
            await MainActor.run {
                self.isPurgingMemory = false
                self.memoryPurgeResult = result
                self.refreshMetrics()
                
                if result.freedBytes > 0 {
                    let report = OptimizationReport(
                        title: "RAM Bellek Boşaltma",
                        freedMemoryBytes: result.freedBytes,
                        freedDiskBytes: 0,
                        details: [result.message],
                        durationSeconds: result.durationSeconds
                    )
                    self.addReport(report)
                }
            }
        }
    }
    
    public func killProcess(pid: Int32, force: Bool = false) {
        let proc = runningProcesses.first(where: { $0.pid == pid })
        let procName = proc?.name ?? "PID \(pid)"
        let procPath = proc?.path ?? ""
        
        guard SafetyGuard.isProcessKillable(pid: pid, name: procName, path: procPath) else {
            showNotification(message: "Güvenlik Engeli: '\(procName)' bir macOS sistem bileşenidir ve sonlandırılamaz.")
            return
        }
        
        Task {
            let success = await MemoryOptimizerService.shared.terminateProcess(pid: pid, name: procName, path: procPath, force: force)
            await MainActor.run {
                if success {
                    self.runningProcesses.removeAll { $0.pid == pid }
                    self.refreshMetrics(fullProcessRefresh: true)
                    self.showNotification(message: "\(procName) süreci başarıyla sonlandırıldı.")
                } else {
                    self.showNotification(message: "\(procName) süreci sonlandırılamadı.")
                }
            }
        }
    }
    
    // MARK: - 1-Click Smart Optimization
    public func runSmartOptimization() {
        guard !isOptimizingSmart else { return }
        isOptimizingSmart = true
        smartOptProgress = 0.0
        smartOptStatus = "Başlatılıyor..."
        
        Task {
            let report = await MaintenanceService.shared.runSmartOptimization { [weak self] message, progress in
                Task { @MainActor [weak self] in
                    self?.smartOptStatus = message
                    self?.smartOptProgress = progress
                }
            }
            
            await MainActor.run {
                self.isOptimizingSmart = false
                self.latestReport = report
                self.addReport(report)
                self.refreshMetrics()
                self.showNotification(message: "Akıllı iyileştirme başarıyla tamamlandı! \(report.freedMemoryFormatted) RAM ve \(report.freedDiskFormatted) disk alanı kazanıldı.")
            }
        }
    }
    
    // MARK: - Junk Cleaner Actions
    public func scanJunk() {
        guard !isScanningJunk else { return }
        isScanningJunk = true
        junkScanProgress = 0.0
        junkStatusMessage = "Taranıyor..."
        
        Task {
            let groups = await JunkCleanerService.shared.scanAll { [weak self] name, progress in
                Task { @MainActor [weak self] in
                    self?.junkStatusMessage = name
                    self?.junkScanProgress = progress
                }
            }
            
            await MainActor.run {
                self.junkGroups = groups
                self.isScanningJunk = false
                self.junkStatusMessage = "Tarama tamamlandı."
            }
        }
    }
    
    // MARK: - Dry-Run Cleaning Plan & Execution
    public func prepareCleaningPlan() {
        Task {
            let plan = await JunkCleanerService.shared.generateCleaningPlan(from: self.junkGroups)
            await MainActor.run {
                self.activeCleaningPlan = plan
            }
        }
    }
    
    public func executeActiveCleaningPlan() {
        guard let plan = activeCleaningPlan, !isCleaningJunk else { return }
        isCleaningJunk = true
        activeCleaningPlan = nil
        
        Task {
            let result = await JunkCleanerService.shared.executeCleaningPlan(plan) { [weak self] name, progress in
                Task { @MainActor [weak self] in
                    self?.junkStatusMessage = "\(name) temizleniyor..."
                    self?.junkScanProgress = progress
                }
            }
            
            await MainActor.run {
                self.isCleaningJunk = false
                self.refreshMetrics()
                self.scanJunk()
                
                let report = OptimizationReport(
                    title: "Gereksiz Dosya Temizliği (Dry-Run Onaylı)",
                    freedMemoryBytes: 0,
                    freedDiskBytes: result.totalFreedBytes,
                    details: [
                        "\(result.cleanedItemCount) öğe başarıyla temizlendi.",
                        result.failedItemCount > 0 ? "\(result.failedItemCount) öğe atlandı." : "Hata oluşmadı."
                    ],
                    durationSeconds: result.durationSeconds
                )
                self.addReport(report)
                self.showNotification(message: "\(ByteFormatter.format(result.totalFreedBytes)) gereksiz dosya başarıyla temizlendi.")
            }
        }
    }
    
    public func cleanSelectedJunk() {
        guard !isCleaningJunk else { return }
        isCleaningJunk = true
        
        var itemsToClean: [JunkFileItem] = []
        for group in junkGroups {
            itemsToClean.append(contentsOf: group.items.filter { $0.isSelected })
        }
        
        guard !itemsToClean.isEmpty else {
            isCleaningJunk = false
            return
        }
        
        Task {
            let result = await JunkCleanerService.shared.cleanItems(itemsToClean) { [weak self] name, progress in
                Task { @MainActor [weak self] in
                    self?.junkStatusMessage = "\(name) temizleniyor..."
                    self?.junkScanProgress = progress
                }
            }
            
            await MainActor.run {
                self.isCleaningJunk = false
                self.refreshMetrics()
                self.scanJunk()
                
                let report = OptimizationReport(
                    title: "Gereksiz Dosya Temizliği",
                    freedMemoryBytes: 0,
                    freedDiskBytes: result.freedBytes,
                    details: ["\(result.deletedCount) öğe başarıyla temizlendi."],
                    durationSeconds: 0.0
                )
                self.addReport(report)
                self.showNotification(message: "\(ByteFormatter.format(result.freedBytes)) gereksiz dosya başarıyla temizlendi.")
            }
        }
    }
    
    public func toggleJunkGroupSelection(type: JunkCategoryType) {
        guard let index = junkGroups.firstIndex(where: { $0.type == type }) else { return }
        let currentAllSelected = junkGroups[index].isAllSelected
        for i in 0..<junkGroups[index].items.count {
            junkGroups[index].items[i].isSelected = !currentAllSelected
        }
    }
    
    public func toggleJunkItemSelection(itemId: String) {
        for groupIndex in 0..<junkGroups.count {
            if let itemIndex = junkGroups[groupIndex].items.firstIndex(where: { $0.id == itemId }) {
                junkGroups[groupIndex].items[itemIndex].isSelected.toggle()
                break
            }
        }
    }
    
    // MARK: - App Manager & Update Actions
    public func scanApps() {
        guard !isScanningApps else { return }
        isScanningApps = true
        appScanProgress = 0.0
        appStatusMessage = "Uygulamalar taranıyor..."
        
        Task {
            let apps = await AppScannerService.shared.scanApplications { [weak self] name, progress in
                Task { @MainActor [weak self] in
                    self?.appStatusMessage = name
                    self?.appScanProgress = progress
                }
            }
            
            await MainActor.run {
                self.installedApps = apps
                self.isScanningApps = false
                self.appStatusMessage = "\(apps.count) uygulama bulundu."
            }
        }
    }
    
    public func checkAllAppUpdates() {
        guard !isCheckingUpdates else { return }
        isCheckingUpdates = true
        appStatusMessage = "Güncellemeler kontrol ediliyor..."
        
        Task {
            let updated = await AppUpdateCheckerService.shared.checkUpdates(for: self.installedApps) { [weak self] msg, progress in
                Task { @MainActor [weak self] in
                    self?.appStatusMessage = msg
                    self?.appScanProgress = progress
                }
            }
            
            await MainActor.run {
                self.installedApps = updated
                self.isCheckingUpdates = false
                let updatesFound = updated.filter { $0.updateInfo.hasUpdate }.count
                self.appStatusMessage = updatesFound > 0 ? "\(updatesFound) güncelleme mevcut!" : "Tüm uygulamalar güncel."
                self.showNotification(message: self.appStatusMessage)
            }
        }
    }
    
    public func loadAppFilesForUninstall(app: InstalledApp) {
        selectedAppForDetail = app
        isLoadingAppFiles = true
        
        Task {
            let files = await AppUninstallerService.shared.findAssociatedFiles(for: app)
            await MainActor.run {
                self.selectedAppFiles = files
                self.isLoadingAppFiles = false
            }
        }
    }
    
    public func performUninstall() {
        guard !isUninstalling, let app = selectedAppForDetail else { return }
        isUninstalling = true
        
        Task {
            let result = await AppUninstallerService.shared.uninstall(files: self.selectedAppFiles)
            await MainActor.run {
                self.isUninstalling = false
                self.selectedAppForDetail = nil
                self.selectedAppFiles = []
                self.installedApps.removeAll { $0.id == app.id }
                self.refreshMetrics()
                
                let report = OptimizationReport(
                    title: "\(app.name) Kaldırıldı",
                    freedMemoryBytes: 0,
                    freedDiskBytes: result.freedBytes,
                    details: ["\(result.deletedCount) ilişkili dosya silindi."],
                    durationSeconds: 0.0
                )
                self.addReport(report)
                self.showNotification(message: "\(app.name) ve tüm kalıntıları (\(ByteFormatter.format(result.freedBytes))) başarıyla kaldırıldı.")
            }
        }
    }
    
    // MARK: - Startup Items Actions
    public func scanStartupItems() {
        isLoadingStartup = true
        
        Task {
            let items = await StartupManagerService.shared.scanStartupItems()
            await MainActor.run {
                self.startupItems = items
                self.isLoadingStartup = false
            }
        }
    }
    
    public func toggleStartupItem(_ item: LaunchAgentItem) {
        Task {
            let newStatus = !item.isEnabled
            let success = await StartupManagerService.shared.toggleItem(item, enable: newStatus)
            if success {
                await MainActor.run {
                    if let index = self.startupItems.firstIndex(where: { $0.id == item.id }) {
                        self.startupItems[index].isEnabled = newStatus
                    }
                }
            }
        }
    }
    
    public func removeStartupItem(_ item: LaunchAgentItem) {
        Task {
            let success = await StartupManagerService.shared.removeItem(item)
            if success {
                await MainActor.run {
                    self.startupItems.removeAll { $0.id == item.id }
                }
            }
        }
    }
    
    // MARK: - Reports & History
    public func addReport(_ report: OptimizationReport) {
        optimizationHistory.insert(report, at: 0)
        saveHistory()
    }
    
    public func clearHistory() {
        optimizationHistory.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(optimizationHistory) {
            UserDefaults.standard.set(data, forKey: "MacOptimizer_History")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "MacOptimizer_History"),
           let history = try? JSONDecoder().decode([OptimizationReport].self, from: data) {
            self.optimizationHistory = history
        }
    }
    
    public func saveNIMConfig(_ config: NIMConfig) {
        self.nimConfig = config
        // Save API key securely in Keychain
        _ = KeychainManager.saveSecret(key: "nim_api_key", value: config.apiKey)
        
        // Save non-sensitive metadata in UserDefaults
        var safeConfig = config
        safeConfig.apiKey = "" // Keep empty in UserDefaults
        if let data = try? JSONEncoder().encode(safeConfig) {
            UserDefaults.standard.set(data, forKey: "MacOptimizer_NIMConfig")
        }
    }
    
    public func saveAutonomousConfig(_ config: AutonomousConfig) {
        self.autonomousConfig = config
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "MacOptimizer_AutonomousConfig")
        }
    }
    
    private func loadConfigs() {
        KeychainManager.migrateLegacySecretsIfNeeded()
        
        if let data = UserDefaults.standard.data(forKey: "MacOptimizer_NIMConfig"),
           var config = try? JSONDecoder().decode(NIMConfig.self, from: data) {
            // Load decrypted secret from macOS Keychain
            if let secretKey = KeychainManager.loadSecret(key: "nim_api_key") {
                config.apiKey = secretKey
            }
            self.nimConfig = config
        }
        if let data = UserDefaults.standard.data(forKey: "MacOptimizer_AutonomousConfig"),
           let config = try? JSONDecoder().decode(AutonomousConfig.self, from: data) {
            self.autonomousConfig = config
        }
    }
    
    public func auditSecurityPosture() {
        guard !isLoadingSecurityAudit else { return }
        isLoadingSecurityAudit = true
        Task {
            let report = await PrivacyAuditService.shared.runSecurityAudit()
            await MainActor.run {
                self.securityReport = report
                self.isLoadingSecurityAudit = false
            }
        }
    }
    
    public func scanDuplicates(targets: [DuplicateFileFinderService.ScanTargetDirectory] = [.downloads, .documents]) {
        guard !isScanningDuplicates else { return }
        isScanningDuplicates = true
        duplicateScanProgress = 0.0
        duplicateStatusMessage = "Yinelenen dosyalar taranıyor..."
        
        Task {
            let groups = await DuplicateFileFinderService.shared.findDuplicates(
                in: targets,
                progressHandler: { msg, progress in
                    Task { @MainActor in
                        self.duplicateStatusMessage = msg
                        self.duplicateScanProgress = progress
                    }
                }
            )
            
            await MainActor.run {
                self.duplicateGroups = groups
                self.isScanningDuplicates = false
                self.duplicateScanProgress = 1.0
                self.duplicateStatusMessage = groups.isEmpty ? "Yinelenen dosya bulunamadı." : "\(groups.count) yinelenen dosya grubu bulundu."
            }
        }
    }
    
    public func cleanDuplicates() {
        guard !isCleaningDuplicates && !duplicateGroups.isEmpty else { return }
        isCleaningDuplicates = true
        
        Task {
            let result = await DuplicateFileFinderService.shared.cleanDuplicates(self.duplicateGroups)
            await MainActor.run {
                self.isCleaningDuplicates = false
                self.showNotification(message: "\(result.deletedCount) yinelenen dosya Çöp Sepetine taşındı (\(ByteFormatter.format(result.freedBytes)) alan kazanıldı).")
                self.scanDuplicates()
            }
        }
    }
    
    public func showNotification(message: String) {
        activeAlertMessage = message
        showAlert = true
    }
}
