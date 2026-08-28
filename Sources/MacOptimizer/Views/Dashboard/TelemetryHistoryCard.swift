import SwiftUI
import Charts

/// Telemetry history sample for Swift Charts visualization.
public struct TelemetryChartSample: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let cpuUsage: Double
    public let ramPercentage: Double
    
    public init(timestamp: Date = Date(), cpuUsage: Double, ramPercentage: Double) {
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.ramPercentage = ramPercentage
    }
}

/// Responsive live observability card rendering CPU and RAM performance charts.
public struct TelemetryHistoryCard: View {
    @ObservedObject var appState: AppState
    @State private var samples: [TelemetryChartSample] = []
    @State private var selectedMetric: MetricType = .both
    
    enum MetricType: String, CaseIterable, Identifiable {
        case both = "Tümü"
        case cpu = "İşlemci (CPU)"
        case ram = "Bellek (RAM)"
        
        var id: String { rawValue }
    }
    
    public var body: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                // Header & Filter
                HStack {
                    Label("Canlı Telemetri & Performans Grafiği", systemImage: "chart.xyaxis.line")
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                    
                    Picker("", selection: $selectedMetric) {
                        ForEach(MetricType.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                
                // Chart Container
                if samples.count >= 2 {
                    Chart {
                        if selectedMetric == .both || selectedMetric == .cpu {
                            ForEach(samples) { sample in
                                LineMark(
                                    x: .value("Zaman", sample.timestamp),
                                    y: .value("CPU %", sample.cpuUsage),
                                    series: .value("Metrik", "CPU")
                                )
                                .foregroundStyle(Color.orange)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Zaman", sample.timestamp),
                                    y: .value("CPU %", sample.cpuUsage),
                                    series: .value("Metrik", "CPU")
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.25), Color.orange.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        
                        if selectedMetric == .both || selectedMetric == .ram {
                            ForEach(samples) { sample in
                                LineMark(
                                    x: .value("Zaman", sample.timestamp),
                                    y: .value("RAM %", sample.ramPercentage * 100.0),
                                    series: .value("Metrik", "RAM")
                                )
                                .foregroundStyle(Color.blue)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Zaman", sample.timestamp),
                                    y: .value("RAM %", sample.ramPercentage * 100.0),
                                    series: .value("Metrik", "RAM")
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour().minute().second())
                                .font(.system(size: 9))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel {
                                if let intVal = value.as(Int.self) {
                                    Text("%\(intVal)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 140)
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Telemetri verileri toplanıyor...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .frame(height: 140)
                }
                
                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("CPU: %\(String(format: "%.1f", appState.cpuStats.totalUsage))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("RAM: %\(Int(appState.memoryStats.usedPercentage * 100)) (\(ByteFormatter.formatMemory(appState.memoryStats.actualUsedBytes)))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    Text("Son 60 Saniye (Canlı Darwin API)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            seedInitialSamples()
        }
        .onChange(of: appState.cpuStats.totalUsage) { _, _ in
            appendLiveSample()
        }
    }
    
    private func seedInitialSamples() {
        let now = Date()
        var initSamples: [TelemetryChartSample] = []
        for i in (0..<10).reversed() {
            let time = now.addingTimeInterval(-Double(i * 3))
            initSamples.append(TelemetryChartSample(
                timestamp: time,
                cpuUsage: appState.cpuStats.totalUsage,
                ramPercentage: appState.memoryStats.usedPercentage
            ))
        }
        self.samples = initSamples
    }
    
    private func appendLiveSample() {
        let newSample = TelemetryChartSample(
            timestamp: Date(),
            cpuUsage: appState.cpuStats.totalUsage,
            ramPercentage: appState.memoryStats.usedPercentage
        )
        samples.append(newSample)
        if samples.count > 30 {
            samples.removeFirst()
        }
    }
}
