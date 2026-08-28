import SwiftUI

/// View displaying the history of cleanings, RAM purges, and disk gains.
/// Fully responsive across all macOS window dimensions.
public struct HistoryView: View {
    @ObservedObject var appState: AppState
    
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
                    Text("Optimizasyon Geçmişi & Raporlar")
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
}
