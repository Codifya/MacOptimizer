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
                title: Text(l10n: "Delete Duplicate Files", table: .cleanup),
                message: Text(L10n.string("%lld selected duplicate files will be moved to the Trash. Original files will be kept. Do you confirm?", table: .cleanup, Int64(selectedDuplicatesCount))),
                primaryButton: .destructive(Text(l10n: "Move to Trash", table: .cleanup)) {
                    appState.cleanDuplicates()
                },
                secondaryButton: .cancel(Text(L10n.string("Cancel", table: .cleanup)))
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
                        Text(l10n: "Duplicate File Finder", table: .cleanup)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                        
                        Text(l10n: "Find copy files with the same content (SHA-256) and free up gigabytes on your disk.", table: .cleanup)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer(minLength: 12)
                    
                    ActionButton(
                        title: appState.isScanningDuplicates ? L10n.string("Scanning...", table: .cleanup) : L10n.string("Scan for Duplicates", table: .cleanup),
                        iconName: "magnifyingglass",
                        gradient: SystemTheme.junkGradient,
                        isLoading: appState.isScanningDuplicates
                    ) {
                        appState.scanDuplicates(targets: Array(selectedTargets))
                    }
                }
                
                // Target Folders Filter Chips
                HStack(spacing: 8) {
                    Text(l10n: "Folders to Scan:", table: .cleanup)
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
                                Text(verbatim: target.localizedTitle)
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
                    .truncationMode(.middle)
                
                Button(L10n.string("Cancel the Scan", table: .cleanup)) {
                    appState.cancelDuplicateScan()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.red)
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
                        Text(l10n: "Total Space to be Reclaimed:", table: .cleanup)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(ByteFormatter.format(totalRecoverableBytes))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                    }
                    
                    Spacer()
                    
                    ActionButton(
                        title: appState.isCleaningDuplicates ? L10n.string("Cleaning...", table: .cleanup) : L10n.string("Move Selected Copies to Trash (%lld Files)", table: .cleanup, Int64(selectedDuplicatesCount)),
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
                
                Text(L10n.string("%lld Duplicate Files", table: .cleanup, Int64(group.wrappedValue.duplicates.count)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Original File (Preserved)
            HStack(spacing: 8) {
                MetricBadge(text: L10n.string("Original (Kept)", table: .cleanup), colorName: "green")
                
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
                .help(L10n.string("Show in Finder", table: .cleanup))
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
                    
                    MetricBadge(text: L10n.string("Copy", table: .cleanup), colorName: "purple")
                    
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
                
                Text(appState.duplicateStatusMessage.isEmpty ? L10n.string("Duplicate File Scan Not Run", table: .cleanup) : appState.duplicateStatusMessage)
                    .font(.system(size: 16, weight: .bold))
                
                Text(l10n: "Start a scan to detect files with identical content in your Downloads, Documents, and Pictures folders.", table: .cleanup)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                
                ActionButton(
                    title: L10n.string("Start Scan", table: .cleanup),
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
