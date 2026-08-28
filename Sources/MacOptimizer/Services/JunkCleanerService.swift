import Foundation

/// Comprehensive scanner and cleaner for macOS junk files, logs, caches, and developer build leftovers.
/// Features parallel multi-category scanning, dry-run CleaningPlan generation, and strict Zero-Harm policy validation.
public actor JunkCleanerService {
    public static let shared = JunkCleanerService()
    
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    
    public init() {}
    
    // MARK: - Dry-Run CleaningPlan Generation
    public func generateCleaningPlan(from groups: [JunkCategoryGroup]) -> CleaningPlan {
        var plannedItems: [CleanableItemPlan] = []
        var warnings: [String] = []
        
        for group in groups {
            for item in group.items {
                let canonicalPath = URL(fileURLWithPath: item.path).resolvingSymlinksInPath().standardizedFileURL.path
                let risk = OperationRiskClassifier.classifyFileRemoval(path: canonicalPath)
                
                // Never add forbidden paths into the plan
                if risk == .forbidden {
                    warnings.append("Korumalı dosya plana eklenmedi: \(item.name)")
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
            
            let url = URL(fileURLWithPath: item.path)
            do {
                let result = try SafeOperationExecutor.removeFile(at: url, moveToTrash: item.category == .appLeftovers || item.category == .largeFiles)
                if result.success {
                    totalFreed += (result.bytesFreed > 0 ? result.bytesFreed : item.sizeBytes)
                    cleanedCount += 1
                } else {
                    failedCount += 1
                    errors.append(result.message)
                }
            } catch {
                failedCount += 1
                errors.append("\(item.name): \(error.localizedDescription)")
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        progressHandler?("Temizlik Tamamlandı", 1.0)
        
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
        
        progressHandler?("Gereksiz dosyalar taranıyor...", 0.1)
        
        var categoryResults: [JunkCategoryType: [JunkFileItem]] = [:]
        
        await withTaskGroup(of: (JunkCategoryType, [JunkFileItem]).self) { group in
            for cat in categories {
                group.addTask {
                    let items = await self.scanCategory(cat)
                    return (cat, items)
                }
            }
            
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
        
        progressHandler?("Tarama Tamamlandı", 1.0)
        return groups
    }
    
    // MARK: - Scan Individual Category
    public func scanCategory(_ category: JunkCategoryType) async -> [JunkFileItem] {
        switch category {
        case .systemCache:
            return scanUserCaches()
        case .systemLogs:
            return scanSystemLogs()
        case .developerCache:
            return scanDeveloperCaches()
        case .browserCache:
            return scanBrowserCaches()
        case .trashBin:
            return scanTrashBin()
        case .largeFiles:
            return scanLargeFiles(minSizeBytes: 100 * 1024 * 1024)
        case .appLeftovers:
            return await scanAppLeftovers()
        }
    }
    
    // MARK: - User & System Caches
    private func scanUserCaches() -> [JunkFileItem] {
        let cachesURL = homeDirectory.appendingPathComponent("Library/Caches")
        return scanSubdirectories(in: cachesURL, category: .systemCache)
    }
    
    // MARK: - System & App Logs
    private func scanSystemLogs() -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        
        let userLogsURL = homeDirectory.appendingPathComponent("Library/Logs")
        items.append(contentsOf: scanSubdirectories(in: userLogsURL, category: .systemLogs))
        
        let crashReporterURL = homeDirectory.appendingPathComponent("Library/Logs/DiagnosticReports")
        if fileManager.fileExists(atPath: crashReporterURL.path) && PathProtectionPolicy.isCleanableCachePath(crashReporterURL.path) {
            let size = calculateSize(at: crashReporterURL)
            if size > 0 {
                items.append(JunkFileItem(
                    path: crashReporterURL.path,
                    name: "Sistem Çökme & Tanı Raporları",
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
    private func scanDeveloperCaches() -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        
        let devTargets: [(path: String, name: String, desc: String)] = [
            ("Library/Developer/Xcode/DerivedData", "Xcode DerivedData", "Derleme ve indeks önbellekleri"),
            ("Library/Developer/Xcode/Archives", "Xcode Arşivleri", "Eski uygulama derleme arşivleri"),
            ("Library/Developer/Xcode/iOS DeviceSupport", "iOS Device Support", "Eski iOS cihaz sembolleri"),
            ("Library/Developer/Xcode/watchOS DeviceSupport", "watchOS Device Support", "Eski watchOS cihaz sembolleri"),
            ("Library/Developer/CoreSimulator/Caches", "Simülatör Önbellekleri", "iOS Simülatör geçici dosyaları"),
            (".npm/_cacache", "NPM Önbelleği", "Node Package Manager önbelleği"),
            (".yarn/cache", "Yarn Önbelleği", "Yarn paket önbelleği"),
            (".pnpm-store", "pnpm Store", "pnpm global paket havuzu"),
            (".cargo/registry/cache", "Rust Cargo Önbelleği", "Cargo crates önbellek dosyaları"),
            ("Library/Caches/CocoaPods", "CocoaPods Önbelleği", "iOS Pods indirme önbellekleri"),
            (".gradle/caches", "Gradle Önbelleği", "Android ve Java derleme önbellekleri"),
            (".cache/pip", "Python pip Önbelleği", "Python paket indirme önbellekleri")
        ]
        
        for target in devTargets {
            let url = homeDirectory.appendingPathComponent(target.path)
            if fileManager.fileExists(atPath: url.path) && PathProtectionPolicy.isCleanableCachePath(url.path) {
                let size = calculateSize(at: url)
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
    private func scanBrowserCaches() -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        
        let browserPaths: [(path: String, name: String)] = [
            ("Library/Caches/com.apple.Safari", "Safari Web Önbelleği"),
            ("Library/Containers/com.apple.Safari/Data/Library/Caches", "Safari Container Önbelleği"),
            ("Library/Caches/Google/Chrome", "Google Chrome Önbelleği"),
            ("Library/Caches/company.thebrowser.Browser", "Arc Tarayıcı Önbelleği"),
            ("Library/Caches/BraveSoftware/Brave-Browser", "Brave Tarayıcı Önbelleği"),
            ("Library/Caches/com.microsoft.edgemac", "Microsoft Edge Önbelleği"),
            ("Library/Caches/Firefox", "Mozilla Firefox Önbelleği")
        ]
        
        for browser in browserPaths {
            let url = homeDirectory.appendingPathComponent(browser.path)
            if fileManager.fileExists(atPath: url.path) && PathProtectionPolicy.isCleanableCachePath(url.path) {
                let size = calculateSize(at: url)
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
    private func scanTrashBin() -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        let trashURL = homeDirectory.appendingPathComponent(".Trash")
        
        guard let contents = try? fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for url in contents {
            let size = calculateSize(at: url)
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            
            items.append(JunkFileItem(
                path: url.path,
                name: url.lastPathComponent,
                sizeBytes: size,
                category: .trashBin,
                isSelected: true,
                detail: "Çöp Sepetinde",
                lastModifiedDate: modDate
            ))
        }
        
        return items
    }
    
    // MARK: - Large & Old Files
    public func scanLargeFiles(minSizeBytes: Int64 = 100 * 1024 * 1024) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        let scanFolders = ["Downloads", "Documents", "Movies", "Music"]
        
        for folder in scanFolders {
            let dirURL = homeDirectory.appendingPathComponent(folder)
            guard let enumerator = fileManager.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
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
                        detail: "\(folder) / \(fileURL.pathExtension.uppercased()) Dosyası",
                        lastModifiedDate: values.contentModificationDate
                    ))
                }
            }
        }
        
        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }
    
    // MARK: - App Leftovers (Safe Orphan Directory Scanner)
    private func scanAppLeftovers() async -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        
        // 1. Gather all installed bundle identifiers & app names
        var installedNames: Set<String> = []
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
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
            for dir in appSupportDirs {
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
                    let size = calculateSize(at: dir)
                    if size > 15 * 1024 * 1024 { // Only include notable items > 15 MB
                        items.append(JunkFileItem(
                            path: dir.path,
                            name: dir.lastPathComponent,
                            sizeBytes: size,
                            category: .appLeftovers,
                            isSelected: false,
                            detail: "Silinmiş uygulama kalıntısı (Application Support)"
                        ))
                    }
                }
            }
        }
        
        return items
    }
    
    // MARK: - Legacy Cleaning Execution (Backwards compatibility)
    public func cleanItems(_ items: [JunkFileItem], progressHandler: (@Sendable (String, Double) -> Void)? = nil) async -> (freedBytes: Int64, deletedCount: Int, failedCount: Int) {
        var totalFreed: Int64 = 0
        var deleted = 0
        var failed = 0
        let totalItems = Double(items.count)
        
        for (index, item) in items.enumerated() {
            let progress = Double(index) / max(1.0, totalItems)
            progressHandler?(item.name, progress)
            
            let url = URL(fileURLWithPath: item.path)
            
            do {
                let res = try SafeOperationExecutor.removeFile(at: url, moveToTrash: item.category == .appLeftovers || item.category == .largeFiles)
                if res.success {
                    totalFreed += (res.bytesFreed > 0 ? res.bytesFreed : item.sizeBytes)
                    deleted += 1
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }
        
        progressHandler?("Temizlik Tamamlandı", 1.0)
        return (totalFreed, deleted, failed)
    }
    
    // MARK: - Optimized Directory Sizing
    private func scanSubdirectories(in folderURL: URL, category: JunkCategoryType) -> [JunkFileItem] {
        var items: [JunkFileItem] = []
        guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for url in contents {
            guard PathProtectionPolicy.isCleanableCachePath(url.path) else { continue }
            
            let size = calculateSize(at: url)
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
    
    public func calculateSize(at url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        
        if !isDir.boolValue {
            if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? NSNumber {
                return size.int64Value
            }
            return 0
        }
        
        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true,
               let fileSize = values.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
}
