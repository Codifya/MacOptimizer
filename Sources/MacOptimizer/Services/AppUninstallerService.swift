import Foundation

/// Service for discovering and cleanly removing all associated files and leftovers when uninstalling an application.
/// Strictly guarded by SafetyGuard to prevent accidental deletion of system directories or other apps.
public actor AppUninstallerService {
    public static let shared = AppUninstallerService()
    
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    
    public struct AppFileItem: Identifiable, Sendable, Equatable {
        public let id: String
        public let path: String
        public let name: String
        public let locationName: String
        public let sizeBytes: Int64
        public var isSelected: Bool
        public let isMainApp: Bool
        
        public var sizeFormatted: String {
            ByteFormatter.format(sizeBytes)
        }
    }
    
    public init() {}
    
    /// Finds all associated files, caches, preferences, containers, and logs for an application
    public func findAssociatedFiles(for app: InstalledApp) async -> [AppFileItem] {
        var items: [AppFileItem] = []
        
        // Safety Check: Never allow uninstalling core macOS system apps
        guard !SafetyGuard.isProtectedSystemApp(path: app.path, bundleIdentifier: app.bundleIdentifier) else {
            return []
        }
        
        // 1. Main .app bundle
        if SafetyGuard.isSafeToClean(path: app.path) {
            let mainAppSize = await JunkCleanerService.shared.calculateSize(at: URL(fileURLWithPath: app.path))
            items.append(AppFileItem(
                id: app.path,
                path: app.path,
                name: "\(app.name).app",
                locationName: "Uygulama Paketi (Ana Dosya)",
                sizeBytes: mainAppSize,
                isSelected: true,
                isMainApp: true
            ))
        }
        
        let bundleId = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let appName = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate identifier lengths to prevent parent directory matching
        let validBundleId = bundleId.count >= 4 && bundleId.contains(".") && !bundleId.hasPrefix("com.apple.")
        let validAppName = appName.count >= 2 && !SafetyGuard.essentialAppSupportFolders.contains(appName.lowercased())
        
        var targetLocations: [(subpath: String, label: String)] = []
        
        if validBundleId {
            targetLocations.append(("Library/Application Support/\(bundleId)", "Application Support"))
            targetLocations.append(("Library/Caches/\(bundleId)", "Önbellek (Caches)"))
            targetLocations.append(("Library/Preferences/\(bundleId).plist", "Tercihler (Preferences)"))
            targetLocations.append(("Library/Saved Application State/\(bundleId).savedState", "Kayıtlı Uygulama Durumu"))
            targetLocations.append(("Library/Containers/\(bundleId)", "Uygulama Sandbox Kapsayıcısı"))
            targetLocations.append(("Library/WebKit/\(bundleId)", "WebKit Verileri"))
            targetLocations.append(("Library/HTTPStorages/\(bundleId)", "HTTP Depolama"))
            targetLocations.append(("Library/Logs/\(bundleId)", "Uygulama Günlükleri"))
            targetLocations.append(("Library/LaunchAgents/\(bundleId).plist", "Başlangıç Servisi (LaunchAgent)"))
        }
        
        if validAppName {
            targetLocations.append(("Library/Application Support/\(appName)", "Application Support"))
            targetLocations.append(("Library/Caches/\(appName)", "Önbellek (Caches)"))
            targetLocations.append(("Library/Logs/\(appName)", "Uygulama Günlükleri"))
        }
        
        for loc in targetLocations {
            let targetURL = homeDirectory.appendingPathComponent(loc.subpath)
            if fileManager.fileExists(atPath: targetURL.path) && SafetyGuard.isSafeToClean(path: targetURL.path) {
                let size = await JunkCleanerService.shared.calculateSize(at: targetURL)
                if !items.contains(where: { $0.path == targetURL.path }) {
                    items.append(AppFileItem(
                        id: targetURL.path,
                        path: targetURL.path,
                        name: targetURL.lastPathComponent,
                        locationName: loc.label,
                        sizeBytes: size,
                        isSelected: true,
                        isMainApp: false
                    ))
                }
            }
        }
        
        // Group containers search with strict matching
        if validBundleId {
            let groupContainersURL = homeDirectory.appendingPathComponent("Library/Group Containers")
            if let groupDirs = try? fileManager.contentsOfDirectory(at: groupContainersURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for dir in groupDirs {
                    let dirName = dir.lastPathComponent.lowercased()
                    if dirName == bundleId.lowercased() ||
                       dirName.hasSuffix(".\(bundleId.lowercased())") ||
                       (validAppName && appName.count >= 4 && dirName.contains(appName.lowercased()) && !dirName.hasPrefix("com.apple.")) {
                        if SafetyGuard.isSafeToClean(path: dir.path) {
                            let size = await JunkCleanerService.shared.calculateSize(at: dir)
                            if !items.contains(where: { $0.path == dir.path }) {
                                items.append(AppFileItem(
                                    id: dir.path,
                                    path: dir.path,
                                    name: dir.lastPathComponent,
                                    locationName: "Grup Kapsayıcısı (Group Container)",
                                    sizeBytes: size,
                                    isSelected: true,
                                    isMainApp: false
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    /// Uninstalls and removes selected files safely using SafeOperationExecutor
    public func uninstall(files: [AppFileItem]) async -> (freedBytes: Int64, deletedCount: Int, failedCount: Int) {
        var totalFreed: Int64 = 0
        var deleted = 0
        var failed = 0
        
        for file in files where file.isSelected {
            let url = URL(fileURLWithPath: file.path)
            do {
                let result = try SafeOperationExecutor.removeFile(at: url, moveToTrash: true)
                if result.success {
                    totalFreed += (result.bytesFreed > 0 ? result.bytesFreed : file.sizeBytes)
                    deleted += 1
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }
        
        return (totalFreed, deleted, failed)
    }
}
