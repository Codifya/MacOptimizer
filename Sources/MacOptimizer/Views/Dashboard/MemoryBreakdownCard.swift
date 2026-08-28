import SwiftUI

/// Visual segmented breakdown of macOS RAM (Active, Wired, Compressed, Inactive, Free)
public struct MemoryBreakdownCard: View {
    let stats: MemoryStats
    
    private var total: Double {
        max(1.0, Double(stats.totalBytes))
    }
    
    private var activeRatio: Double { Double(stats.activeBytes) / total }
    private var wiredRatio: Double { Double(stats.wiredBytes) / total }
    private var compressedRatio: Double { Double(stats.compressedBytes) / total }
    private var inactiveRatio: Double { Double(stats.inactiveBytes) / total }
    private var freeRatio: Double { Double(stats.freeBytes) / total }
    
    public var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Bellek Dağılımı", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 15, weight: .bold))
                    
                    Spacer()
                    
                    Text("Toplam: \(ByteFormatter.formatMemory(stats.totalBytes))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Multi-Segmented Stacked Bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        // Active (Blue)
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: max(0, geo.size.width * CGFloat(activeRatio)))
                        
                        // Wired (Purple)
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: max(0, geo.size.width * CGFloat(wiredRatio)))
                        
                        // Compressed (Orange)
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: max(0, geo.size.width * CGFloat(compressedRatio)))
                        
                        // Inactive (Teal)
                        Rectangle()
                            .fill(Color.teal)
                            .frame(width: max(0, geo.size.width * CGFloat(inactiveRatio)))
                        
                        // Free (Green)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: max(0, geo.size.width * CGFloat(freeRatio)))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .frame(height: 14)
                
                // Legend (Responsive Adaptive Columns)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    LegendItem(color: .blue, label: "Aktif", value: ByteFormatter.formatMemory(stats.activeBytes))
                    LegendItem(color: .purple, label: "Kablolu (Wired)", value: ByteFormatter.formatMemory(stats.wiredBytes))
                    LegendItem(color: .orange, label: "Sıkıştırılmış", value: ByteFormatter.formatMemory(stats.compressedBytes))
                    LegendItem(color: .teal, label: "Pasif (Önbellek)", value: ByteFormatter.formatMemory(stats.inactiveBytes))
                    LegendItem(color: .green, label: "Tamamen Boş", value: ByteFormatter.formatMemory(stats.freeBytes))
                    LegendItem(color: .indigo, label: "Kullanılabilir", value: ByteFormatter.formatMemory(stats.freeAndInactiveBytes))
                }
            }
        }
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
    }
}
