import SwiftUI

/// Quick view of top resource-consuming processes on the dashboard
public struct TopProcessesCard: View {
    let processes: [ProcessInfoModel]
    let onKill: (Int32) -> Void
    let onNavigateToMemory: () -> Void
    
    public var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L10n.string("Top Memory Consumers", table: .dashboard), systemImage: "flame.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(L10n.string("View All →", table: .dashboard)) {
                        onNavigateToMemory()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                }
                
                if processes.isEmpty {
                    Text(l10n: "Scanning processes...", table: .dashboard)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(processes.prefix(5)) { proc in
                            HStack(spacing: 10) {
                                Image(systemName: proc.isUserApp ? "app.badge.fill" : "gearshape.2.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(proc.isUserApp ? .blue : .secondary)
                                    .frame(width: 24, height: 24)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(proc.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    
                                    Text(L10n.string("PID: %lld", table: .dashboard, Int64(proc.pid)))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(proc.cpuFormatted)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.orange)
                                    .frame(width: 55, alignment: .trailing)
                                
                                Text(proc.memoryFormatted)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(width: 80, alignment: .trailing)
                                
                                if proc.isProtected {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(.secondary.opacity(0.4))
                                        .font(.system(size: 13))
                                        .help(L10n.string("Protected macOS system process (cannot be terminated)", table: .dashboard))
                                } else {
                                    Button {
                                        onKill(proc.pid)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red.opacity(0.7))
                                            .font(.system(size: 15))
                                    }
                                    .buttonStyle(.plain)
                                    .help(L10n.string("Terminate process (PID: %lld)", table: .dashboard, Int64(proc.pid)))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}
