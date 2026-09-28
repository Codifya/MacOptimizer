import Foundation
import SwiftUI
import AppKit
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
        case .dashboard: return L10n.string("Dashboard")
        case .aiCopilot: return L10n.string("AI Assistant & Advisor")
        case .autonomousGuard: return L10n.string("Autonomous Protection")
        case .memory: return L10n.string("RAM & Memory")
        case .junkCleaner: return L10n.string("Junk Cleaner")
        case .duplicateFinder: return L10n.string("Duplicate Files")
        case .appManager: return L10n.string("App Manager")
        case .appUpdates: return L10n.string("Updates")
        case .startupManager: return L10n.string("Startup Items")
        case .maintenance: return L10n.string("System Maintenance")
        case .security: return L10n.string("Security & Privacy")
        case .history: return L10n.string("Reports & History")
        case .settings: return L10n.string("Settings & AI Hub")
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

/// Global Application State for MacOptimizer.
///
/// Holds low-frequency, user-driven state (navigation, scan results, AI chat, settings). High-frequency
/// hardware metrics live in `metrics` (`LiveMetricsStore`) so a 2.5 s metrics tick no longer
/// invalidates every view that observes `AppState`.
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // MARK: Memory bounds (long-running sessions must plateau, not grow)
    public static let maxAutonomousAlerts = 200
    public static let maxChatMessages = 100
    public static let maxOptimizationHistory = 500
    
    @Published public var selectedTab: NavigationTab = .dashboard {
        didSet { if oldValue != selectedTab { updateMonitoringDemand() } }
    }
    
    // Live Hardware & Metrics — owned here, observed directly by metric views.
    public let metrics: LiveMetricsStore
    private let monitor: MonitoringCoordinator
    private var visibilityObservers: [NSObjectProtocol] = []
    private var isUIVisible = true
    
    // Non-reactive convenience accessors for actions and AI context. Views observe `metrics` instead.
    public var memoryStats: MemoryStats { metrics.memoryStats }
    public var cpuStats: CPUStats { metrics.cpuStats }
    public var diskStats: DiskStats { metrics.diskStats }
    public var batteryStats: BatteryStats { metrics.batteryStats }
    public var networkStats: NetworkStats { metrics.networkStats }
    public var hardwareInfo: HardwareInfo { metrics.hardwareInfo }
    public var runningProcesses: [ProcessInfoModel] { metrics.runningProcesses }
    
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
    @Published public var autonomousConfig = AutonomousConfig() {
        didSet { if oldValue.isWatchdogActive != autonomousConfig.isWatchdogActive { updateMonitoringDemand() } }
    }
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
    
    // Security & Privacy Audit State
    @Published public var securityReport: SecurityAuditReport?
    @Published public var isLoadingSecurityAudit = false
    
    // Alert / Notification State
    @Published public var activeAlertMessage: String?
    @Published public var showAlert = false
    @Published public var aiKillConfirmationPID: Int32?
    
    public var unresolvedAlertsCount: Int {
        autonomousAlerts.filter { !$0.isResolved }.count
    }
    
    // Owned long-running user operations. Starting a new one cancels its predecessor, and each can be
    // cancelled explicitly, so navigation or repeated clicks never stack background workers.
    private var junkScanTask: Task<Void, Never>?
    private var duplicateScanTask: Task<Void, Never>?
    private var appScanTask: Task<Void, Never>?
    
    public init(startMonitoring shouldStartMonitoring: Bool = true, sampler: SystemMetricsSampling = SystemMonitorService.shared) {
        self.metrics = LiveMetricsStore()
        self.monitor = MonitoringCoordinator(sampler: sampler)
        loadConfigs()
        loadHistory()
        initDefaultChat()
        updateMonitoringDemand()
        if shouldStartMonitoring {
            startMonitoring()
        }
    }
    
    private func initDefaultChat() {
        if chatMessages.isEmpty {
            chatMessages.append(AIChatMessage(
                role: .assistant,
                content: L10n.string("Hello! I’m your MacOptimizer AI assistant. I can analyze your system, clean junk files, and check for app updates. How can I help?"),
                actions: [
                    AIAction(title: L10n.string("Analyze System Status"), type: .analyzeSystem),
                    AIAction(title: L10n.string("Scan for Junk Files"), type: .scanJunk)
                ]
            ))
        }
    }
    
    // MARK: - Live System Monitoring & Autonomous Loop
    
    /// Idempotent: calling it repeatedly (e.g. from multiple scenes) never creates a second loop.
    public func startMonitoring() {
        monitor.setHandler { [weak self] sample in
            await self?.handleSample(sample)
        }
        observeApplicationVisibility()
        monitor.start()
        monitor.refreshNow(includeProcesses: monitoringDemand.wantsProcesses)
    }
    
    public func stopMonitoring() {
        monitor.stop()
        for observer in visibilityObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        visibilityObservers.removeAll()
    }
    
    public var isMonitoring: Bool { monitor.isRunning }
    
    /// Requests an immediate, coalesced sample. Never runs concurrently with the scheduled loop.
    public func refreshMetrics(fullProcessRefresh: Bool = false) {
        monitor.refreshNow(includeProcesses: fullProcessRefresh)
    }
    
    private var monitoringDemand: MonitoringDemand {
        MonitoringDemand(
            isUIVisible: isUIVisible,
            wantsProcesses: selectedTab == .dashboard || selectedTab == .memory,
            watchdogActive: autonomousConfig.isWatchdogActive
        )
    }
    
    private func updateMonitoringDemand() {
        monitor.updateDemand(monitoringDemand)
    }
    
    /// Tracks whether any window (main window or menu bar popover) is on screen so sampling can drop
    /// from 2.5 s to the watchdog/idle cadence while the app is hidden or fully occluded.
    private func observeApplicationVisibility() {
        guard visibilityObservers.isEmpty else { return }
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didChangeOcclusionStateNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification
        ]
        visibilityObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshVisibility()
                }
            }
        }
    }
    
    private func refreshVisibility() {
        let app = NSApplication.shared
        let visible = !app.isHidden && app.occlusionState.contains(.visible)
        guard visible != isUIVisible else { return }
        isUIVisible = visible
        updateMonitoringDemand()
    }
    
    private func handleSample(_ sample: MetricsSample) async {
        metrics.apply(sample)
        
        if sample.tiers.contains(.telemetry) {
            let memory = metrics.memoryStats
            let cpu = metrics.cpuStats
            let disk = metrics.diskStats
            let pressure: Int
            switch memory.pressureLevel {
            case .normal: pressure = 0
            case .warning: pressure = 1
            case .critical: pressure = 2
            }
            await TelemetryStore.shared.recordAndPrune(
                cpuUsage: cpu.totalUsage,
                ramUsedBytes: memory.actualUsedBytes,
                ramPressureLevel: pressure,
                diskUsedBytes: disk.usedBytes
            )
        }
        
        guard autonomousConfig.isWatchdogActive else { return }
        let newAlerts = await AutonomousGuardService.shared.evaluateCycle(
            memory: metrics.memoryStats,
            cpu: metrics.cpuStats,
            disk: metrics.diskStats,
            processes: sample.processes ?? [],
            config: autonomousConfig,
            processesAreFresh: sample.processes != nil
        )
        ingestAlerts(newAlerts)
    }
    
    private func ingestAlerts(_ newAlerts: [AutonomousAlert]) {
        guard !newAlerts.isEmpty else { return }
        let now = Date()
        for alert in newAlerts {
            let isDuplicate = autonomousAlerts.contains {
                $0.title == alert.title && now.timeIntervalSince($0.timestamp) < 30.0
            }
            guard !isDuplicate else { continue }
            autonomousAlerts.prependBounded(alert, limit: Self.maxAutonomousAlerts)
            if autonomousConfig.notifyOnAnomalies && !alert.autoHealed {
                showNotification(message: "\(alert.title): \(alert.message)")
            }
        }
    }
    
    /// Wraps a progress callback so updates reach the main actor at most ~10×/s.
    private func throttledProgress(_ apply: @escaping @MainActor @Sendable (AppState, String, Double) -> Void) -> @Sendable (String, Double) -> Void {
        ProgressThrottle(interval: 0.1) { [weak self] message, progress in
            Task { @MainActor [weak self] in
                guard let self else { return }
                apply(self, message, progress)
            }
        }.handler
    }
    
    // MARK: - AI Health Analysis & NVIDIA NIM
    public func runAIHealthAnalysis() {
        guard !isAnalyzingAI else { return }
        isAnalyzingAI = true
        
        Task {
            // Processes are only sampled while a process screen is visible; fetch on demand otherwise.
            let processes = self.runningProcesses.isEmpty
                ? await SystemMonitorService.shared.fetchRunningProcesses()
                : self.runningProcesses
            let insights = await AIAssistantService.shared.analyzeSystemHealth(
                memory: self.memoryStats,
                cpu: self.cpuStats,
                disk: self.diskStats,
                hardware: self.hardwareInfo,
                topProcesses: processes,
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
        chatMessages.appendBounded(userMsg, limit: Self.maxChatMessages)
        isChatThinking = true
        
        let baseContext = """
        Mac Modeli: \(hardwareInfo.modelName) (\(hardwareInfo.chipName)), macOS Sürümü: \(hardwareInfo.osVersion)
        RAM: %\(Int(memoryStats.usedPercentage * 100))
        CPU: %\(String(format: "%.1f", cpuStats.totalUsage)), Boş Disk: %\(Int(diskStats.freePercentage * 100))
        """
        let context = NvidiaNIMProvider.cloudContext(
            baseContext,
            processNames: runningProcesses.prefix(4).map { "\($0.name) (PID: \($0.pid))" },
            includeProcesses: UserDefaults.standard.bool(forKey: "MacOptimizer_IncludeRunningAppNames")
        )
        
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
                self.chatMessages.appendBounded(assistantMsg, limit: Self.maxChatMessages)
            }
        }
    }
    
    public func executeAIAction(_ action: AIAction) {
        switch action.type {
        case .analyzeSystem:
            runAIHealthAnalysis()
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
                aiKillConfirmationPID = pid
            }
        }
    }

    public func confirmAIProcessTermination() {
        guard let pid = aiKillConfirmationPID else { return }
        aiKillConfirmationPID = nil
        killProcess(pid: pid, force: false)
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
                    self.showNotification(message: L10n.string("Found and listed %lld models from NVIDIA NIM.", models.count))
                }
            } catch {
                await MainActor.run {
                    self.isScanningNIMModels = false
                    self.showNotification(message: L10n.string("Model scan failed: %@", error.localizedDescription))
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
    
    public func killProcess(pid: Int32, force: Bool = false) {
        Task {
            // The process list may be stale (or empty) when no process screen is visible — e.g. a kill
            // requested from a watchdog alert. Resolve name/path from a fresh sample so the safety
            // policy always evaluates the real executable, never just "PID n".
            var proc = self.runningProcesses.first(where: { $0.pid == pid })
            if proc == nil {
                proc = await SystemMonitorService.shared.fetchRunningProcesses(forceRefresh: true).first(where: { $0.pid == pid })
            }
            let procName = proc?.name ?? "PID \(pid)"
            let procPath = proc?.path ?? ""
            
            guard SafetyGuard.isProcessKillable(pid: pid, name: procName, path: procPath) else {
                self.showNotification(message: L10n.string("Security blocked the action: %@ is a macOS system component and cannot be terminated.", procName))
                return
            }
            
            let success = await MemoryOptimizerService.shared.terminateProcess(pid: pid, name: procName, path: procPath, force: force)
            if success {
                self.metrics.removeProcess(pid: pid)
                self.refreshMetrics(fullProcessRefresh: true)
                self.showNotification(message: L10n.string("Process %@ was terminated successfully.", procName))
            } else {
                self.showNotification(message: L10n.string("Process %@ could not be terminated.", procName))
            }
        }
    }
    
    // MARK: - 1-Click Smart Optimization
    public func runSmartOptimization() {
        guard !isOptimizingSmart else { return }
        isOptimizingSmart = true
        smartOptProgress = 0.0
        smartOptStatus = L10n.string("Starting…")
        Task {
            let groups = await withTaskGroup(of: [JunkFileItem].self) { group in
                for category: JunkCategoryType in [.systemCache, .systemLogs, .browserCache] {
                    group.addTask { await JunkCleanerService.shared.scanCategory(category) }
                }
                var items: [JunkFileItem] = []
                for await result in group { items += result }
                return items
            }
            let plan = await JunkCleanerService.shared.generateCleaningPlan(from: [JunkCategoryGroup(type: .systemCache, items: groups)])
            await MainActor.run {
                self.isOptimizingSmart = false
                self.activeCleaningPlan = plan
                self.selectedTab = .junkCleaner
            }
        }
    }
    
    // MARK: - Junk Cleaner Actions
    public func scanJunk() {
        guard !isScanningJunk else { return }
        isScanningJunk = true
        junkScanProgress = 0.0
        junkStatusMessage = L10n.string("Scanning…")
        
        let progress = throttledProgress { state, name, progress in
            state.junkStatusMessage = name
            state.junkScanProgress = progress
        }
        junkScanTask = Task { [weak self] in
            let groups = await JunkCleanerService.shared.scanAll(progressHandler: progress)
            guard let self else { return }
            self.isScanningJunk = false
            if Task.isCancelled {
                self.junkStatusMessage = "Tarama iptal edildi."
            } else {
                self.junkGroups = groups
                self.junkStatusMessage = "Tarama tamamlandı."
            }
        }
    }
    
    public func cancelJunkScan() {
        junkScanTask?.cancel()
        junkScanTask = nil
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
            let confirmation = SafeOperationExecutor.confirm(plan)
            let result = await JunkCleanerService.shared.executeCleaningPlan(plan, confirmation: confirmation, progressHandler: self.throttledProgress { state, name, progress in
                state.junkStatusMessage = "\(name) temizleniyor..."
                state.junkScanProgress = progress
            })
            
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
                self.showNotification(message: L10n.string("Cleaned %@ of junk files successfully.", ByteFormatter.format(result.totalFreedBytes)))
            }
        }
    }
    
    public func cleanSelectedJunk() {
        prepareCleaningPlan()
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
        
        let progress = throttledProgress { state, name, progress in
            state.appStatusMessage = name
            state.appScanProgress = progress
        }
        appScanTask = Task { [weak self] in
            let apps = await AppScannerService.shared.scanApplications(progressHandler: progress)
            guard let self else { return }
            self.isScanningApps = false
            if Task.isCancelled {
                self.appStatusMessage = "Tarama iptal edildi."
            } else {
                self.installedApps = apps
                self.appStatusMessage = "\(apps.count) uygulama bulundu."
            }
        }
    }
    
    public func checkAllAppUpdates() {
        guard !isCheckingUpdates else { return }
        isCheckingUpdates = true
        appStatusMessage = "Güncellemeler kontrol ediliyor..."
        
        Task {
            // Wait for an in-flight app scan so updates are checked against the complete list.
            await self.appScanTask?.value
            let updated = await AppUpdateCheckerService.shared.checkUpdates(for: self.installedApps, progressHandler: self.throttledProgress { state, msg, progress in
                state.appStatusMessage = msg
                state.appScanProgress = progress
            })
            
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
            let result = await AppUninstallerService.shared.uninstall(files: self.selectedAppFiles, confirmation: SafeOperationExecutor.confirm(CleaningPlan()))
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
                self.showNotification(message: L10n.string("%@ and all its leftovers (%@) were removed successfully.", app.name, ByteFormatter.format(result.freedBytes)))
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
            let success = await StartupManagerService.shared.removeItem(item, confirmation: SafeOperationExecutor.confirm(CleaningPlan()))
            if success {
                await MainActor.run {
                    self.startupItems.removeAll { $0.id == item.id }
                }
            }
        }
    }
    
    // MARK: - Reports & History
    public func addReport(_ report: OptimizationReport) {
        optimizationHistory.prependBounded(report, limit: Self.maxOptimizationHistory)
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
            self.optimizationHistory = Array(history.prefix(Self.maxOptimizationHistory))
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
        
        let progress = throttledProgress { state, msg, progress in
            state.duplicateStatusMessage = msg
            state.duplicateScanProgress = progress
        }
        duplicateScanTask = Task { [weak self] in
            let groups = await DuplicateFileFinderService.shared.findDuplicates(in: targets, progressHandler: progress)
            guard let self else { return }
            self.isScanningDuplicates = false
            if Task.isCancelled {
                self.duplicateStatusMessage = "Tarama iptal edildi."
                return
            }
            self.duplicateGroups = groups
            self.duplicateScanProgress = 1.0
            self.duplicateStatusMessage = groups.isEmpty ? "Yinelenen dosya bulunamadı." : "\(groups.count) yinelenen dosya grubu bulundu."
        }
    }
    
    public func cancelDuplicateScan() {
        duplicateScanTask?.cancel()
        duplicateScanTask = nil
    }
    
    public func cleanDuplicates() {
        guard !isCleaningDuplicates && !duplicateGroups.isEmpty else { return }
        isCleaningDuplicates = true
        
        Task {
            let result = await DuplicateFileFinderService.shared.cleanDuplicates(self.duplicateGroups, confirmation: SafeOperationExecutor.confirm(CleaningPlan()))
            await MainActor.run {
                self.isCleaningDuplicates = false
                self.showNotification(message: L10n.string("Moved %lld duplicate files to Trash (%@ freed).", result.deletedCount, ByteFormatter.format(result.freedBytes)))
                self.scanDuplicates()
            }
        }
    }
    
    public func showNotification(message: String) {
        activeAlertMessage = message
        showAlert = true
    }
}
