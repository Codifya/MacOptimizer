import XCTest
@testable import MacOptimizer

final class MacOptimizerTests: XCTestCase {
    
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
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
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
            XCTAssertTrue(PathProtectionPolicy.isForbiddenPath(path), "User essential data path must be forbidden: \(path)")
            XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(path), "User data path must not be cleanable: \(path)")
            XCTAssertEqual(OperationRiskClassifier.classifyFileRemoval(path: path), .forbidden, "Risk must be forbidden: \(path)")
        }
    }
    
    func testPathTraversalAndMalformedPaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
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
            XCTAssertTrue(PathProtectionPolicy.isForbiddenPath(path), "Traversal path must be forbidden: \(path)")
            XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(path), "Traversal path must not be cleanable: \(path)")
        }
    }
    
    func testApprovedCleanableCachesAllowed() {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
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
            XCTAssertFalse(PathProtectionPolicy.isForbiddenPath(path), "Valid cache path must not be forbidden: \(path)")
            XCTAssertTrue(PathProtectionPolicy.isCleanableCachePath(path), "Valid cache path must be cleanable: \(path)")
            XCTAssertTrue(SafetyPolicyEngine.canDelete(path: path), "Policy engine must allow cleanable cache: \(path)")
        }
    }
    
    // MARK: - 2. Symlink Traversal Attack Tests
    func testSymlinkAttackResolution() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let symlinkToSystem = tempDir.appendingPathComponent("fake_cache_system")
        let symlinkToSSH = tempDir.appendingPathComponent("fake_cache_ssh")
        
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        
        try? FileManager.default.createSymbolicLink(at: symlinkToSystem, withDestinationURL: URL(fileURLWithPath: "/System"))
        try? FileManager.default.createSymbolicLink(at: symlinkToSSH, withDestinationURL: URL(fileURLWithPath: "\(home)/.ssh"))
        
        XCTAssertTrue(PathProtectionPolicy.isForbiddenPath(symlinkToSystem.path), "Symlink to /System must be resolved and forbidden")
        XCTAssertTrue(PathProtectionPolicy.isForbiddenPath(symlinkToSSH.path), "Symlink to ~/.ssh must be resolved and forbidden")
        XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(symlinkToSystem.path))
        XCTAssertFalse(PathProtectionPolicy.isCleanableCachePath(symlinkToSSH.path))
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
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
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
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        
        // Remove file
        let deniedDecision = SafetyPolicyEngine.evaluate(.removeFile(path: "\(home)/Documents"))
        XCTAssertFalse(deniedDecision.isAllowed)
        
        let allowedDecision = SafetyPolicyEngine.evaluate(.removeFile(path: "\(home)/Library/Caches/temp.dat"))
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
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        
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
        let plan = await JunkCleanerService.shared.generateCleaningPlan(from: [group])
        
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
    
    func testSandboxedCommandExecution() async {
        let result = await SandboxedCommandRunner.run(
            executable: .dscacheutil,
            arguments: ["-q", "host", "-a", "name", "localhost"],
            timeoutSeconds: 5.0
        )
        XCTAssertTrue(result.durationMs >= 0)
    }
    
    // MARK: - 9. Keychain Secret Manager Tests
    func testKeychainManagerSaveLoadDelete() {
        let testKey = "test_unit_secret_key"
        let testValue = "nvapi-test-token-123456"
        
        // Save
        let saved = KeychainManager.saveSecret(key: testKey, value: testValue)
        XCTAssertTrue(saved, "Secret should be saved to Keychain")
        
        // Load
        let loaded = KeychainManager.loadSecret(key: testKey)
        XCTAssertEqual(loaded, testValue, "Loaded secret must match saved secret")
        
        // Delete
        let deleted = KeychainManager.deleteSecret(key: testKey)
        XCTAssertTrue(deleted, "Secret should be deleted from Keychain")
        
        // Confirm deleted
        let afterDelete = KeychainManager.loadSecret(key: testKey)
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
    }
    
    func testOllamaAndOpenAIProvidersInstantiation() {
        let ollama = OllamaProvider(baseURL: "http://localhost:11434", model: "llama3.2")
        XCTAssertEqual(ollama.providerId, "ollama_local")
        XCTAssertFalse(ollama.requiresNetwork)
        
        let openai = OpenAICompatibleProvider(baseURL: "https://api.openai.com", apiKey: "test-key", model: "gpt-4o")
        XCTAssertEqual(openai.providerId, "openai_compatible")
        XCTAssertTrue(openai.requiresNetwork)
    }
    
    // MARK: - 11. Mach-O Architecture Detector Tests
    func testMachOArchitectureDetectorHeaders() {
        let armPath = "/usr/bin/tar"
        if FileManager.default.fileExists(atPath: armPath) {
            let arch = MachOArchitectureDetector.detect(at: URL(fileURLWithPath: armPath))
            XCTAssertTrue(arch == .appleSilicon || arch == .universal || arch == .intel, "Architecture must be valid: \(arch)")
        }
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
        let store = TelemetryStore.shared
        await store.record(
            cpuUsage: 12.5,
            ramUsedBytes: 8589934592,
            ramPressureLevel: 1,
            diskUsedBytes: 250000000000
        )
        await store.purgeOldRawSamples()
    }
    
    func testTelemetryStoreFetchHistoryAndDownsampling() async {
        let store = TelemetryStore.shared
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
}
