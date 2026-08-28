import SwiftUI

/// Card displaying deep IOKit battery health, temperature, cycle counts, and power state.
public struct BatteryAnalyticsCard: View {
    let stats: BatteryStats
    
    public var body: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: stats.isCharging ? "bolt.batteryblock.fill" : "battery.100")
                            .font(.system(size: 16))
                            .foregroundColor(stats.isCharging ? .green : .blue)
                        
                        Text("Pil Sağlığı & Güç Telemetrisi")
                            .font(.system(size: 13, weight: .bold))
                    }
                    
                    Spacer()
                    
                    MetricBadge(
                        text: stats.powerSource,
                        colorName: stats.isCharging ? "green" : "blue"
                    )
                }
                
                // Main Metrics Grid
                HStack(spacing: 16) {
                    // Battery Level Mini Gauge
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                                .frame(width: 52, height: 52)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(stats.percentage) / 100.0)
                                .stroke(
                                    stats.percentage > 20 ? Color.green : Color.red,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 52, height: 52)
                            
                            Text("%\(stats.percentage)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        
                        Text(stats.timeRemainingFormatted)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 75)
                    
                    Divider()
                    
                    // Detailed Diagnostics
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Maksimum Kapasite:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("%\(stats.healthPercentage)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(stats.healthPercentage >= 80 ? .green : .orange)
                        }
                        
                        HStack {
                            Text("Pil Döngü Sayısı:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(stats.cycleCount) Döngü")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Pil Sıcaklığı:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Text(String(format: "%.1f °C", stats.temperatureCelsius))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(stats.isOverheating ? .red : .primary)
                                
                                if stats.isOverheating {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        HStack {
                            Text("Durum:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            MetricBadge(text: stats.condition, colorName: stats.condition == "Normal" ? "green" : "orange")
                        }
                    }
                }
            }
        }
    }
}
