import SwiftUI
import Charts

/// Responsive live observability card rendering CPU and RAM performance charts.
///
/// The sample history lives in `LiveMetricsStore.chartHistory` (a fixed-capacity ring buffer), so it
/// survives navigation, never grows, and is not rebuilt with synthetic points on every appearance.
public struct TelemetryHistoryCard: View {
    @ObservedObject var metrics: LiveMetricsStore
    @State private var selectedMetric: MetricType = .both
    
    private var samples: RingBuffer<TelemetryChartSample> { metrics.chartHistory }
    
    enum MetricType: String, CaseIterable, Identifiable {
        case both = "Tümü"
        case cpu = "İşlemci (CPU)"
        case ram = "Bellek (RAM)"
        
        var id: String { rawValue }
    }
    
    public var body: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                // Header & Filter (stacks vertically when the window is too narrow)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        titleLabel
                        Spacer()
                        metricPicker
                            .frame(minWidth: 200, idealWidth: 240, maxWidth: 280)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        titleLabel
                        metricPicker
                    }
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
                    ContentUnavailableView("Henüz telemetri örneği yok", systemImage: "chart.xyaxis.line", description: Text("Grafik, gerçek CPU ve bellek örnekleri geldikçe görüntülenecek."))
                    .frame(height: 140)
                }
                
                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("CPU: %\(String(format: "%.1f", metrics.cpuStats.totalUsage))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("RAM: %\(Int(metrics.memoryStats.usedPercentage * 100)) (\(ByteFormatter.formatMemory(metrics.memoryStats.actualUsedBytes)))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    Text("Son \(LiveMetricsStore.chartHistoryCapacity) Örnek (Canlı Darwin API)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var titleLabel: some View {
        Label("Canlı Telemetri & Performans Grafiği", systemImage: "chart.xyaxis.line")
            .font(.system(size: 14, weight: .bold))
            .lineLimit(1)
    }
    
    private var metricPicker: some View {
        Picker("", selection: $selectedMetric) {
            ForEach(MetricType.allCases) { metric in
                Text(metric.rawValue).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
