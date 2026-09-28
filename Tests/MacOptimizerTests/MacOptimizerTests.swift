import XCTest
@testable import MacOptimizer

final class MacOptimizerTests: XCTestCase {

    func testAutonomousConfigDecodesLegacyPurgeSetting() throws {
        let legacyJSON = #"{"isWatchdogActive":true,"autoPurgeRAMOnSpike":false,"ramThresholdPercent":85,"autoCleanTemporaryLogsWeekly":true,"notifyOnAnomalies":true,"scanIntervalSeconds":5,"cpuRunawayThresholdPercent":90}"#.data(using: .utf8)!
        let config = try JSONDecoder().decode(AutonomousConfig.self, from: legacyJSON)
        XCTAssertTrue(config.isWatchdogActive)
        XCTAssertEqual(config.ramThresholdPercent, 85)
    }

    func testEmptyTrashRemovesSymlinkEntryButPreservesTarget() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let trash = root.appendingPathComponent("Trash")
        let outside = root.appendingPathComponent("outside.txt")
        let link = trash.appendingPathComponent("link")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try Data("target".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = SafeOperationExecutor.emptyTrash([link], confirmation: SafeOperationExecutor.confirm(CleaningPlan()), trashDirectory: trash)

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: link.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testEmptyTrashSkipsEntryOutsideTrashAndRemovesNormalFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let trash = root.appendingPathComponent("Trash")
        let normal = trash.appendingPathComponent("normal.txt")
        let outside = root.appendingPathComponent("outside.txt")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try Data("normal".utf8).write(to: normal)
        try Data("keep".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = SafeOperationExecutor.emptyTrash([normal, outside], confirmation: SafeOperationExecutor.confirm(CleaningPlan()), trashDirectory: trash)

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: normal.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testExecutorRefusesDestructivePathWithoutConfirmation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("keep.txt")
        try Data("safe".utf8).write(to: file)

        XCTAssertThrowsError(try SafeOperationExecutor.removeFile(at: file, policyHomeDirectory: root))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testDeletionPolicyRejectsCacheLookalikePath() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let path = home.appendingPathComponent("x/Library/Caches/../../Documents/keep.txt").path
        XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(path, homeDirectory: home))
    }

    func testChangedSymlinkTargetFailsExecutorRevalidation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let first = root.appendingPathComponent("first")
        let second = root.appendingPathComponent("second")
        let link = root.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: first)
        let validated = link.resolvingSymlinksInPath().standardizedFileURL
        try FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: second)
        XCTAssertFalse(SafeOperationExecutor.stillResolvesTo(link, expected: validated))
    }

    func testCleanCacheRootsCanUseTemporaryHome() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cacheItem = home.appendingPathComponent("Library/Caches/item")
        try FileManager.default.createDirectory(at: cacheItem, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        XCTAssertTrue(PathProtectionPolicy.isCleanableCachePath(cacheItem.path, homeDirectory: home))
    }

    func testPermanentDeletionIsDeniedOutsideInjectedCacheRoots() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let document = home.appendingPathComponent("Documents/file.txt")
        try FileManager.default.createDirectory(at: document.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        XCTAssertFalse(SafeOperationExecutor.mayDeletePermanently(document.path, policyHomeDirectory: home))
    }

    func testCLIExecuteRequiresYesAndBundleIdentifierValidation() {
        XCTAssertTrue(CLICommandRunner.executionRequestedWithoutConfirmation(["clean", "--execute"]))
        XCTAssertFalse(CLICommandRunner.executionRequestedWithoutConfirmation(["clean", "--execute", "--yes"]))
        XCTAssertTrue(AppUninstallerService.isValidBundleIdentifier("org.example.App-1"))
        XCTAssertFalse(AppUninstallerService.isValidBundleIdentifier("org.example/../../Documents"))
        XCTAssertFalse(AppUninstallerService.isValidBundleIdentifier("org..example"))
    }
    
    // MARK: - 1. Property-Based Path Protection Tests (50+ Path Variations)
    func testSystemRootPathsForbidden() {
        let systemRoots = [
            "/",
            "/System",
            "/System/Applications",
            "/System/Library",
            "/System/Volumes",
            "/Library",
            "/Library/Apple",
            "/Library/Application Support/Apple",
            "/Library/Preferences",
            "/Library/Extensions",
            "/Library/Frameworks",
            "/Library/Keychains",
            "/Library/LaunchDaemons",
            "/Library/SystemExtensions",
            "/usr",
            "/usr/bin",
            "/usr/sbin",
            "/usr/lib",
            "/usr/libexec",
            "/bin",
            "/sbin",
            "/var",
            "/var/root",
            "/etc",
            "/dev",
            "/private",
            "/private/var",
            "/private/etc",
            "/Volumes",
            "/cores",
            "/opt"
        ]
        
        for path in systemRoots {
            XCTAssertTrue(PathProtectionPolicy.isForbiddenPath(path), "System path must be forbidden: \(path)")
            XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(path), "System path must not be cleanable: \(path)")
            XCTAssertFalse(SafetyGuard.isSafeToClean(path: path), "SafetyGuard must block system path: \(path)")
            XCTAssertEqual(OperationRiskClassifier.classifyFileRemoval(path: path), .forbidden, "Risk must be forbidden: \(path)")
        }
    }
    
    func testUserRootAndDataDirectoriesForbidden() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("macoptimizer-test-home").path
        let protectedUserPaths = [
            home,
            "\(home)/Desktop",
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Movies",
            "\(home)/Music",
            "\(home)/Pictures",
            "\(home)/Applications",
            "\(home)/Library",
            "\(home)/Library/Application Support",
            "\(home)/Library/Keychains",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages",
            "\(home)/Library/Photos",
            "\(home)/Library/Safari",
            "\(home)/Library/Preferences",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Mobile Documents",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/.aws",
            "\(home)/.config",
            "\(home)/.zshrc",
            "\(home)/.bash_profile",
            "\(home)/.bashrc",
            "\(home)/.gitconfig"
        ]
        
        for path in protectedUserPaths {
            XCTAssertTrue(PathProtectionPolicy.isForbiddenPath(path, homeDirectory: URL(fileURLWithPath: home)), "User essential data path must be forbidden: \(path)")
            XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(path, homeDirectory: URL(fileURLWithPath: home)), "User data path must not be cleanable: \(path)")
            XCTAssertEqual(OperationRiskClassifier.classifyFileRemoval(path: path), .forbidden, "Risk must be forbidden: \(path)")
        }
    }
    
    func testPathTraversalAndMalformedPaths() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("macoptimizer-test-home").path
        let maliciousPaths = [
            "\(home)/Library/Caches/../../../System",
            "\(home)/Library/Caches/../../Documents",
            "\(home)/Library/Caches/../../.ssh",
            "/System/../Users",
            "/usr/bin/../../System",
            "   ",
            "",
            "///",
            "/private/../etc",
            "\(home)/Desktop/../.gnupg"
        ]
        
        for path in maliciousPaths {
            XCTAssertTrue(PathProtectionPolicy.isForbiddenPath(path, homeDirectory: URL(fileURLWithPath: home)), "Traversal path must be forbidden: \(path)")
            XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(path, homeDirectory: URL(fileURLWithPath: home)), "Traversal path must not be cleanable: \(path)")
        }
    }
    
    func testApprovedCleanableCachesAllowed() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("macoptimizer-test-home").path
        let validCachePaths = [
            "\(home)/Library/Caches/com.example.app",
            "\(home)/Library/Caches/Google/Chrome/Default/Cache",
            "\(home)/Library/Logs/DiagnosticReports/crash.ips",
            "\(home)/Library/Developer/Xcode/DerivedData/MyApp-abcd",
            "\(home)/Library/Developer/Xcode/Archives/2026-08-28",
            "\(home)/Library/Developer/CoreSimulator/Caches/temp",
            "\(home)/.Trash/oldfile.txt"
        ]
        
        for path in validCachePaths {
            XCTAssertFalse(PathProtectionPolicy.isForbiddenPath(path, homeDirectory: URL(fileURLWithPath: home)), "Valid cache path must not be forbidden: \(path)")
            XCTAssertTrue(PathProtectionPolicy.isCleanableCachePath(path, homeDirectory: URL(fileURLWithPath: home)), "Valid cache path must be cleanable: \(path)")
            XCTAssertTrue(SafetyPolicyEngine.canDelete(path: path, homeDirectory: URL(fileURLWithPath: home)), "Policy engine must allow cleanable cache: \(path)")
        }
    }
    
    // MARK: - 2. Symlink Traversal Attack Tests
    func testSymlinkAttackResolution() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let symlinkToSystem = tempDir.appendingPathComponent("fake_cache_system")
        let symlinkToSSH = tempDir.appendingPathComponent("fake_cache_ssh")
        
        let home = tempDir.appendingPathComponent("home")
        let protected = home.appendingPathComponent(".ssh")
        try FileManager.default.createDirectory(at: protected, withIntermediateDirectories: true)
        
        try FileManager.default.createSymbolicLink(at: symlinkToSystem, withDestinationURL: tempDir.appendingPathComponent("system"))
        try FileManager.default.createSymbolicLink(at: symlinkToSSH, withDestinationURL: protected)
        
        XCTAssertTrue(PathProtectionPolicy.isForbiddenPath(symlinkToSSH.path, homeDirectory: home), "Symlink to injected home .ssh must be forbidden")
        XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(symlinkToSystem.path, homeDirectory: home))
        XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(symlinkToSSH.path, homeDirectory: home))
    }
    
    // MARK: - 3. Process Protection Policy Tests (35+ Daemons & System Procs)
    func testProtectedDaemonsAndPIDs() {
        // PID 0 and 1
        XCTAssertTrue(ProcessProtectionPolicy.isForbiddenProcess(pid: 0, name: "kernel_task"))
        XCTAssertTrue(ProcessProtectionPolicy.isForbiddenProcess(pid: 1, name: "launchd"))
        XCTAssertTrue(ProcessProtectionPolicy.isForbiddenProcess(pid: getpid(), name: "MacOptimizer"))
        
        let criticalProcesses = [
            "kernel_task", "launchd", "WindowServer", "loginwindow", "diskarbitrationd",
            "securityd", "opendirectoryd", "coreauthd", "syspolicyd", "tccd", "trustd",
            "Dock", "Finder", "SystemUIServer", "ControlCenter", "NotificationCenter",
            "mds", "mds_stores", "mdworker", "powerd", "notifyd", "logd", "fseventsd",
            "configd", "distnoted", "usbd", "bluetoothd", "airportd", "identityservicesd",
            "sharingd", "coreduetd", "apsd", "cupsd", "syslogd", "auditd", "diagnosticd",
            "runningboardd", "containermanagerd", "spindump"
        ]
        
        for proc in criticalProcesses {
            XCTAssertTrue(ProcessProtectionPolicy.isForbiddenProcess(pid: 9999, name: proc), "Process \(proc) must be forbidden from killing")
            XCTAssertFalse(SafetyPolicyEngine.canTerminateProcess(pid: 9999, name: proc), "Safety policy engine must deny termination for \(proc)")
            XCTAssertFalse(SafetyGuard.isProcessKillable(pid: 9999, name: proc), "SafetyGuard must block \(proc)")
            XCTAssertEqual(OperationRiskClassifier.classifyProcessTermination(pid: 9999, name: proc), .forbidden)
        }
    }
    
    func testKillableUserProcessesAllowed() {
        let userProcesses = [
            (pid: Int32(2048), name: "Google Chrome"),
            (pid: Int32(2049), name: "Spotify"),
            (pid: Int32(2050), name: "Slack"),
            (pid: Int32(2051), name: "Code"),
            (pid: Int32(2052), name: "Discord"),
            (pid: Int32(2053), name: "Figma")
        ]
        
        for proc in userProcesses {
            XCTAssertFalse(ProcessProtectionPolicy.isForbiddenProcess(pid: proc.pid, name: proc.name))
            XCTAssertTrue(SafetyPolicyEngine.canTerminateProcess(pid: proc.pid, name: proc.name))
            XCTAssertEqual(OperationRiskClassifier.classifyProcessTermination(pid: proc.pid, name: proc.name), .medium)
        }
    }
    
    // MARK: - 4. Application Protection Policy Tests
    func testProtectedAppleSystemApplications() {
        let appleSystemApps = [
            (path: "/System/Applications/Safari.app", id: "com.apple.Safari"),
            (path: "/System/Library/CoreServices/Finder.app", id: "com.apple.finder"),
            (path: "/System/Applications/Utilities/Terminal.app", id: "com.apple.Terminal"),
            (path: "/System/Applications/App Store.app", id: "com.apple.AppStore"),
            (path: "/System/Applications/Utilities/Activity Monitor.app", id: "com.apple.ActivityMonitor"),
            (path: "/System/Applications/Utilities/Disk Utility.app", id: "com.apple.DiskUtility"),
            (path: "/System/Applications/Utilities/Keychain Access.app", id: "com.apple.Keychain-Access"),
            (path: "/System/Applications/Utilities/Console.app", id: "com.apple.Console")
        ]
        
        for app in appleSystemApps {
            XCTAssertTrue(ApplicationProtectionPolicy.isProtectedApp(path: app.path, bundleIdentifier: app.id), "System app \(app.id) must be protected")
            XCTAssertFalse(SafetyPolicyEngine.canUninstallApp(path: app.path, bundleIdentifier: app.id))
            XCTAssertTrue(SafetyGuard.isProtectedSystemApp(path: app.path, bundleIdentifier: app.id))
        }
    }
    
    func testThirdPartyApplicationsCanBeUninstalled() {
        let thirdPartyApps = [
            (path: "/Applications/Google Chrome.app", id: "com.google.Chrome"),
            (path: "/Applications/Spotify.app", id: "com.spotify.client"),
            (path: "/Applications/Visual Studio Code.app", id: "com.microsoft.VSCode"),
            (path: "/Applications/Telegram.app", id: "ru.keepcoder.Telegram")
        ]
        
        for app in thirdPartyApps {
            XCTAssertFalse(ApplicationProtectionPolicy.isProtectedApp(path: app.path, bundleIdentifier: app.id))
            XCTAssertTrue(SafetyPolicyEngine.canUninstallApp(path: app.path, bundleIdentifier: app.id))
        }
    }
    
    // MARK: - 5. Launch Item Protection Policy Tests
    func testProtectedSystemLaunchItems() {
        let systemItems = [
            (path: "/System/Library/LaunchAgents/com.apple.xpc.activity.plist", label: "com.apple.xpc.activity"),
            (path: "/Library/LaunchDaemons/com.apple.securityd.plist", label: "com.apple.securityd"),
            (path: "/System/Library/LaunchDaemons/com.apple.logd.plist", label: "com.apple.logd")
        ]
        
        for item in systemItems {
            XCTAssertTrue(LaunchItemProtectionPolicy.isProtectedLaunchItem(path: item.path, label: item.label))
            XCTAssertTrue(SafetyGuard.isProtectedLaunchItem(path: item.path, label: item.label))
        }
    }
    
    func testUserLaunchItemsAllowed() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("macoptimizer-test-home").path
        let userItems = [
            (path: "\(home)/Library/LaunchAgents/com.google.keystone.agent.plist", label: "com.google.keystone.agent"),
            (path: "\(home)/Library/LaunchAgents/com.spotify.webhelper.plist", label: "com.spotify.webhelper"),
            (path: "\(home)/Library/LaunchAgents/com.dropbox.DropboxMacUpdate.agent.plist", label: "com.dropbox.DropboxMacUpdate")
        ]
        
        for item in userItems {
            XCTAssertFalse(LaunchItemProtectionPolicy.isProtectedLaunchItem(path: item.path, label: item.label))
            XCTAssertFalse(SafetyGuard.isProtectedLaunchItem(path: item.path, label: item.label))
        }
    }
    
    // MARK: - 6. OperationRiskClassifier & Policy Engine Evaluation
    func testOperationRiskOrdering() {
        XCTAssertTrue(OperationRisk.safe < OperationRisk.low)
        XCTAssertTrue(OperationRisk.low < OperationRisk.medium)
        XCTAssertTrue(OperationRisk.medium < OperationRisk.destructive)
        XCTAssertTrue(OperationRisk.destructive < OperationRisk.forbidden)
    }
    
    func testSafetyPolicyEngineDecisions() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("macoptimizer-test-home").path
        
        // Remove file
        let deniedDecision = SafetyPolicyEngine.evaluate(.removeFile(path: "\(home)/Documents"), homeDirectory: URL(fileURLWithPath: home))
        XCTAssertFalse(deniedDecision.isAllowed)
        
        let allowedDecision = SafetyPolicyEngine.evaluate(.removeFile(path: "\(home)/Library/Caches/temp.dat"), homeDirectory: URL(fileURLWithPath: home))
        XCTAssertTrue(allowedDecision.isAllowed)
        
        // Terminate process
        let deniedProc = SafetyPolicyEngine.evaluate(.terminateProcess(pid: 1, name: "launchd"))
        XCTAssertFalse(deniedProc.isAllowed)
        
        let allowedProc = SafetyPolicyEngine.evaluate(.terminateProcess(pid: 4000, name: "Chrome"))
        XCTAssertTrue(allowedProc.isAllowed)
        
        // Maintenance
        let maintDecision = SafetyPolicyEngine.evaluate(.executeMaintenance(taskIdentifier: "dns"))
        XCTAssertTrue(maintDecision.isAllowed)
    }
    
    // MARK: - 7. Dry-Run CleaningPlan Tests
    func testCleaningPlanGenerationAndPreview() async {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("macoptimizer-test-home").path
        
        let item1 = JunkFileItem(
            path: "\(home)/Library/Caches/test_app_1",
            name: "test_app_1",
            sizeBytes: 100 * 1024 * 1024,
            category: .systemCache,
            isSelected: true
        )
        let item2 = JunkFileItem(
            path: "\(home)/Library/Logs/test_app_2.log",
            name: "test_app_2.log",
            sizeBytes: 50 * 1024 * 1024,
            category: .systemLogs,
            isSelected: false
        )
        let itemForbidden = JunkFileItem(
            path: "\(home)/Documents",
            name: "Documents",
            sizeBytes: 500 * 1024 * 1024,
            category: .largeFiles,
            isSelected: true
        )
        
        let group = JunkCategoryGroup(type: .systemCache, items: [item1, item2, itemForbidden])
        let plan = await JunkCleanerService(homeDirectory: URL(fileURLWithPath: home)).generateCleaningPlan(from: [group])
        
        XCTAssertEqual(plan.items.count, 2, "Forbidden item must be excluded from plan")
        XCTAssertEqual(plan.totalEstimatedBytes, 150 * 1024 * 1024)
        XCTAssertEqual(plan.selectedEstimatedBytes, 100 * 1024 * 1024)
        XCTAssertEqual(plan.selectedCount, 1)
        XCTAssertTrue(plan.warnings.count >= 1)
    }
    
    // MARK: - 8. Sandboxed Command Runner Tests
    func testSandboxedCommandRunnerWhitelistedExecutables() {
        let executables = ApprovedExecutable.allCases
        XCTAssertTrue(executables.contains(.dscacheutil))
        XCTAssertTrue(executables.contains(.killall))
        XCTAssertTrue(executables.contains(.mdutil))
        XCTAssertTrue(executables.contains(.qlmanage))
    }
    
    func testSandboxedCommandArgumentFiltering() {
        XCTAssertEqual(SandboxedCommandRunner.sanitizedArguments(["-q", "host", "localhost; whoami"]), ["-q", "host"])
    }
    
    // MARK: - 9. Keychain Secret Manager Tests
    func testKeychainManagerSaveLoadDelete() {
        let testKey = "test_unit_secret_key"
        let service = "com.codifya.MacOptimizerTests.\(UUID().uuidString)"
        let testValue = "nvapi-test-token-123456"
        defer { _ = KeychainManager.deleteSecret(key: testKey, service: service) }
        
        // Save
        let saved = KeychainManager.saveSecret(key: testKey, value: testValue, service: service)
        XCTAssertTrue(saved, "Secret should be saved to Keychain")
        
        // Load
        let loaded = KeychainManager.loadSecret(key: testKey, service: service)
        XCTAssertEqual(loaded, testValue, "Loaded secret must match saved secret")
        
        // Delete
        let deleted = KeychainManager.deleteSecret(key: testKey, service: service)
        XCTAssertTrue(deleted, "Secret should be deleted from Keychain")
        
        // Confirm deleted
        let afterDelete = KeychainManager.loadSecret(key: testKey, service: service)
        XCTAssertNil(afterDelete, "Secret must be nil after deletion")
    }
    
    // MARK: - 10. AI Multi-Providers & Heuristic Tests
    func testLocalHeuristicProviderDiagnostics() async {
        let provider = LocalHeuristicProvider()
        XCTAssertEqual(provider.providerId, "local_heuristics")
        XCTAssertFalse(provider.requiresNetwork)
        
        var memory = MemoryStats()
        memory.totalBytes = 16 * 1024 * 1024 * 1024
        memory.activeBytes = 10 * 1024 * 1024 * 1024
        memory.wiredBytes = 5 * 1024 * 1024 * 1024
        memory.pressureLevel = .critical
        
        let cpu = CPUStats(totalUsage: 45.0)
        let disk = DiskStats(totalBytes: 500 * 1024 * 1024 * 1024, freeBytes: 200 * 1024 * 1024 * 1024)
        var hardware = HardwareInfo()
        hardware.modelName = "MacBook Pro"
        hardware.chipName = "Apple M3 Pro"
        hardware.osVersion = "macOS 15.0"
        
        let insights = await provider.diagnose(
            memory: memory,
            cpu: cpu,
            disk: disk,
            hardware: hardware,
            topProcesses: [],
            junkGroups: [],
            outdatedAppsCount: 2
        )
        
        XCTAssertFalse(insights.isEmpty)
        XCTAssertTrue(insights.contains(where: { $0.severity == .critical }))
        let memoryInsight = insights.first(where: { $0.category == "RAM" })
        XCTAssertTrue(memoryInsight?.actions.isEmpty == true)
        XCTAssertTrue(memoryInsight?.summary.contains("uygulamaları kapatmayı") == true)
    }
    
    func testNIMRequestPayloadDisclosureAndHistoryLimit() throws {
        let off = NvidiaNIMProvider.cloudContext("metrics", processNames: ["SecretApp (PID: 7)"], includeProcesses: false)
        XCTAssertFalse(off.contains("SecretApp"))
        let on = NvidiaNIMProvider.cloudContext("metrics", processNames: ["SecretApp (PID: 7)"], includeProcesses: true)
        XCTAssertTrue(on.contains("SecretApp"))

        let messages = (0..<10).map { ["role": "user", "content": "message-\($0)" + ($0 == 9 ? " /Users/alice/Secret.txt" : "")] }
        let body = try NvidiaNIMService.requestBody(messages: messages, config: NIMConfig(apiKey: "secret-key"))
        let payload = String(decoding: body, as: UTF8.self)
        XCTAssertFalse(payload.contains("secret-key"))
        XCTAssertFalse(payload.contains("/Users/"))
        XCTAssertTrue(payload.contains("[dosya yolu]"))
        XCTAssertFalse(payload.contains("message-0"))
        XCTAssertTrue(payload.contains("message-9"))
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual((decoded?["messages"] as? [[String: String]])?.count, 7)
    }
    
    // MARK: - 11. Mach-O Architecture Detector Tests
    func testMachOArchitectureDetectorHeaders() {
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("macho-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fixture) }
        try? Data([0xFE, 0xED, 0xFA, 0xCF, 0x01, 0x00, 0x00, 0x0C]).write(to: fixture)
        let arch = MachOArchitectureDetector.detect(at: fixture)
        XCTAssertEqual(arch, .appleSilicon)
    }
    
    // MARK: - 12. Version Comparator & ByteFormatter Tests
    func testVersionComparator() {
        XCTAssertTrue(VersionComparator.isNewer(remoteVersion: "2.0.0", than: "1.9.9"))
        XCTAssertTrue(VersionComparator.isNewer(remoteVersion: "1.0.1", than: "1.0.0"))
        XCTAssertTrue(VersionComparator.isNewer(remoteVersion: "1.10.0", than: "1.9.0"))
        XCTAssertTrue(VersionComparator.isNewer(remoteVersion: "2.0.0-beta.2", than: "2.0.0-beta.1"))
        XCTAssertFalse(VersionComparator.isNewer(remoteVersion: "1.0.0", than: "1.0.0"))
        XCTAssertFalse(VersionComparator.isNewer(remoteVersion: "1.0.0", than: "2.0.0"))
    }
    
    func testByteFormatter() {
        let short500 = ByteFormatter.formatShort(500)
        XCTAssertEqual(short500.value, "500")
        XCTAssertEqual(short500.unit, "B")
        
        let shortMB = ByteFormatter.formatShort(1024 * 1024 * 5)
        XCTAssertEqual(shortMB.value, "5")
        XCTAssertEqual(shortMB.unit, "MB")
        
        let shortGB = ByteFormatter.formatShort(Int64(1024 * 1024 * 1024 * 2))
        XCTAssertEqual(shortGB.value, "2.0")
        XCTAssertEqual(shortGB.unit, "GB")
        
        XCTAssertFalse(ByteFormatter.format(1024 * 1024).isEmpty)
        XCTAssertFalse(ByteFormatter.formatMemory(1024 * 1024 * 1024 * 16).isEmpty)
    }
    
    // MARK: - 13. Telemetry Store SQLite Tests
    func testTelemetryStoreRecordAndPurge() async {
        let store = makeTemporaryTelemetryStore()
        await store.record(
            cpuUsage: 12.5,
            ramUsedBytes: 8589934592,
            ramPressureLevel: 1,
            diskUsedBytes: 250000000000
        )
        await store.purgeOldRawSamples()
    }
    
    func testTelemetryStoreFetchHistoryAndDownsampling() async {
        let store = makeTemporaryTelemetryStore()
        // Record 15 points
        for i in 1...15 {
            await store.record(
                cpuUsage: Double(i * 5),
                ramUsedBytes: UInt64(i * 1024 * 1024 * 500),
                ramPressureLevel: 0,
                diskUsedBytes: 100000000000
            )
        }
        
        let history = await store.fetchHistory(hours: 1, maxPoints: 5)
        XCTAssertFalse(history.isEmpty)
        XCTAssertLessThanOrEqual(history.count, 5, "Downsampling should limit count to maxPoints")
    }
    
    // MARK: - 14. Thermal State & Swap Metrics Tests
    func testThermalStateProperties() {
        for state in CPUStats.ThermalState.allCases {
            XCTAssertFalse(state.rawValue.isEmpty)
            XCTAssertFalse(state.colorName.isEmpty)
            XCTAssertFalse(state.iconName.isEmpty)
        }
        
        var cpu = CPUStats()
        cpu.thermalState = .nominal
        XCTAssertEqual(cpu.thermalState.colorName, "green")
        
        cpu.thermalState = .critical
        XCTAssertEqual(cpu.thermalState.colorName, "red")
    }
    
    func testMemoryStatsSwapMetrics() {
        var mem = MemoryStats()
        mem.totalBytes = 17179869184 // 16 GB
        mem.activeBytes = 8589934592 // 8 GB
        mem.wiredBytes = 2147483648  // 2 GB
        mem.compressedBytes = 1073741824 // 1 GB
        mem.swapTotalBytes = 2147483648
        mem.swapUsedBytes = 536870912
        mem.swapFreeBytes = 1610612736
        
        XCTAssertEqual(mem.actualUsedBytes, 11811160064)
        XCTAssertEqual(mem.swapTotalBytes, 2147483648)
        XCTAssertEqual(mem.swapUsedBytes, 536870912)
    }
    
    // MARK: - 15. Autonomous Guard Watchdog Rule Engine Tests
    func testAutonomousGuardWatchdogRules() async {
        let guardService = AutonomousGuardService()
        
        var mem = MemoryStats()
        mem.totalBytes = 16000000000
        mem.activeBytes = 14000000000
        mem.wiredBytes = 1000000000
        mem.swapUsedBytes = 3 * 1024 * 1024 * 1024 // 3 GB swap (triggers swap rule)
        
        var cpu = CPUStats()
        cpu.totalUsage = 95.0
        cpu.thermalState = .serious // Triggers thermal rule
        
        var disk = DiskStats()
        disk.totalBytes = 500000000000
        disk.freeBytes = 5 * 1024 * 1024 * 1024 // 5 GB free (triggers low disk rule)
        
        var config = AutonomousConfig()
        config.isWatchdogActive = true
        
        let alerts = await guardService.evaluateCycle(
            memory: mem,
            cpu: cpu,
            disk: disk,
            processes: [],
            config: config
        )
        
        XCTAssertFalse(alerts.isEmpty, "Watchdog should generate alerts for critical metrics")
        let titles = alerts.map { $0.title }
        XCTAssertTrue(titles.contains(where: { $0.contains("Bellek") || $0.contains("RAM") || $0.contains("Memory") }))
        XCTAssertTrue(titles.contains(where: { $0.contains("Termal") || $0.contains("Sıcaklık") || $0.contains("Thermal") }))
        XCTAssertTrue(titles.contains(where: { $0.contains("Swap") }))
        XCTAssertTrue(titles.contains(where: { $0.contains("Disk") }))
    }
    
    func testAutonomousGuardSkipsProtectedSystemProcesses() async {
        let guardService = AutonomousGuardService()
        
        var mem = MemoryStats()
        mem.totalBytes = 16000000000
        
        var cpu = CPUStats()
        cpu.totalUsage = 50.0
        
        let disk = DiskStats()
        
        var config = AutonomousConfig()
        config.isWatchdogActive = true
        config.cpuRunawayThresholdPercent = 80.0
        
        let protectedProcess = ProcessInfoModel(
            pid: 100,
            name: "WindowServer",
            path: "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer",
            memoryBytes: 500000000,
            cpuPercentage: 99.0,
            isUserApp: false,
            bundleIdentifier: nil,
            isProtected: true
        )
        
        for _ in 1...5 {
            let alerts = await guardService.evaluateCycle(
                memory: mem,
                cpu: cpu,
                disk: disk,
                processes: [protectedProcess],
                config: config
            )
            // No kill alert should ever be created for WindowServer
            XCTAssertFalse(alerts.contains(where: { $0.title.contains("WindowServer") }))
        }
    }
    
    // MARK: - 16. Developer Junk Cleaner & CLI Runner Tests
    func testDeveloperCachesScanning() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = home.appendingPathComponent("Library/Developer/Xcode/DerivedData/fixture")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: cache.appendingPathComponent("data"))
        defer { try? FileManager.default.removeItem(at: home) }
        let groups = await JunkCleanerService(homeDirectory: home).scanCategory(.developerCache)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path))
        XCTAssertTrue(groups.allSatisfy { $0.path.hasPrefix(home.path + "/") })
    }
    
    func testCLICommandRunnerPSNFiltering() {
        XCTAssertFalse(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer"]))
        XCTAssertFalse(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "-psn_0_123456"]))
        XCTAssertFalse(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "-AppleLanguages", "(tr)"]))
        XCTAssertFalse(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "-NSDocumentRevisionsDebugMode", "YES"]))
        XCTAssertTrue(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "status"]))
        XCTAssertTrue(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "clean", "--dry-run"]))
        XCTAssertTrue(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "version"]))
        XCTAssertTrue(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "help"]))
        XCTAssertTrue(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "--version"]))
        XCTAssertTrue(CLICommandRunner.shouldHandleCLI(arguments: ["MacOptimizer", "unknown"]))
    }

    func testCLIHelpIsEnglishOnly() {
        XCTAssertFalse(CLICommandRunner.helpText.contains { "çğıİöşüÇĞÖŞÜ".contains($0) })
    }

    func testBatteryHealthUsesAppleSiliconCapacityAndIntelCapacityShapes() {
        let appleSilicon = ["AppleRawMaxCapacity": 4_600, "NominalChargeCapacity": 4_550, "DesignCapacity": 5_000]
        let intel = ["MaxCapacity": 4_000, "DesignCapacity": 5_000]
        XCTAssertEqual(SystemMonitorService.batteryHealthPercentage(properties: appleSilicon), 92)
        XCTAssertEqual(SystemMonitorService.batteryHealthPercentage(properties: intel), 80)
        XCTAssertEqual(SystemMonitorService.batteryHealthPercentage(properties: ["MaxCapacity": 96, "DesignCapacity": 5_000]), 96)
        XCTAssertEqual(SystemMonitorService.batteryHealthPercentage(properties: ["MaxCapacity": 6_000, "DesignCapacity": 5_000]), 100)
        XCTAssertEqual(SystemMonitorService.batteryHealthPercentage(properties: ["MaxCapacity": 5_000, "DesignCapacity": 0]), 0)
    }

    func testSecurityScoreAwardsNoFirewallPointsWhenDisabled() {
        XCTAssertEqual(PrivacyAuditService.score(sip: true, gatekeeper: true, firewall: false, accessibility: false), 55)
        XCTAssertEqual(PrivacyAuditService.score(sip: nil, gatekeeper: nil, firewall: false, accessibility: false), 0)
    }

    func testCPUSamplingRequiresTwoValidSamples() {
        XCTAssertEqual(SystemMonitorService.sampledCPUUsage(previous: [10, 20, 70, 0], current: [20, 25, 145, 0]) ?? -1, 16.6667, accuracy: 0.001)
        XCTAssertNil(SystemMonitorService.sampledCPUUsage(previous: [1, 2], current: [2, 3]))
        XCTAssertNil(SystemMonitorService.sampledCPUUsage(previous: [1, 2, 3, 4], current: [1, 2, 3, 4]))
    }

    func testMaintenanceResultMappingUsesBothCommandExitCodes() async {
        let service = MaintenanceService { executable, _ in
            CommandExecutionResult(exitCode: executable == .dscacheutil ? 0 : 1, stdout: "", stderr: "", durationMs: 0)
        }
        let result = await service.flushDNSCache()
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("mDNSResponder: 1"))
    }
    
    // MARK: - 17. Maintenance Service & App Uninstaller Tests
    func testMaintenanceServiceMethods() async {
        let recorder = MaintenanceTestRecorder()
        let service = MaintenanceService(commandRunner: { executable, _ in
            recorder.record(executable)
            return CommandExecutionResult(exitCode: 0, stdout: "", stderr: "", durationMs: 0)
        }, clipboardClearer: { recorder.clearClipboard() })
        let dns = await service.flushDNSCache()
        let quickLook = await service.resetQuickLookCache()
        let clipboard = await service.clearClipboard()
        XCTAssertTrue(dns.success)
        XCTAssertTrue(quickLook.success)
        XCTAssertTrue(clipboard.success)
        XCTAssertEqual(recorder.commands, [.dscacheutil, .killall, .qlmanage])
        XCTAssertTrue(recorder.clipboardWasCleared)
    }
    
    func testAppUninstallerProtectedAppsRefused() async {
        let safari = InstalledApp(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            path: "/System/Applications/Safari.app",
            version: "17.0",
            sizeBytes: 50000000,
            isSystemApp: true
        )
        
        let items = await AppUninstallerService.shared.findAssociatedFiles(for: safari)
        XCTAssertTrue(items.isEmpty, "System apps must never have uninstallation files discovered")
    }
    
    // MARK: - 18. Privacy & Security Posture Audit Tests
    func testPrivacyAuditServiceEvaluation() async {
        let service = PrivacyAuditService(commandRunner: { executable, _ in
            let output = executable == .csrutil ? "System Integrity Protection status: enabled" : executable == .spctl ? "assessments enabled" : "Firewall is enabled"
            return CommandExecutionResult(exitCode: 0, stdout: output, stderr: "", durationMs: 0)
        }, accessibilityChecker: { false })
        let report = await service.runSecurityAudit()
        XCTAssertGreaterThanOrEqual(report.score, 0)
        XCTAssertLessThanOrEqual(report.score, 100)
        XCTAssertGreaterThanOrEqual(report.items.count, 4)
        XCTAssertFalse(report.ratingDescription.isEmpty)
        XCTAssertFalse(report.ratingColorName.isEmpty)
    }
    
    // MARK: - 19. Duplicate File Finder Models & Algorithm Tests
    func testDuplicateItemAndGroupModel() {
        let item1 = DuplicateItem(
            id: "/tmp/doc1.pdf",
            path: "/tmp/doc1.pdf",
            name: "doc1.pdf",
            sizeBytes: 204800,
            modificationDate: Date(timeIntervalSince1970: 1000),
            isSelectedForDeletion: false
        )
        
        let item2 = DuplicateItem(
            id: "/tmp/doc1_copy.pdf",
            path: "/tmp/doc1_copy.pdf",
            name: "doc1_copy.pdf",
            sizeBytes: 204800,
            modificationDate: Date(timeIntervalSince1970: 2000),
            isSelectedForDeletion: true
        )
        
        let group = DuplicateFileGroup(
            id: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            original: item1,
            duplicates: [item2],
            sizePerFile: 204800
        )
        
        XCTAssertEqual(group.totalWastedBytes, 204800)
        XCTAssertEqual(group.duplicates.count, 1)
        XCTAssertFalse(group.original.isSelectedForDeletion)
        XCTAssertTrue(group.duplicates[0].isSelectedForDeletion)
    }
    
    // MARK: - 20. Battery & Power Telemetry Tests
    func testBatteryStatsMetrics() {
        var stats = BatteryStats()
        stats.isPresent = true
        stats.percentage = 95
        stats.cycleCount = 142
        stats.healthPercentage = 98
        stats.temperatureCelsius = 29.5
        stats.condition = "Normal"
        
        XCTAssertFalse(stats.isOverheating)
        
        stats.temperatureCelsius = 42.0
        XCTAssertTrue(stats.isOverheating)
    }
    
    // MARK: - 21. Network Throughput Telemetry Tests
    func testNetworkStatsThroughputFormatting() {
        var stats = NetworkStats()
        stats.downloadBytesPerSec = 15_728_640.0 // ~15 MB/s
        stats.uploadBytesPerSec = 2_097_152.0    // ~2 MB/s
        
        XCTAssertEqual(stats.downloadSpeedFormatted, "15.0 MB/s")
        XCTAssertEqual(stats.uploadSpeedFormatted, "2.0 MB/s")
        
        stats.downloadBytesPerSec = 512.0
        XCTAssertEqual(stats.downloadSpeedFormatted, "512 B/s")
    }

    private func makeTemporaryTelemetryStore() -> TelemetryStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("telemetry-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return TelemetryStore(databaseURL: url)
    }


    private final class MaintenanceTestRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _commands: [ApprovedExecutable] = []
        private var _clipboardWasCleared = false
        var commands: [ApprovedExecutable] { lock.withLock { _commands } }
        var clipboardWasCleared: Bool { lock.withLock { _clipboardWasCleared } }
        func record(_ executable: ApprovedExecutable) { lock.withLock { _commands.append(executable) } }
        func clearClipboard() { lock.withLock { _clipboardWasCleared = true } }
    }

}
