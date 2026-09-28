import XCTest
import Combine
@testable import MacOptimizer

/// Regression guards for the performance/concurrency hardening pass.
/// These assert invariants (bounds, lifecycles, termination), not machine-dependent timings;
/// time limits below are generous upper bounds for "did not hang".
final class PerformanceHardeningTests: XCTestCase {

    // MARK: - Bounded storage

    func testRingBufferKeepsOnlyCapacityElements() {
        var buffer = RingBuffer<Int>(capacity: 60)
        for value in 0..<10_000 { buffer.append(value) }
        XCTAssertEqual(buffer.count, 60)
        XCTAssertEqual(buffer.first, 9_940)
        XCTAssertEqual(buffer.last, 9_999)
        XCTAssertEqual(Array(buffer), Array(9_940..<10_000))
    }

    func testBoundedArrayHelpers() {
        var newestFirst: [Int] = []
        var oldestFirst: [Int] = []
        for value in 0..<1_000 {
            newestFirst.prependBounded(value, limit: 200)
            oldestFirst.appendBounded(value, limit: 100)
        }
        XCTAssertEqual(newestFirst.count, 200)
        XCTAssertEqual(newestFirst.first, 999)
        XCTAssertEqual(oldestFirst.count, 100)
        XCTAssertEqual(oldestFirst.last, 999)
    }

    @MainActor
    func testLiveMetricsChartHistoryIsBounded() {
        let store = LiveMetricsStore()
        for index in 0..<10_000 {
            var sample = MetricsSample()
            var cpu = CPUStats()
            cpu.totalUsage = Double(index % 100)
            sample.cpu = cpu
            sample.memory = MemoryStats()
            store.apply(sample)
        }
        XCTAssertEqual(store.chartHistory.count, LiveMetricsStore.chartHistoryCapacity)
        // Identifiers stay unique and monotonic (stable SwiftUI identity).
        let ids = store.chartHistory.map(\.id)
        XCTAssertEqual(ids, ids.sorted())
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    @MainActor
    func testLiveMetricsStoreSkipsUnchangedAssignments() {
        let store = LiveMetricsStore()
        var publishCount = 0
        let cancellable = store.objectWillChange.sink { publishCount += 1 }
        var sample = MetricsSample()
        sample.disk = DiskStats()      // equal to the initial value → must not publish
        sample.battery = BatteryStats()
        store.apply(sample)
        XCTAssertEqual(publishCount, 0)
        cancellable.cancel()
    }

    @MainActor
    func testBoundsAreDeclared() {
        let autonomousAlertsLimit = AppState.maxAutonomousAlerts
        let chatMessagesLimit = AppState.maxChatMessages
        let optimizationHistoryLimit = AppState.maxOptimizationHistory
        let iconCacheLimit = AppIconCache.countLimit
        XCTAssertLessThanOrEqual(autonomousAlertsLimit, 500)
        XCTAssertLessThanOrEqual(chatMessagesLimit, 200)
        XCTAssertLessThanOrEqual(optimizationHistoryLimit, 1_000)
        XCTAssertLessThanOrEqual(iconCacheLimit, 512)
    }

    // MARK: - Process execution (deadlock / timeout / cancellation)

    func testLargeOutputDoesNotDeadlock() async {
        // 512 KB far exceeds the 64 KB pipe buffer that made the old runner hang until its timeout.
        let start = Date()
        let result = await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/head"),
            arguments: ["-c", "524288", "/dev/zero"],
            timeout: 10
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertFalse(result.isTimedOut)
        XCTAssertEqual(result.standardOutput.utf8.count, 524_288)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testOutputIsCappedAndChildStillCompletes() async {
        let result = await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/head"),
            arguments: ["-c", "8000000", "/dev/zero"],
            timeout: 10,
            outputLimit: 100_000
        )
        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.isTruncated)
        XCTAssertEqual(result.standardOutput.utf8.count, 100_000)
    }

    func testHungProcessTimesOutWithControlledError() async {
        let start = Date()
        let result = await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["30"],
            timeout: 0.5
        )
        XCTAssertTrue(result.isTimedOut)
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.exitCode, -2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testTermIgnoringProcessIsKilled() async {
        let start = Date()
        let result = await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "trap '' TERM; while :; do sleep 1; done"],
            timeout: 0.3
        )
        XCTAssertTrue(result.isTimedOut)
        XCTAssertLessThan(Date().timeIntervalSince(start), 8)
    }

    func testCancellationTerminatesChild() async {
        let start = Date()
        let task = Task {
            await ProcessExecutor.run(executableURL: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], timeout: 60)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        let result = await task.value
        XCTAssertTrue(result.isCancelled)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testMissingExecutableReturnsError() async {
        let result = await ProcessExecutor.run(executableURL: URL(fileURLWithPath: "/nonexistent/tool"), timeout: 1)
        XCTAssertEqual(result.exitCode, -1)
        XCTAssertFalse(result.standardError.isEmpty)
    }

    func testConcurrentExecutionsAreIsolated() async {
        let correct = await withTaskGroup(of: Bool.self) { group in
            for index in 0..<32 {
                group.addTask {
                    let result = await SystemCommandRunner.run(executable: "/bin/echo", arguments: ["\(index)"], timeoutSeconds: 5)
                    return result.standardOutput == "\(index)"
                }
            }
            var count = 0
            for await ok in group where ok { count += 1 }
            return count
        }
        XCTAssertEqual(correct, 32)
    }

    // MARK: - Timeout / blocking bridge / throttling

    func testWithTimeoutThrowsForSlowOperation() async {
        do {
            _ = try await withTimeout(seconds: 0.2) {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return 1
            }
            XCTFail("Expected timeout")
        } catch {
            XCTAssertTrue(error is OperationTimeoutError)
        }
    }

    func testWithTimeoutReturnsFastResult() async throws {
        let value = try await withTimeout(seconds: 2) { 42 }
        XCTAssertEqual(value, 42)
    }

    func testRunBlockingObservesCancellation() async {
        let start = Date()
        let task = Task {
            await runBlocking { flag -> Int in
                var spins = 0
                while !flag.isCancelled { usleep(1_000); spins += 1 }
                return spins
            }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        _ = await task.value
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
    }

    func testProgressThrottleCoalescesAndDeliversFinal() {
        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var count = 0
            private(set) var last = 0.0
            func record(_ value: Double) { lock.lock(); count += 1; last = value; lock.unlock() }
        }
        let counter = Counter()
        let throttle = ProgressThrottle(interval: 0.1) { _, progress in counter.record(progress) }
        for index in 0..<100_000 { throttle.report("file", Double(index) / 100_000) }
        throttle.report("done", 1.0)
        XCTAssertLessThan(counter.count, 50)
        XCTAssertEqual(counter.last, 1.0)
    }

    // MARK: - Monitoring scheduler

    func testSchedulePolicyOnlySpawnsProcessesWhenConsumed() {
        let policy = MetricsSchedulePolicy()
        let hidden = MonitoringDemand(isUIVisible: false, wantsProcesses: false, watchdogActive: false)
        XCTAssertNil(policy.interval(for: .processes, demand: hidden))
        XCTAssertNil(policy.interval(for: .processes, demand: MonitoringDemand(isUIVisible: true, wantsProcesses: false)))
        XCTAssertNotNil(policy.interval(for: .processes, demand: MonitoringDemand(isUIVisible: false, wantsProcesses: false, watchdogActive: true)))
        XCTAssertGreaterThan(policy.tickInterval(for: hidden), policy.tickInterval(for: MonitoringDemand()))
    }

    @MainActor
    func testSimulatedHourProcessSpawnBudget() async {
        final class Clock: @unchecked Sendable { var now: TimeInterval = 0 }
        let cases: [(MonitoringDemand, ClosedRange<Int>)] = [
            (MonitoringDemand(), 470...490),                                                              // dashboard visible
            (MonitoringDemand(isUIVisible: true, wantsProcesses: false), 0...0),                          // other screen
            (MonitoringDemand(isUIVisible: false, wantsProcesses: false, watchdogActive: true), 170...190),// background watchdog
            (MonitoringDemand(isUIVisible: false, wantsProcesses: false, watchdogActive: false), 0...0),  // idle
        ]
        for (demand, expected) in cases {
            let clock = Clock()
            let sampler = FakeSampler()
            let coordinator = MonitoringCoordinator(sampler: sampler, demand: demand, clock: { clock.now })
            while clock.now < 3_600 {
                clock.now += await coordinator.runCycle()
            }
            XCTAssertTrue(expected.contains(sampler.processCalls), "\(demand): \(sampler.processCalls) ps spawns/hour")
        }
    }

    @MainActor
    func testStartIsIdempotentAndCyclesNeverOverlap() async {
        var policy = MetricsSchedulePolicy()
        policy.visibleCoreInterval = 0.01
        let sampler = FakeSampler(delayNanoseconds: 30_000_000)
        let coordinator = MonitoringCoordinator(sampler: sampler, policy: policy)
        coordinator.start()
        coordinator.start()
        coordinator.start()
        for _ in 0..<20 { coordinator.refreshNow(includeProcesses: true) }
        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(sampler.maxConcurrentCoreSamples, 1)

        coordinator.stop()
        XCTAssertFalse(coordinator.isRunning)
        let afterStop = sampler.coreCalls
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertLessThanOrEqual(sampler.coreCalls, afterStop + 1)
    }

    @MainActor
    func testReleasedCoordinatorStopsItsLoop() async {
        var policy = MetricsSchedulePolicy()
        policy.visibleCoreInterval = 0.01
        let sampler = FakeSampler()
        var coordinator: MonitoringCoordinator? = MonitoringCoordinator(sampler: sampler, policy: policy)
        let weakCoordinator = { [weak coordinator] in coordinator }
        coordinator?.start()
        try? await Task.sleep(nanoseconds: 100_000_000)
        coordinator = nil
        try? await Task.sleep(nanoseconds: 200_000_000)
        let calls = sampler.coreCalls
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(weakCoordinator())
        XCTAssertEqual(sampler.coreCalls, calls)
    }

    @MainActor
    func testAppStateNavigationDoesNotMultiplyWorkers() async {
        let sampler = FakeSampler()
        let state = AppState(startMonitoring: false, sampler: sampler)
        state.startMonitoring()
        for tab in NavigationTab.allCases + NavigationTab.allCases {
            state.selectedTab = tab
            state.startMonitoring()
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(state.isMonitoring)
        XCTAssertEqual(sampler.maxConcurrentCoreSamples, 1)
        state.stopMonitoring()
        XCTAssertFalse(state.isMonitoring)
    }

    // MARK: - Watchdog correctness

    func testRunawayRuleIgnoresStaleProcessLists() async {
        let guardService = AutonomousGuardService()
        var config = AutonomousConfig()
        config.isWatchdogActive = true
        config.cpuRunawayThresholdPercent = 80
        let hot = ProcessInfoModel(pid: 4242, name: "HotApp", path: "/Applications/HotApp.app/Contents/MacOS/HotApp", cpuPercentage: 99)

        var mem = MemoryStats()
        mem.totalBytes = 16_000_000_000
        // One fresh sample followed by cached copies must not look like 3 consecutive measurements.
        var alerts = await guardService.evaluateCycle(memory: mem, cpu: CPUStats(), disk: DiskStats(), processes: [hot], config: config, processesAreFresh: true)
        for _ in 0..<5 {
            alerts += await guardService.evaluateCycle(memory: mem, cpu: CPUStats(), disk: DiskStats(), processes: [hot], config: config, processesAreFresh: false)
        }
        XCTAssertFalse(alerts.contains { $0.type == .runawayProcess })
    }

    func testRunawayStreakResetsWhenProcessCoolsDown() async {
        let guardService = AutonomousGuardService()
        var config = AutonomousConfig()
        config.isWatchdogActive = true
        config.cpuRunawayThresholdPercent = 80
        let path = "/Applications/HotApp.app/Contents/MacOS/HotApp"
        let hot = ProcessInfoModel(pid: 4243, name: "HotApp", path: path, cpuPercentage: 99)
        let cool = ProcessInfoModel(pid: 4243, name: "HotApp", path: path, cpuPercentage: 1)
        var mem = MemoryStats()
        mem.totalBytes = 16_000_000_000

        var alerts: [AutonomousAlert] = []
        for proc in [hot, hot, cool, hot, hot] {
            alerts += await guardService.evaluateCycle(memory: mem, cpu: CPUStats(), disk: DiskStats(), processes: [proc], config: config)
        }
        XCTAssertFalse(alerts.contains { $0.type == .runawayProcess }, "streak must reset after a cool sample")
        alerts = await guardService.evaluateCycle(memory: mem, cpu: CPUStats(), disk: DiskStats(), processes: [hot], config: config)
        XCTAssertTrue(alerts.contains { $0.type == .runawayProcess })
    }

    // MARK: - Scanners

    func testDuplicateFinderUsesContentNotJustPrefix() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("sub"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let base = Data((0..<300_000).map { UInt8($0 % 251) })
        var differentTail = base
        differentTail[299_999] ^= 0xFF
        try base.write(to: root.appendingPathComponent("a.bin"))
        try base.write(to: root.appendingPathComponent("sub/a-copy.bin"))
        try differentTail.write(to: root.appendingPathComponent("tail.bin"))

        let groups = DuplicateFileFinderService.findDuplicatesSync(in: [root], minSizeBytes: 100, flag: CancellationFlag(), progressHandler: nil)
        XCTAssertEqual(groups.count, 1)
        let names = Set(groups.flatMap { [$0.original.name] + $0.duplicates.map(\.name) })
        XCTAssertEqual(names, ["a.bin", "a-copy.bin"])
    }

    func testCancelledDuplicateScanReturnsPromptly() {
        let flag = CancellationFlag()
        flag.cancel()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let start = Date()
        let groups = DuplicateFileFinderService.findDuplicatesSync(in: [home], minSizeBytes: 1, flag: flag, progressHandler: nil)
        XCTAssertTrue(groups.isEmpty)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }

    func testFileSizeCalculatorAcrossPoolSlices() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("size-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for index in 0..<1_000 {
            try Data(count: 3).write(to: root.appendingPathComponent("f\(index)"))
        }
        XCTAssertEqual(FileSizeCalculator.size(of: root), 3_000)
        let cancelled = CancellationFlag()
        cancelled.cancel()
        XCTAssertEqual(FileSizeCalculator.size(of: root, cancellation: cancelled), 0)
    }

    func testCancelledJunkScanTerminates() async {
        let start = Date()
        let task = Task { await JunkCleanerService.shared.scanAll() }
        task.cancel()
        _ = await task.value
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }

    // MARK: - Command injection hardening

    func testHomebrewCaskTokenValidation() {
        XCTAssertTrue(AppUpdateCheckerService.isValidCaskToken("visual-studio-code"))
        XCTAssertTrue(AppUpdateCheckerService.isValidCaskToken("font-fira-code@3"))
        XCTAssertFalse(AppUpdateCheckerService.isValidCaskToken("foo; rm -rf ~"))
        XCTAssertFalse(AppUpdateCheckerService.isValidCaskToken("$(whoami)"))
        XCTAssertFalse(AppUpdateCheckerService.isValidCaskToken("Visual Studio Code"))
        XCTAssertFalse(AppUpdateCheckerService.isValidCaskToken(""))
        XCTAssertEqual(AppUpdateCheckerService.caskToken(fromUpgradeCommand: "brew upgrade --cask firefox"), "firefox")
        XCTAssertNil(AppUpdateCheckerService.caskToken(fromUpgradeCommand: "brew upgrade --cask a && curl evil"))
        XCTAssertNil(AppUpdateCheckerService.caskToken(fromUpgradeCommand: "brew x; curl evil"))
        XCTAssertNil(AppUpdateCheckerService.caskToken(fromUpgradeCommand: "rm -rf /"))
    }

    // MARK: - Telemetry

    func testTelemetryHistoryIsBoundedByMaxPoints() async {
        let store = TelemetryStore.shared
        for index in 0..<200 {
            await store.record(cpuUsage: Double(index % 100), ramUsedBytes: 1, ramPressureLevel: 0, diskUsedBytes: 1)
        }
        let history = await store.fetchHistory(hours: 1, maxPoints: 10)
        XCTAssertFalse(history.isEmpty)
        XCTAssertLessThanOrEqual(history.count, 10)
        XCTAssertEqual(history.map(\.timestamp), history.map(\.timestamp).sorted())
    }
}

// MARK: - Test doubles

/// Deterministic sampler that records call counts and detects overlapping cycles.
final class FakeSampler: SystemMetricsSampling, @unchecked Sendable {
    private let lock = NSLock()
    private let delayNanoseconds: UInt64
    private var _coreCalls = 0
    private var _processCalls = 0
    private var inFlight = 0
    private var _maxConcurrent = 0

    init(delayNanoseconds: UInt64 = 0) {
        self.delayNanoseconds = delayNanoseconds
    }

    var coreCalls: Int { locked { _coreCalls } }
    var processCalls: Int { locked { _processCalls } }
    var maxConcurrentCoreSamples: Int { locked { _maxConcurrent } }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    func sampleCore() async -> (MemoryStats, CPUStats, NetworkStats) {
        locked {
            _coreCalls += 1
            inFlight += 1
            _maxConcurrent = max(_maxConcurrent, inFlight)
        }
        if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
        locked { inFlight -= 1 }
        return (MemoryStats(), CPUStats(), NetworkStats())
    }

    func sampleDisk() async -> DiskStats { DiskStats() }
    func sampleBattery() async -> BatteryStats { BatteryStats() }
    func sampleHardware() async -> HardwareInfo { HardwareInfo() }

    func sampleProcesses() async -> [ProcessInfoModel]? {
        locked { _processCalls += 1 }
        return []
    }
}
