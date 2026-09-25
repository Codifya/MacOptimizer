import Foundation

/// Independently scheduled groups of system metrics.
///
/// Classification (see docs/PERFORMANCE_REPORT.md):
/// * CRITICAL – `core`: feeds the menu bar, the watchdog and persisted telemetry; never fully stops.
/// * NORMAL   – `disk`, `battery`, `telemetry`: change slowly, sampled on long intervals.
/// * UI_ONLY  – `processes`, `hardware`: only sampled while a screen that shows them is on screen
///              (`processes` is also needed by the watchdog's runaway-process rule).
public enum MetricTier: String, CaseIterable, Sendable, Hashable {
    case core       // memory, CPU, network throughput (Mach/sysctl/getifaddrs, in-process, cheap)
    case disk       // volume capacity (resource-value lookups can take tens of ms)
    case battery    // IOPowerSources + AppleSmartBattery IORegistry dictionary
    case hardware   // model/chip/OS are static; only uptime changes
    case processes  // spawns /bin/ps — the single most expensive sample
    case telemetry  // persist one row to SQLite for the History screen
}

/// What the UI and the watchdog currently need. Everything the scheduler does is derived from this.
public struct MonitoringDemand: Equatable, Sendable {
    /// Any app window (main window or menu bar popover) is on screen.
    public var isUIVisible: Bool
    /// The visible screen renders the process list (dashboard, memory manager).
    public var wantsProcesses: Bool
    /// The autonomous watchdog is enabled and must keep evaluating in the background.
    public var watchdogActive: Bool

    public init(isUIVisible: Bool = true, wantsProcesses: Bool = true, watchdogActive: Bool = false) {
        self.isUIVisible = isUIVisible
        self.wantsProcesses = wantsProcesses
        self.watchdogActive = watchdogActive
    }
}

/// Pure scheduling rules: given the demand and when each tier last ran, which tiers are due and
/// how long to sleep. Kept free of AppKit/SwiftUI so it can be unit-tested deterministically.
public struct MetricsSchedulePolicy: Sendable, Equatable {
    public var visibleCoreInterval: TimeInterval = 2.5
    public var watchdogCoreInterval: TimeInterval = 10.0
    public var idleCoreInterval: TimeInterval = 60.0
    public var diskInterval: TimeInterval = 30.0
    public var visibleBatteryInterval: TimeInterval = 30.0
    public var hiddenBatteryInterval: TimeInterval = 120.0
    public var hardwareInterval: TimeInterval = 60.0
    public var visibleProcessInterval: TimeInterval = 7.5
    public var watchdogProcessInterval: TimeInterval = 20.0 // multiple of watchdogCoreInterval
    public var telemetryInterval: TimeInterval = 60.0

    public init() {}

    /// Sleep between scheduler cycles.
    public func tickInterval(for demand: MonitoringDemand) -> TimeInterval {
        if demand.isUIVisible { return visibleCoreInterval }
        if demand.watchdogActive { return watchdogCoreInterval }
        return idleCoreInterval
    }

    /// Interval for a tier under the given demand, or `nil` when nobody needs it.
    public func interval(for tier: MetricTier, demand: MonitoringDemand) -> TimeInterval? {
        switch tier {
        case .core:
            return tickInterval(for: demand)
        case .disk:
            return diskInterval
        case .battery:
            return demand.isUIVisible ? visibleBatteryInterval : hiddenBatteryInterval
        case .hardware:
            return demand.isUIVisible ? hardwareInterval : nil
        case .processes:
            if demand.isUIVisible && demand.wantsProcesses { return visibleProcessInterval }
            if demand.watchdogActive { return watchdogProcessInterval }
            return nil
        case .telemetry:
            return telemetryInterval
        }
    }

    /// Tiers that should be sampled at `now`. A tier that has never run is due immediately if needed.
    /// A small tolerance (10% of the tick) avoids skipping a tier because of timer jitter.
    public func dueTiers(
        now: TimeInterval,
        lastRun: [MetricTier: TimeInterval],
        demand: MonitoringDemand
    ) -> Set<MetricTier> {
        let tolerance = tickInterval(for: demand) * 0.1
        var due: Set<MetricTier> = []
        for tier in MetricTier.allCases {
            guard let interval = interval(for: tier, demand: demand) else { continue }
            guard let last = lastRun[tier] else {
                due.insert(tier)
                continue
            }
            if now - last + tolerance >= interval { due.insert(tier) }
        }
        return due
    }
}
