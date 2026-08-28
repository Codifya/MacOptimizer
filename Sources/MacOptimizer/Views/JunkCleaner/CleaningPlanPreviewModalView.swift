import SwiftUI

/// Modal sheet displaying the Dry-Run CleaningPlan, risk breakdown, warnings, and item list before execution.
public struct CleaningPlanPreviewModalView: View {
    @ObservedObject var appState: AppState
    let plan: CleaningPlan
    let onDismiss: () -> Void
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Risk Summary Banner
                    riskSummaryBanner
                    
                    // Zero-Harm Shield Notice
                    zeroHarmNotice
                    
                    // Warnings Box (if any)
                    if !plan.warnings.isEmpty {
                        warningsBox
                    }
                    
                    // Planned Items List
                    plannedItemsSection
                }
                .padding(20)
            }
            
            Divider()
            
            // Bottom Action Footer
            footerBar
        }
        .frame(minWidth: 520, idealWidth: 600, maxWidth: 720, minHeight: 460, idealHeight: 560, maxHeight: 680)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Temizlik Planı & Risk Önizlemesi (Dry-Run)")
                        .font(.system(size: 15, weight: .bold))
                    Text("Disk üzerinde değişiklik yapılmadan önce oluşturulan güvenlik planı.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Risk Summary Banner
    private var riskSummaryBanner: some View {
        GlassCard(cornerRadius: 12, padding: 14) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kazanılacak Alan:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.format(plan.selectedEstimatedBytes))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Divider()
                    .frame(height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Temizlenecek Öğe:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(plan.selectedCount) Adet")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Divider()
                    .frame(height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maksimum Risk:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(riskColor(plan.maxRiskLevel))
                            .frame(width: 8, height: 8)
                        Text(plan.maxRiskLevel.displayName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(riskColor(plan.maxRiskLevel))
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Zero-Harm Notice
    private var zeroHarmNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Zero-Harm Savunma Kalkanı Aktif")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Text("Kök sistem dosyaları, kişisel belgeleriniz ve kritik macOS servisleri kesinlikle korunmaktadır. Önbellek dışı dosyalar Çöp Sepeti korumalı olarak taşınır.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Warnings Box
    private var warningsBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Plan Uyarıları", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.orange)
            
            ForEach(plan.warnings, id: \.self) { warning in
                Text("• \(warning)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Planned Items Section
    private var plannedItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Temizlenecek Dosya ve Klasörler:")
                .font(.system(size: 13, weight: .bold))
            
            VStack(spacing: 6) {
                ForEach(plan.items.filter { $0.isSelected }) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.category.iconName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Text(item.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)
                        
                        Text(item.risk.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(riskColor(item.risk).opacity(0.12))
                            .foregroundColor(riskColor(item.risk))
                            .clipShape(Capsule())
                        
                        Text(item.sizeFormatted)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    // MARK: - Footer
    private var footerBar: some View {
        HStack {
            Button("Vazgeç") {
                onDismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            ActionButton(
                title: "Planı Onayla ve Temizle (\(ByteFormatter.format(plan.selectedEstimatedBytes)))",
                iconName: "trash.fill",
                gradient: SystemTheme.junkGradient,
                isLoading: appState.isCleaningJunk
            ) {
                onDismiss()
                appState.executeActiveCleaningPlan()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.secondary.opacity(0.04))
    }
    
    private func riskColor(_ risk: OperationRisk) -> Color {
        switch risk {
        case .safe: return .blue
        case .low: return .green
        case .medium: return .orange
        case .destructive: return .red
        case .forbidden: return .purple
        }
    }
}
