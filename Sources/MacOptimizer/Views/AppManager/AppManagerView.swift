import SwiftUI

/// Complete Installed Applications manager with architecture filters, search, and uninstaller.
/// Fully responsive across compact, standard, and wide macOS window sizes.
public struct AppManagerView: View {
    @ObservedObject var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedFilter: AppFilter = .all
    @State private var sortOption: AppSortOption = .size
    @State private var appToUninstall: InstalledApp?
    
    enum AppFilter: String, CaseIterable, Identifiable {
        case all = "Tümü"
        case userOnly = "Kullanıcı"
        case appleSilicon = "Apple Silicon"
        case universal = "Universal"
        case intel = "Intel (x86)"
        case updates = "Güncellemeler"
        
        var id: String { rawValue }
    }
    
    enum AppSortOption: String, CaseIterable, Identifiable {
        case size = "Boyuta Göre"
        case name = "İsme Göre"
        
        var id: String { rawValue }
    }
    
    private var filteredApps: [InstalledApp] {
        var list = appState.installedApps.filter { app in
            let matchesSearch = searchText.isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .userOnly:
                matchesFilter = !app.isSystemApp
            case .appleSilicon:
                matchesFilter = app.architecture == .appleSilicon
            case .universal:
                matchesFilter = app.architecture == .universal
            case .intel:
                matchesFilter = app.architecture == .intel
            case .updates:
                matchesFilter = app.updateInfo.hasUpdate
            }
            
            return matchesSearch && matchesFilter
        }
        
        switch sortOption {
        case .size:
            list.sort { $0.sizeBytes > $1.sizeBytes }
        case .name:
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        
        return list
    }
    
    private var totalAppsSize: Int64 {
        appState.installedApps.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Hero
            appManagerHeaderHero
            
            // Responsive Toolbar (Search, Filter, Sort)
            appToolbar
            
            // App List
            if appState.installedApps.isEmpty && !appState.isScanningApps {
                emptyAppsView
            } else {
                appsListView
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .sheet(item: $appToUninstall) { app in
            AppUninstallerDetailView(
                appState: appState,
                app: app,
                onDismiss: {
                    appToUninstall = nil
                }
            )
        }
    }
    
    // MARK: - Header Hero
    private var appManagerHeaderHero: some View {
        GlassCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Yüklü Uygulamalar & Kaldırıcı")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    
                    if !appState.installedApps.isEmpty {
                        Text("\(appState.installedApps.count) uygulama tespit edildi • Toplam: \(ByteFormatter.format(totalAppsSize))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Mac'inizde kurulu tüm uygulamaları, mimarilerini ve boyutlarını inceleyin.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if appState.isScanningApps {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.appStatusMessage)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                            
                            AnimatedProgressBar(progress: appState.appScanProgress, gradient: SystemTheme.primaryGradient, height: 5)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer(minLength: 12)
                
                HStack(spacing: 8) {
                    ActionButton(
                        title: appState.isScanningApps ? "Taranıyor..." : "Uygulamaları Tara",
                        iconName: "arrow.clockwise",
                        gradient: SystemTheme.primaryGradient,
                        isLoading: appState.isScanningApps
                    ) {
                        appState.scanApps()
                    }
                    
                    ActionButton(
                        title: appState.isCheckingUpdates ? "Denetleniyor..." : "Güncellemeleri Bul",
                        iconName: "arrow.triangle.2.circlepath",
                        gradient: SystemTheme.updateGradient,
                        isLoading: appState.isCheckingUpdates
                    ) {
                        appState.checkAllAppUpdates()
                    }
                }
            }
        }
    }
    
    // MARK: - Responsive Toolbar
    private var appToolbar: some View {
        ViewThatFits(in: .horizontal) {
            // Wide Toolbar: Single Row
            HStack(spacing: 12) {
                searchField
                    .frame(width: 220)
                
                Spacer()
                
                filterSegmentedPicker
                    .frame(maxWidth: 420)
                
                sortPicker
                    .frame(width: 125)
            }
            
            // Compact Toolbar: Two Rows
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    searchField
                        .frame(maxWidth: .infinity)
                    
                    sortPicker
                        .frame(width: 125)
                }
                
                filterSegmentedPicker
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            TextField("Uygulama adı veya Bundle ID ara...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var filterSegmentedPicker: some View {
        Picker("Filtrele", selection: $selectedFilter) {
            ForEach(AppFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var sortPicker: some View {
        Picker("Sırala", selection: $sortOption) {
            ForEach(AppSortOption.allCases) { opt in
                Text(opt.rawValue).tag(opt)
            }
        }
        .pickerStyle(.menu)
    }
    
    // MARK: - App List
    private var appsListView: some View {
        GlassCard(cornerRadius: 16, padding: 10) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredApps) { app in
                        AppRowView(
                            app: app,
                            onInspectUninstall: {
                                appState.loadAppFilesForUninstall(app: app)
                                appToUninstall = app
                            },
                            onUpdate: {
                                if !app.updateInfo.downloadURL.isEmpty, let url = URL(string: app.updateInfo.downloadURL) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Empty State
    private var emptyAppsView: some View {
        GlassCard(cornerRadius: 16, padding: 36) {
            VStack(spacing: 16) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(SystemTheme.primaryGradient)
                
                Text("Uygulamalar Taranmadı")
                    .font(.system(size: 16, weight: .bold))
                
                Text("Kurulu olan uygulamaları listelemek ve güncelleme kontrolü yapmak için taramayı başlatın.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                ActionButton(
                    title: "Uygulamaları Tara",
                    iconName: "magnifyingglass",
                    gradient: SystemTheme.primaryGradient
                ) {
                    appState.scanApps()
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
