import SwiftUI
import Charts

/// View displaying optimization reports and SQLite historical telemetry trends over 1h, 24h, and 48h.
/// Fully responsive across all macOS window dimensions.
public struct HistoryView: View {
    @ObservedObject var appState: AppState
    @State private var timeRangeHours: Int = 24
    @State private var historyPoints: [TelemetryHistoryPoint] = []
    @State private var isLoadingHistory: Bool = false
    
    private var totalFreedRAM: UInt64 {
        appState.optimizationHistory.reduce(0) { $0 + $1.freedMemoryBytes }
    }
    
    private var totalFreedDisk: Int64 {
        appState.optimizationHistory.reduce(0) { $0 + $1.freedDiskBytes }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Summary Hero
                historyHeaderHero
                
                // Historical Telemetry SQLite Chart Card
                telemetryHistoricalTrendCard
                
                // History List
                if appState.optimizationHistory.isEmpty {
                    emptyHistoryView
                } else {
                    historyListView
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .onAppear {
            loadTelemetryHistory()
        }
    }
    
    // MARK: - Header Hero
    private var historyHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Optimizasyon Geçmişi & SQLite Telemetri")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Text("Toplam Kazanılan RAM: \(ByteFormatter.formatMemory(totalFreedRAM))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text("Toplam Kazanılan Disk: \(ByteFormatter.format(totalFreedDisk))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kazanılan RAM: \(ByteFormatter.formatMemory(totalFreedRAM))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                            Text("Kazanılan Disk: \(ByteFormatter.format(totalFreedDisk))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                Spacer(minLength: 12)
                
                if !appState.optimizationHistory.isEmpty {
                    Button("Geçmişi Temizle") {
                        appState.clearHistory()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    // MARK: - SQLite Historical Telemetry Chart
    private var telemetryHistoricalTrendCard: some View {
        GlassCard(cornerRadius: 16, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Sistem Performans Geçmişi (SQLite)", systemImage: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                    
                    Picker("Zaman Aralığı", selection: $timeRangeHours) {
                        Text("Son 1 Saat").tag(1)
                        Text("Son 24 Saat").tag(24)
                        Text("Son 48 Saat").tag(48)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    .onChange(of: timeRangeHours) { _, _ in
                        loadTelemetryHistory()
                    }
                }
                
                if !historyPoints.isEmpty {
                    Chart {
                        ForEach(historyPoints) { point in
                            LineMark(
                                x: .value("Zaman", point.timestamp),
                                y: .value("CPU %", point.cpuUsage),
                                series: .value("Metrik", "CPU")
                            )
                            .foregroundStyle(Color.orange)
                            .interpolationMethod(.catmullRom)
                            
                            LineMark(
                                x: .value("Zaman", point.timestamp),
                                y: .value("RAM %", appState.memoryStats.totalBytes > 0 ? (Double(point.ramUsedBytes) / Double(appState.memoryStats.totalBytes)) * 100.0 : 0.0),
                                series: .value("Metrik", "RAM")
                            )
                            .foregroundStyle(Color.blue)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel(format: .dateTime.hour().minute())
                                .font(.system(size: 9))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                                .foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel {
                                if let intVal = val.as(Int.self) {
                                    Text("%\(intVal)").font(.system(size: 9)).foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 150)
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "circle.dotted")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("Bu zaman aralığında yeterli SQLite telemetri kaydı bulunamadı.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .frame(height: 120)
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("CPU Kullanımı").font(.system(size: 11, weight: .semibold))
                    }
                    
                    HStack(spacing: 6) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("RAM Kullanımı").font(.system(size: 11, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    Text("\(historyPoints.count) Veri Noktası (SQLite WAL)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - List
    private var historyListView: some View {
        VStack(spacing: 8) {
            ForEach(appState.optimizationHistory) { report in
                GlassCard(cornerRadius: 12, padding: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.title)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            
                            if let detail = report.details.first {
                                Text(detail)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer(minLength: 8)
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            if report.freedMemoryBytes > 0 {
                                Text("+\(report.freedMemoryFormatted) RAM")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            if report.freedDiskBytes > 0 {
                                Text("+\(report.freedDiskFormatted) Disk")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            Text(report.formattedDate)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty
    private var emptyHistoryView: some View {
        GlassCard(cornerRadius: 16, padding: 36) {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text("Henüz Optimizasyon Kaydı Yok")
                    .font(.system(size: 15, weight: .semibold))
                
                Text("Yaptığınız RAM boşaltma ve dosya temizleme işlemleri burada listelenecektir.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func loadTelemetryHistory() {
        Task {
            let points = await TelemetryStore.shared.fetchHistory(hours: timeRangeHours, maxPoints: 50)
            await MainActor.run {
                self.historyPoints = points
            }
        }
    }
}
