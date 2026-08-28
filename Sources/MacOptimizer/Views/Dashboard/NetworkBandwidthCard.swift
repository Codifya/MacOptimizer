import SwiftUI

/// Card displaying real-time network throughput, active interface, and IP configuration.
public struct NetworkBandwidthCard: View {
    let stats: NetworkStats
    
    public var body: some View {
        GlassCard(cornerRadius: 16, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.system(size: 16))
                            .foregroundColor(.cyan)
                        
                        Text("Ağ Hızı & Bant Genişliği")
                            .font(.system(size: 13, weight: .bold))
                    }
                    
                    Spacer()
                    
                    MetricBadge(
                        text: "\(stats.activeInterfaceName) • \(stats.localIPAddress)",
                        colorName: "cyan"
                    )
                }
                
                // Throughput Metrics
                HStack(spacing: 16) {
                    // Download Gauge
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("İndirme (Download)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Text(stats.downloadSpeedFormatted)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Upload Gauge
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Yükleme (Upload)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Text(stats.uploadSpeedFormatted)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                
                // Session Counters
                HStack {
                    HStack(spacing: 4) {
                        Text("Toplam İndirilen:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(ByteFormatter.format(Int64(stats.totalDownloadBytes)))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Toplam Gönderilen:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(ByteFormatter.format(Int64(stats.totalUploadBytes)))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                }
            }
        }
    }
}
