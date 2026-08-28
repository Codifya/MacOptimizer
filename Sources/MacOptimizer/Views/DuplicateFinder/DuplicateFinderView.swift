import SwiftUI
import AppKit

/// View for identifying and removing duplicate files with SHA-256 verification and Zero-Harm safety.
public struct DuplicateFinderView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTargets: Set<DuplicateFileFinderService.ScanTargetDirectory> = [.downloads, .documents]
    @State private var showConfirmDelete = false
    
    private var totalRecoverableBytes: Int64 {
        appState.duplicateGroups.reduce(0) { $0 + $1.totalWastedBytes }
    }
    
    private var selectedDuplicatesCount: Int {
        appState.duplicateGroups.reduce(0) { $0 + $1.duplicates.filter { $0.isSelectedForDeletion }.count }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Hero
            duplicateHeaderHero
            
            if appState.isScanningDuplicates {
                scanningProgressCard
            } else if appState.duplicateGroups.isEmpty {
                emptyDuplicatesCard
            } else {
                duplicateResultsList
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .alert(isPresented: $showConfirmDelete) {
            Alert(
                title: Text("Yinelenen Dosyaları Sil"),
                message: Text("Seçili \(selectedDuplicatesCount) adet kopya dosya Çöp Sepetine taşınacaktır. Orijinal dosyalar korunacaktır. Onaylıyor musunuz?"),
                primaryButton: .destructive(Text("Çöp Kutusuna Taşı")) {
                    appState.cleanDuplicates()
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }
    
    // MARK: - Header Hero
    private var duplicateHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Yinelenen Dosya Bulucu")
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        Text("Aynı içeriğe (SHA-256) sahip kopya dosyaları bularak diskinizde gigabaytlarca yer açın.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer(minLength: 12)
                    
                    ActionButton(
                        title: appState.isScanningDuplicates ? "Taranıyor..." : "Yinelenenleri Tara",
                        iconName: "magnifyingglass",
                        gradient: SystemTheme.junkGradient,
                        isLoading: appState.isScanningDuplicates
                    ) {
                        appState.scanDuplicates(targets: Array(selectedTargets))
                    }
                }
                
                // Target Folders Filter Chips
                HStack(spacing: 8) {
                    Text("Taranacak Dizinler:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(DuplicateFileFinderService.ScanTargetDirectory.allCases) { target in
                        Button {
                            if selectedTargets.contains(target) {
                                if selectedTargets.count > 1 {
                                    selectedTargets.remove(target)
                                }
                            } else {
                                selectedTargets.insert(target)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: selectedTargets.contains(target) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 10))
                                Text(target.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedTargets.contains(target) ? Color.purple.opacity(0.15) : Color.secondary.opacity(0.08))
                            .foregroundColor(selectedTargets.contains(target) ? .purple : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Scanning Progress Card
    private var scanningProgressCard: some View {
        GlassCard(cornerRadius: 16, padding: 32) {
            VStack(spacing: 14) {
                ProgressView(value: appState.duplicateScanProgress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 450)
                
                Text(appState.duplicateStatusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Results List
    private var duplicateResultsList: some View {
        VStack(spacing: 12) {
            GlassCard(cornerRadius: 16, padding: 12) {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach($appState.duplicateGroups) { $group in
                            duplicateGroupCard(group: $group)
                        }
                    }
                    .padding(4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Bottom Action Bar
            GlassCard(cornerRadius: 14, padding: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kazanılacak Toplam Alan:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(ByteFormatter.format(totalRecoverableBytes))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                    }
                    
                    Spacer()
                    
                    ActionButton(
                        title: appState.isCleaningDuplicates ? "Temizleniyor..." : "Seçilen Kopyaları Çöpe Taşı (\(selectedDuplicatesCount) Dosya)",
                        iconName: "trash.fill",
                        gradient: SystemTheme.dangerGradient,
                        isLoading: appState.isCleaningDuplicates
                    ) {
                        showConfirmDelete = true
                    }
                    .disabled(selectedDuplicatesCount == 0 || appState.isCleaningDuplicates)
                }
            }
        }
    }
    
    // MARK: - Single Group Card
    private func duplicateGroupCard(group: Binding<DuplicateFileGroup>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.blue)
                    Text(group.wrappedValue.original.name)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    
                    MetricBadge(text: ByteFormatter.format(group.wrappedValue.sizePerFile), colorName: "blue")
                }
                
                Spacer()
                
                Text("\(group.wrappedValue.duplicates.count) Kopya Dosya")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Original File (Preserved)
            HStack(spacing: 8) {
                MetricBadge(text: "Orijinal (Korunuyor)", colorName: "green")
                
                Text(group.wrappedValue.original.path)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    NSWorkspace.shared.selectFile(group.wrappedValue.original.path, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Finder'da Göster")
            }
            .padding(6)
            .background(Color.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Duplicate Copies
            ForEach(group.duplicates) { $dup in
                HStack(spacing: 8) {
                    Button {
                        dup.isSelectedForDeletion.toggle()
                    } label: {
                        Image(systemName: dup.isSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(dup.isSelectedForDeletion ? .purple : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    MetricBadge(text: "Kopya", colorName: "purple")
                    
                    Text(dup.path)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button {
                        NSWorkspace.shared.selectFile(dup.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(Color.secondary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Empty Card
    private var emptyDuplicatesCard: some View {
        GlassCard(cornerRadius: 16, padding: 36) {
            VStack(spacing: 14) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 44))
                    .foregroundStyle(SystemTheme.junkGradient)
                
                Text(appState.duplicateStatusMessage.isEmpty ? "Yinelenen Dosya Taraması Yapılmadı" : appState.duplicateStatusMessage)
                    .font(.system(size: 16, weight: .bold))
                
                Text("İndirilenler, Belgeler ve Resimler klasörlerindeki aynı içerikli dosyaları tespit etmek için taramayı başlatın.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                
                ActionButton(
                    title: "Taramayı Başlat",
                    iconName: "magnifyingglass",
                    gradient: SystemTheme.junkGradient
                ) {
                    appState.scanDuplicates(targets: Array(selectedTargets))
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
