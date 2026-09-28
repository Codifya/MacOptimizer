import Foundation

/// One sampling pass. `nil` fields were not due (or failed) in this cycle; consumers keep previous values.
public struct MetricsSample: Sendable {
    public var tiers: Set<MetricTier> = []
    public var memory: MemoryStats?
    public var cpu: CPUStats?
    public var network: NetworkStats?
    public var disk: DiskStats?
    public var battery: BatteryStats?
    public var hardware: HardwareInfo?
    /// Non-nil only when `/bin/ps` actually ran this cycle (fresh data, not a cached copy).
    public var processes: [ProcessInfoModel]?

    public init() {}
}

/// Source of raw metrics. `SystemMonitorService` is the production implementation; tests inject fakes.
public protocol SystemMetricsSampling: Sendable {
    func sampleCore() async -> (MemoryStats, CPUStats, NetworkStats)
    func sampleDisk() async -> DiskStats
    func sampleBattery() async -> BatteryStats
    func sampleHardware() async -> HardwareInfo
    /// Returns `nil` when sampling failed so the caller keeps the last good list.
    func sampleProcesses() async -> [ProcessInfoModel]?
}

/// The single owner of periodic system sampling.
///
/// Replaces the previous `Timer` that fired every 2.5 s and spawned a *new, unowned* `Task` per tick
/// (ticks could overlap when a sample was slow, and nothing bounded how many were in flight).
///
/// Guarantees:
/// * exactly one sampling loop exists (`start()` is idempotent) and only that loop samples, so
///   cycles can never overlap; `refreshNow()` wakes the loop instead of sampling concurrently;
/// * the loop captures `self` weakly and stops on `stop()`, cancellation, or deallocation;
/// * each tier runs on its own interval derived from `MonitoringDemand` (see `MetricsSchedulePolicy`),
///   so hidden windows cost almost nothing and `/bin/ps` only runs when something consumes it;
/// * a failing tier never blocks the others (every sampler returns a value; process failure → `nil`).
@MainActor
public final class MonitoringCoordinator {
    public typealias SampleHandler = @MainActor (MetricsSample) async -> Void

    public private(set) var demand: MonitoringDemand
    public let policy: MetricsSchedulePolicy

    private let sampler: SystemMetricsSampling
    private let clock: @Sendable () -> TimeInterval
    private var handler: SampleHandler?

    private var loopTask: Task<Void, Never>?
    private var sleeper: Task<Void, Never>?
    private var lastRun: [MetricTier: TimeInterval] = [:]
    private var forcedTiers: Set<MetricTier> = []

    /// Diagnostics used by tests and the performance report.
    public private(set) var completedCycles = 0
    public private(set) var tierRunCounts: [MetricTier: Int] = [:]
    public var isRunning: Bool { loopTask != nil }

    public init(
        sampler: SystemMetricsSampling,
        policy: MetricsSchedulePolicy = MetricsSchedulePolicy(),
        demand: MonitoringDemand = MonitoringDemand(),
        clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.sampler = sampler
        self.policy = policy
        self.demand = demand
        self.clock = clock
    }

    /// Registers the consumer of samples (store update, watchdog, telemetry persistence).
    public func setHandler(_ handler: @escaping SampleHandler) {
        self.handler = handler
    }

    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = await self?.runCycle() else { return }
                if Task.isCancelled { return }
                let sleeper = Task<Void, Never> {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                self?.sleeper = sleeper
                await withTaskCancellationHandler {
                    await sleeper.value
                } onCancel: {
                    sleeper.cancel()
                }
                self?.sleeper = nil
            }
        }
    }

    public func stop() {
        loopTask?.cancel()
        loopTask = nil
        sleeper?.cancel()
        sleeper = nil
    }

    /// Updates what the UI needs. Waking the loop applies the new cadence immediately
    /// (e.g. switching from the 60 s idle cadence to 2.5 s when the window reappears).
    public func updateDemand(_ newDemand: MonitoringDemand) {
        guard newDemand != demand else { return }
        let becameMoreDemanding = policy.tickInterval(for: newDemand) < policy.tickInterval(for: demand)
            || (newDemand.wantsProcesses && !demand.wantsProcesses)
        demand = newDemand
        if becameMoreDemanding { wake() }
    }

    /// Requests an out-of-schedule sample (after a purge, a kill, a manual refresh).
    /// Coalesced: repeated calls before the loop wakes result in a single cycle.
    public func refreshNow(includeProcesses: Bool = false) {
        forcedTiers.insert(.core)
        if includeProcesses { forcedTiers.insert(.processes) }
        wake()
    }

    private func wake() {
        sleeper?.cancel()
    }

    /// Runs one sampling cycle and returns the time to sleep until the next one.
    @discardableResult
    func runCycle() async -> TimeInterval {
        let now = clock()
        var due = policy.dueTiers(now: now, lastRun: lastRun, demand: demand)
        due.insert(.core)
        due.formUnion(forcedTiers)
        forcedTiers.removeAll()
        let wantsProcesses = due.contains(.processes)

        var sample = MetricsSample()
        sample.tiers = due

        // Tiers are independent; await them one by one (cheap in-process calls) except the
        // process list, which is the only one that can take hundreds of milliseconds.
        let sampler = self.sampler
        async let processes: [ProcessInfoModel]? = wantsProcesses ? sampler.sampleProcesses() : nil
        let (memory, cpu, network) = await sampler.sampleCore()
        sample.memory = memory
        sample.cpu = cpu
        sample.network = network
        if due.contains(.disk) { sample.disk = await sampler.sampleDisk() }
        if due.contains(.battery) { sample.battery = await sampler.sampleBattery() }
        if due.contains(.hardware) { sample.hardware = await sampler.sampleHardware() }
        sample.processes = await processes

        for tier in due {
            lastRun[tier] = now
            tierRunCounts[tier, default: 0] += 1
        }
        completedCycles += 1

        if !Task.isCancelled, let handler {
            await handler(sample)
        }
        return policy.tickInterval(for: demand)
    }
}
