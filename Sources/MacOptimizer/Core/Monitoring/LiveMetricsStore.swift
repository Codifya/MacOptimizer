import Foundation
import Combine

/// One point on the dashboard's live chart.
public struct TelemetryChartSample: Identifiable, Sendable, Equatable {
    /// Monotonic sequence number — stable identity for SwiftUI/Charts (no per-sample UUID allocation).
    public let id: Int
    public let timestamp: Date
    public let cpuUsage: Double
    public let ramPercentage: Double

    public init(id: Int, timestamp: Date = Date(), cpuUsage: Double, ramPercentage: Double) {
        self.id = id
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.ramPercentage = ramPercentage
    }
}

/// High-frequency live metrics, isolated from `AppState`.
///
/// Previously these were `@Published` on `AppState`, so every 2.5 s tick invalidated *every* view that
/// observed `AppState` (settings, app list, junk cleaner, sidebar …) — including views that never show
/// a metric. Only views that render metrics observe this store now, and values are assigned only when
/// they actually changed, so an unchanged disk or battery reading publishes nothing.
@MainActor
public final class LiveMetricsStore: ObservableObject {
    /// 30 samples ≈ 75 s at the visible 2.5 s cadence — exactly what the dashboard chart renders.
    public static let chartHistoryCapacity = 30

    @Published public private(set) var memoryStats = MemoryStats()
    @Published public private(set) var cpuStats = CPUStats()
    @Published public private(set) var diskStats = DiskStats()
    @Published public private(set) var batteryStats = BatteryStats()
    @Published public private(set) var networkStats = NetworkStats()
    @Published public private(set) var hardwareInfo = HardwareInfo()
    @Published public private(set) var runningProcesses: [ProcessInfoModel] = []
    @Published public private(set) var chartHistory = RingBuffer<TelemetryChartSample>(capacity: chartHistoryCapacity)

    private var nextSampleID = 0

    public init() {}

    public func apply(_ sample: MetricsSample) {
        if let memory = sample.memory { assignIfChanged(\.memoryStats, memory) }
        if let cpu = sample.cpu { assignIfChanged(\.cpuStats, cpu) }
        if let network = sample.network { assignIfChanged(\.networkStats, network) }
        if let disk = sample.disk { assignIfChanged(\.diskStats, disk) }
        if let battery = sample.battery { assignIfChanged(\.batteryStats, battery) }
        if let hardware = sample.hardware { assignIfChanged(\.hardwareInfo, hardware) }
        if let processes = sample.processes { assignIfChanged(\.runningProcesses, processes) }

        if let memory = sample.memory, let cpu = sample.cpu {
            nextSampleID += 1
            chartHistory.append(TelemetryChartSample(
                id: nextSampleID,
                cpuUsage: cpu.totalUsage,
                ramPercentage: memory.usedPercentage
            ))
        }
    }

    /// Optimistic local removal after a successful kill, before the next process sample arrives.
    public func removeProcess(pid: Int32) {
        runningProcesses.removeAll { $0.pid == pid }
    }

    private func assignIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<LiveMetricsStore, T>, _ value: T) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
