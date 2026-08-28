import Foundation
import AppKit

/// High-performance scanner for installed macOS applications.
/// Features concurrent batch inspection and direct Mach-O header parsing (MachOArchitectureDetector).
public actor AppScannerService {
    public static let shared = AppScannerService()
    
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    
    public init() {}
    
    /// Scans all application directories and returns a list of InstalledApp models concurrently
    public func scanApplications(progressHandler: (@Sendable (String, Double) -> Void)? = nil) async -> [InstalledApp] {
        var appURLs: [URL] = []
        
        let searchDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            homeDirectory.appendingPathComponent("Applications")
        ]
        
        for dir in searchDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            for item in contents where item.pathExtension == "app" {
                if !appURLs.contains(item) {
                    appURLs.append(item)
                }
            }
        }
        
        var installedApps: [InstalledApp] = []
        let total = Double(appURLs.count)
        
        // Concurrent batch scanning with TaskGroup
        let chunkSize = 12
        var processedCount = 0
        
        var index = 0
        while index < appURLs.count {
            let endIndex = min(index + chunkSize, appURLs.count)
            let chunk = Array(appURLs[index..<endIndex])
            
            await withTaskGroup(of: InstalledApp?.self) { group in
                for url in chunk {
                    group.addTask {
                        await self.inspectApp(at: url)
                    }
                }
                
                for await app in group {
                    if let validApp = app {
                        installedApps.append(validApp)
                    }
                    processedCount += 1
                    let progress = Double(processedCount) / max(1.0, total)
                    progressHandler?(app?.name ?? "Taranıyor...", progress)
                }
            }
            
            index = endIndex
        }
        
        progressHandler?("Tamamlandı", 1.0)
        
        // Sort user apps first, then alphabetically
        return installedApps.sorted {
            if $0.isSystemApp != $1.isSystemApp {
                return !$0.isSystemApp && $1.isSystemApp
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    /// Inspects a single .app bundle using direct Mach-O header parsing
    public func inspectApp(at url: URL) async -> InstalledApp? {
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        guard fileManager.fileExists(atPath: infoPlistURL.path),
              let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        
        let bundleName = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        
        let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown.\(bundleName)"
        let version = plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String ?? "1.0"
        let buildNumber = plist["CFBundleVersion"] as? String ?? "1"
        let minOS = plist["LSMinimumSystemVersion"] as? String ?? ""
        let isSystemApp = SafetyGuard.isProtectedSystemApp(path: url.path, bundleIdentifier: bundleId)
        
        // Ultra-fast architecture detection via direct binary header reading
        let arch = detectArchitecture(for: url, plist: plist)
        
        // Calculate size
        let sizeBytes = await JunkCleanerService.shared.calculateSize(at: url)
        
        // Last modified date
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        
        return InstalledApp(
            name: bundleName,
            bundleIdentifier: bundleId,
            path: url.path,
            version: version,
            buildNumber: buildNumber,
            minOSVersion: minOS,
            architecture: arch,
            sizeBytes: sizeBytes,
            isSystemApp: isSystemApp,
            lastModifiedDate: modDate
        )
    }
    
    /// Detects binary architecture directly from Mach-O headers without spawning external processes
    private func detectArchitecture(for appURL: URL, plist: [String: Any]) -> AppArchitecture {
        let execName = plist["CFBundleExecutable"] as? String ?? appURL.deletingPathExtension().lastPathComponent
        let execURL = appURL.appendingPathComponent("Contents/MacOS").appendingPathComponent(execName)
        
        guard fileManager.fileExists(atPath: execURL.path) else {
            return .unknown
        }
        
        return MachOArchitectureDetector.detect(at: execURL)
    }
}
