import Foundation

/// Comprehensive scanner and cleaner for macOS junk files, logs, caches, and developer build leftovers.
/// Features parallel multi-category scanning, dry-run CleaningPlan generation, and strict Zero-Harm policy validation.
///
/// Stateless and `Sendable`: every filesystem operation runs through `runBlocking` on a GCD queue.
/// This used to be an actor, which serialised the "parallel" category TaskGroup onto one executor,
/// parked a cooperative-pool thread for the whole scan, and made every other caller (app scanner,
/// uninstaller, smart optimisation) queue behind a running scan. Scans are now truly parallel and
/// cancellable.
public final class JunkCleanerService: Sendable {
    public static let shared = JunkCleanerService()
    
    private var fileManager: FileManager { FileManager.default }
    private let homeDirectory: URL
    private let rootDirectory: URL
    
    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        rootDirectory: URL = URL(fileURLWithPath: "/")
    ) {
        self.homeDirectory = homeDirectory
        self.rootDirectory = rootDirectory
    }
    
    // MARK: - Dry-Run CleaningPlan Generation
    public func generateCleaningPlan(from groups: [JunkCategoryGroup]) async -> CleaningPlan {
        await runBlocking(qos: .userInitiated) { _ in Self.buildCleaningPlan(from: groups, homeDirectory: self.homeDirectory) }
    }
    
    private static func buildCleaningPlan(from groups: [JunkCategoryGroup], homeDirectory: URL) -> CleaningPlan {
        var plannedItems: [CleanableItemPlan] = []
        var warnings: [String] = []
        
        for group in groups {
            for item in group.items {
                if item.category == .trashBin {
                    warnings.append(L10n.string("Trash must be emptied separately with explicit confirmation: %@", table: .services, item.name))
                    continue
                }
                let canonicalPath = URL(fileURLWithPath: item.path).resolvingSymlinksInPath().standardizedFileURL.path
                let risk = OperationRiskClassifier.classifyFileRemoval(path: canonicalPath, homeDirectory: homeDirectory)
                
                // Never add forbidden paths into the plan
                if risk == .forbidden {
                    warnings.append(L10n.string("Protected file was not added to the plan: %@", table: .services, item.name))
                    continue
                }
                
                plannedItems.append(CleanableItemPlan(
                    id: item.id,
                    path: canonicalPath,
                    name: item.name,
                    category: item.category,
                    sizeBytes: item.sizeBytes,
                    risk: risk,
                    isSelected: item.isSelected
                ))
            }
        }
        
        let plan = CleaningPlan(
            items: plannedItems,
            warnings: warnings
        )
        
        return plan
    }
    
    // MARK: - Plan Execution with SafeOperationExecutor
    public func executeCleaningPlan(
        _ plan: CleaningPlan,
        confirmation: SafeOperationExecutor.Confirmation,
        progressHandler: (@Sendable (String, Double) -> Void)? = nil
    ) async -> CleaningExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalFreed: Int64 = 0
        var cleanedCount = 0
        var failedCount = 0
        var errors: [String] = []
        
        let selectedItems = plan.items.filter { $0.isSelected }
        let totalCount = Double(selectedItems.count)
        
        for (idx, item) in selectedItems.enumerated() {
            let progress = Double(idx) / max(1.0, totalCount)
            progressHandler?(item.name, progress)
            
            let outcome = await Self.remove(path: item.path, confirmation: confirmation)
            switch outcome {
            case .success(let result) where result.success:
                totalFreed += (result.bytesFreed > 0 ? result.bytesFreed : item.sizeBytes)
                cleanedCount += 1
            case .success(let result):
                failedCount += 1
                errors.append(result.message)
            case .failure(let error):
                failedCount += 1
                errors.append("\(item.name): \(error.localizedDescription)")
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        progressHandler?(L10n.string("Cleanup Complete", table: .services), 1.0)
        
        return CleaningExecutionResult(
            planId: plan.id,
            totalFreedBytes: totalFreed,
            cleanedItemCount: cleanedCount,
            failedItemCount: failedCount,
            errors: errors,
            durationSeconds: duration
        )
    }
    
    // MARK: - Parallel Scan All Junk Categories
    public func scanAll(progressHandler: (@Sendable (String, Double) -> Void)? = nil) async -> [JunkCategoryGroup] {
        let categories: [JunkCategoryType] = [
            .systemCache,
            .systemLogs,
            .developerCache,
            .browserCache,
            .trashBin,
            .largeFiles,
            .appLeftovers
        ]
        
        progressHandler?(L10n.string("Scanning junk files...", table: .services), 0.1)
        
        var categoryResults: [JunkCategoryType: [JunkFileItem]] = [:]
        
        await withTaskGroup(of: (JunkCategoryType, [JunkFileItem]).self) { group in
            for cat in categories {
                group.addTask {
                    let items = await self.scanCategory(cat)
                    return (cat, items)
                }
            }
            // Child tasks inherit cancellation from the caller; each category's runBlocking
            // forwards it to the directory walk, so a cancelled scan stops within one pool slice.
            
            var completedCount = 0
            for await (cat, items) in group {
                categoryResults[cat] = items
                completedCount += 1
                let progress = Double(completedCount) / Double(categories.count)
                progressHandler?(cat.title, progress)
            }
        }
        
        // Assemble in original display order
        var groups: [JunkCategoryGroup] = []
        for cat in categories {
            let items = categoryResults[cat] ?? []
            groups.append(JunkCategoryGroup(type: cat, items: items))
        }
        
        progressHandler?(L10n.string("Scan Complete", table: .services), 1.0)
        return groups
    }
    
    // MARK: - Scan Individual Category
    public func scanCategory(_ category: JunkCategoryType) async -> [JunkFileItem] {
        await runBlocking { [self] flag in
            switch category {
            case .systemCache:
                return scanUserCaches(flag)
            case .systemLogs:
                return scanSystemLogs(flag)
            case .developerCache:
                return scanDeveloperCaches(flag)
            case .browserCache:
                return scanBrowserCaches(flag)
            case .trashBin:
                return scanTrashBin(flag)
            case .largeFiles:
                return scanLargeFiles(minSizeBytes: 100 * 1024 * 1024, flag)
            case .appLeftovers:
                return scanAppLeftovers(flag)
            }
        }
    }
    
    /// Removes one item off the cooperative pool (trashing or deleting large trees can take seconds).
    private static func remove(path: String, confirmation: SafeOperationExecutor.Confirmation) async -> Result<OperationExecutionResult, Error> {
        await runBlocking(qos: .userInitiated) { _ in
            Result { try SafeOperationExecutor.removeFile(at: URL(fileURLWithPath: path), moveToTrash: true, confirmation: confirmation) }
        }
    }
    
    // MARK: - User & System Caches
    private func scanUserCaches(_ flag: CancellationFlag) -> [JunkFileItem] {
        let cachesURL = homeDirectory.appendingPathComponent("Library/Caches")
        return scanSubdirectories(in: cachesURL, category: .systemCache, flag)
    }
    
    // MARK: - System & App Logs
    private func scanSystemLogs(_ flag: CancellationFlag) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        
        let userLogsURL = homeDirectory.appendingPathComponent("Library/Logs")
        items.append(contentsOf: scanSubdirectories(in: userLogsURL, category: .systemLogs, flag))
        
        let crashReporterURL = homeDirectory.appendingPathComponent("Library/Logs/DiagnosticReports")
        if fileManager.fileExists(atPath: crashReporterURL.path) && PathProtectionPolicy.isCleanableCachePath(crashReporterURL.path, homeDirectory: homeDirectory) {
            let size = FileSizeCalculator.size(of: crashReporterURL, cancellation: flag)
            if size > 0 {
                items.append(JunkFileItem(
                    path: crashReporterURL.path,
                    name: L10n.string("System Crash & Diagnostic Reports", table: .services),
                    sizeBytes: size,
                    category: .systemLogs,
                    isSelected: true,
                    detail: crashReporterURL.path
                ))
            }
        }
        
        return items
    }
    
    // MARK: - Developer Build & Tool Caches
    private func scanDeveloperCaches(_ flag: CancellationFlag) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        
        let devTargets: [(path: String, name: String, desc: String)] = [
            ("Library/Developer/Xcode/DerivedData", "Xcode DerivedData", L10n.string("Build and index caches", table: .services)),
            ("Library/Developer/Xcode/Archives", L10n.string("Xcode Archives", table: .services), L10n.string("Old app build archives", table: .services)),
            ("Library/Developer/Xcode/iOS DeviceSupport", "iOS Device Support", L10n.string("Old iOS device symbols", table: .services)),
            ("Library/Developer/Xcode/watchOS DeviceSupport", "watchOS Device Support", L10n.string("Old watchOS device symbols", table: .services)),
            ("Library/Developer/CoreSimulator/Caches", L10n.string("Simulator Caches", table: .services), L10n.string("iOS Simulator temporary files", table: .services)),
            (".npm/_cacache", L10n.string("NPM Cache", table: .services), L10n.string("Node Package Manager cache", table: .services)),
            (".yarn/cache", L10n.string("Yarn Cache", table: .services), L10n.string("Yarn package cache", table: .services)),
            (".pnpm-store", "pnpm Store", L10n.string("pnpm global package store", table: .services)),
            (".cargo/registry/cache", L10n.string("Rust Cargo Cache", table: .services), L10n.string("Cargo crate cache files", table: .services)),
            ("Library/Caches/CocoaPods", L10n.string("CocoaPods Cache", table: .services), L10n.string("iOS Pods download caches", table: .services)),
            (".gradle/caches", L10n.string("Gradle Cache", table: .services), L10n.string("Android and Java build caches", table: .services)),
            (".cache/pip", L10n.string("Python pip Cache", table: .services), L10n.string("Python package download caches", table: .services)),
            ("Library/Caches/Homebrew", L10n.string("Homebrew Download Cache", table: .services), L10n.string("Downloaded formulae and bottle packages", table: .services)),
            ("Library/Caches/uv", L10n.string("Python UV Cache", table: .services), L10n.string("UV package manager cache", table: .services)),
            ("Library/Caches/pypoetry", L10n.string("Python Poetry Cache", table: .services), L10n.string("Poetry virtual environments and package store", table: .services))
        ]
        
        for target in devTargets where !flag.isCancelled {
            let url = homeDirectory.appendingPathComponent(target.path)
            if fileManager.fileExists(atPath: url.path) && PathProtectionPolicy.isCleanableCachePath(url.path, homeDirectory: homeDirectory) {
                let size = FileSizeCalculator.size(of: url, cancellation: flag)
                if size > 0 {
                    items.append(JunkFileItem(
                        path: url.path,
                        name: target.name,
                        sizeBytes: size,
                        category: .developerCache,
                        isSelected: true,
                        detail: target.desc
                    ))
                }
            }
        }
        
        return items
    }
    
    // MARK: - Browser Caches
    private func scanBrowserCaches(_ flag: CancellationFlag) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        
        let browserPaths: [(path: String, name: String)] = [
            ("Library/Caches/com.apple.Safari", L10n.string("Safari Web Cache", table: .services)),
            ("Library/Containers/com.apple.Safari/Data/Library/Caches", L10n.string("Safari Container Cache", table: .services)),
            ("Library/Caches/Google/Chrome", L10n.string("Google Chrome Cache", table: .services)),
            ("Library/Caches/company.thebrowser.Browser", L10n.string("Arc Browser Cache", table: .services)),
            ("Library/Caches/BraveSoftware/Brave-Browser", L10n.string("Brave Browser Cache", table: .services)),
            ("Library/Caches/com.microsoft.edgemac", L10n.string("Microsoft Edge Cache", table: .services)),
            ("Library/Caches/Firefox", L10n.string("Mozilla Firefox Cache", table: .services))
        ]
        
        for browser in browserPaths where !flag.isCancelled {
            let url = homeDirectory.appendingPathComponent(browser.path)
            if fileManager.fileExists(atPath: url.path) && PathProtectionPolicy.isCleanableCachePath(url.path, homeDirectory: homeDirectory) {
                let size = FileSizeCalculator.size(of: url, cancellation: flag)
                if size > 0 {
                    items.append(JunkFileItem(
                        path: url.path,
                        name: browser.name,
                        sizeBytes: size,
                        category: .browserCache,
                        isSelected: true,
                        detail: url.path
                    ))
                }
            }
        }
        
        return items
    }
    
    // MARK: - Trash Bin
    private func scanTrashBin(_ flag: CancellationFlag) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        let trashURL = homeDirectory.appendingPathComponent(".Trash")
        
        guard let contents = try? fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for url in contents where !flag.isCancelled {
            let size = FileSizeCalculator.size(of: url, cancellation: flag)
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            
            items.append(JunkFileItem(
                path: url.path,
                name: url.lastPathComponent,
                sizeBytes: size,
                category: .trashBin,
                isSelected: false,
                detail: L10n.string("In Trash", table: .services),
                lastModifiedDate: modDate
            ))
        }
        
        return items
    }
    
    // MARK: - Large & Old Files
    private func scanLargeFiles(minSizeBytes: Int64, _ flag: CancellationFlag) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        let scanFolders = ["Downloads", "Documents", "Movies", "Music"]
        
        for folder in scanFolders where !flag.isCancelled {
            let dirURL = homeDirectory.appendingPathComponent(folder)
            guard let enumerator = fileManager.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }
            
            var exhausted = false
            while !exhausted && !flag.isCancelled {
                autoreleasepool {
                    for _ in 0..<FileSizeCalculator.entriesPerPool {
                        guard let fileURL = enumerator.nextObject() as? URL else {
                            exhausted = true
                            return
                        }
                        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey]),
                              values.isRegularFile == true,
                              let size = values.fileSize,
                              Int64(size) >= minSizeBytes else {
                            continue
                        }
                        
                        if SafetyPolicyEngine.canDelete(path: fileURL.path) {
                            items.append(JunkFileItem(
                                path: fileURL.path,
                                name: fileURL.lastPathComponent,
                                sizeBytes: Int64(size),
                                category: .largeFiles,
                                isSelected: false,
                                detail: L10n.string("%@ / %@ File", table: .services, folder, fileURL.pathExtension.uppercased()),
                                lastModifiedDate: values.contentModificationDate
                            ))
                        }
                    }
                }
            }
        }
        
        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }
    
    // MARK: - App Leftovers (Safe Orphan Directory Scanner)
    private func scanAppLeftovers(_ flag: CancellationFlag) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        
        // 1. Gather all installed bundle identifiers & app names
        var installedNames: Set<String> = []
        let appDirs = [
            rootDirectory.appendingPathComponent("Applications"),
            rootDirectory.appendingPathComponent("System/Applications"),
            homeDirectory.appendingPathComponent("Applications")
        ]
        
        for appDir in appDirs {
            guard let apps = try? fileManager.contentsOfDirectory(at: appDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            for app in apps where app.pathExtension == "app" {
                let name = app.deletingPathExtension().lastPathComponent.lowercased()
                installedNames.insert(name)
                
                let plistURL = app.appendingPathComponent("Contents/Info.plist")
                if let data = try? Data(contentsOf: plistURL),
                   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                    if let bundleId = plist["CFBundleIdentifier"] as? String {
                        installedNames.insert(bundleId.lowercased())
                    }
                    if let bundleName = plist["CFBundleName"] as? String {
                        installedNames.insert(bundleName.lowercased())
                    }
                    if let dispName = plist["CFBundleDisplayName"] as? String {
                        installedNames.insert(dispName.lowercased())
                    }
                }
            }
        }
        
        // 2. Safely inspect ~/Library/Application Support
        let appSupportURL = homeDirectory.appendingPathComponent("Library/Application Support")
        if let appSupportDirs = try? fileManager.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for dir in appSupportDirs where !flag.isCancelled {
                let dirName = dir.lastPathComponent.lowercased()
                
                // Never flag essential tools or system directories
                if SafetyGuard.essentialAppSupportFolders.contains(dirName) || dirName.hasPrefix("com.apple.") {
                    continue
                }
                
                guard PathProtectionPolicy.isCleanableCachePath(dir.path) || dir.path.contains("/Application Support/") else {
                    continue
                }
                
                // Extra safety: only consider orphan if dirName is at least 3 chars
                guard dirName.count >= 3 else { continue }
                
                let isInstalled = installedNames.contains { name in
                    name == dirName || (dirName.count >= 4 && name.contains(dirName))
                }
                
                if !isInstalled {
                    let size = FileSizeCalculator.size(of: dir, cancellation: flag)
                    if size > 15 * 1024 * 1024 { // Only include notable items > 15 MB
                        items.append(JunkFileItem(
                            path: dir.path,
                            name: dir.lastPathComponent,
                            sizeBytes: size,
                            category: .appLeftovers,
                            isSelected: false,
                            detail: L10n.string("Deleted app leftover (Application Support)", table: .services)
                        ))
                    }
                }
            }
        }
        
        return items
    }
    
    // MARK: - Optimized Directory Sizing
    private func scanSubdirectories(in folderURL: URL, category: JunkCategoryType, _ flag: CancellationFlag) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for url in contents {
            if flag.isCancelled { break }
            guard PathProtectionPolicy.isCleanableCachePath(url.path, homeDirectory: homeDirectory) else { continue }
            
            let size = FileSizeCalculator.size(of: url, cancellation: flag)
            if size > 1024 * 1024 { // Only include items > 1MB
                items.append(JunkFileItem(
                    path: url.path,
                    name: url.lastPathComponent,
                    sizeBytes: size,
                    category: category,
                    isSelected: true,
                    detail: url.path
                ))
            }
        }
        
        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }
    
    /// Kept for API compatibility; prefer `FileSizeCalculator` directly.
    public func calculateSize(at url: URL) async -> Int64 {
        await FileSizeCalculator.measure(url)
    }
}
