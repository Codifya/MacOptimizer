import Foundation

/// Service for checking software updates for installed macOS applications via Sparkle Appcasts, Homebrew Casks, and App Store
public actor AppUpdateCheckerService {
    public static let shared = AppUpdateCheckerService()
    
    private let urlSession: URLSession
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Checks all installed apps for updates concurrently
    public func checkUpdates(for apps: [InstalledApp], progressHandler: (@Sendable (String, Double) -> Void)? = nil) async -> [InstalledApp] {
        var updatedApps: [InstalledApp] = []
        let total = Double(apps.count)
        
        let brewOutdatedMap = await fetchHomebrewOutdatedCasks()
        let chunkSize = 5
        var index = 0
        
        while index < apps.count {
            let endIndex = Swift.min(index + chunkSize, apps.count)
            let chunk = Array(apps[index..<endIndex])
            
            await withTaskGroup(of: InstalledApp.self) { group in
                for app in chunk {
                    group.addTask {
                        var mutableApp = app
                        
                        let appKey = app.name.lowercased().replacingOccurrences(of: " ", with: "-")
                        if let brewInfo = brewOutdatedMap[appKey] ?? brewOutdatedMap[app.bundleIdentifier.lowercased()] {
                            mutableApp.updateInfo.hasUpdate = true
                            mutableApp.updateInfo.latestVersion = brewInfo.latestVersion
                            mutableApp.updateInfo.updateSource = .homebrew
                            mutableApp.updateInfo.downloadURL = "brew upgrade --cask \(brewInfo.name)"
                            return mutableApp
                        }
                        
                        if let sparkleUpdate = await self.checkSparkleFeed(for: app) {
                            mutableApp.updateInfo = sparkleUpdate
                            return mutableApp
                        }
                        
                        if let directUpdate = await self.checkDirectAppUpdate(for: app) {
                            mutableApp.updateInfo = directUpdate
                            return mutableApp
                        }
                        
                        return mutableApp
                    }
                }
                
                for await result in group {
                    updatedApps.append(result)
                }
            }
            
            index = endIndex
            let progress = Double(index) / Swift.max(1.0, total)
            progressHandler?("\(index)/\(apps.count) Uygulama Kontrol Edildi", progress)
        }
        
        progressHandler?("Güncelleme Kontrolü Tamamlandı", 1.0)
        return updatedApps
    }
    
    /// Checks a single app's Sparkle feed
    public func checkSparkleFeed(for app: InstalledApp) async -> AppUpdateInfo? {
        let appURL = URL(fileURLWithPath: app.path)
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let feedURLString = plist["SUFeedURL"] as? String ?? plist["SUFeedURLString"] as? String,
              let feedURL = URL(string: feedURLString) else {
            return nil
        }
        
        do {
            var request = URLRequest(url: feedURL)
            request.setValue("MacOptimizer/1.0", forHTTPHeaderField: "User-Agent")
            
            let (feedData, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            let items = AppcastParser.parse(data: feedData)
            guard let latest = items.first else { return nil }
            
            let remoteVer = !latest.shortVersion.isEmpty ? latest.shortVersion : latest.version
            guard !remoteVer.isEmpty else { return nil }
            
            let isNewer = VersionComparator.isNewer(remoteVersion: remoteVer, than: app.version)
            
            if isNewer {
                var update = AppUpdateInfo()
                update.hasUpdate = true
                update.latestVersion = remoteVer
                update.downloadURL = latest.downloadURL
                update.releaseNotesURL = latest.releaseNotesURL
                update.updateSource = .sparkle
                return update
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    /// Checks Homebrew Cask outdated list
    private func fetchHomebrewOutdatedCasks() async -> [String: (name: String, latestVersion: String)] {
        var map: [String: (name: String, latestVersion: String)] = [:]
        
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        var brewPath: String?
        for path in brewPaths {
            if FileManager.default.fileExists(atPath: path) {
                brewPath = path
                break
            }
        }
        
        guard let brew = brewPath else { return map }
        
        let result = await SystemCommandRunner.run(executable: brew, arguments: ["outdated", "--cask", "--json=v2"])
        guard result.isSuccess, let data = result.standardOutput.data(using: .utf8) else {
            return map
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let casks = json["casks"] as? [[String: Any]] {
            for cask in casks {
                if let name = cask["name"] as? String,
                   let latestVer = cask["current_version"] as? String {
                    map[name.lowercased()] = (name, latestVer)
                    if let token = cask["token"] as? String {
                        map[token.lowercased()] = (name, latestVer)
                    }
                }
            }
        }
        
        return map
    }
    
    /// Direct check for popular open-source apps using known public update APIs
    private func checkDirectAppUpdate(for app: InstalledApp) async -> AppUpdateInfo? {
        let bundleId = app.bundleIdentifier.lowercased()
        
        if bundleId == "com.microsoft.vscode" {
            let updateURL = URL(string: "https://update.code.visualstudio.com/api/update/darwin-arm64/stable/version")
            if let url = updateURL,
               let (data, _) = try? await urlSession.data(from: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = json["name"] as? String {
                if VersionComparator.isNewer(remoteVersion: name, than: app.version) {
                    var update = AppUpdateInfo()
                    update.hasUpdate = true
                    update.latestVersion = name
                    update.downloadURL = json["url"] as? String ?? "https://code.visualstudio.com"
                    update.updateSource = .directCheck
                    return update
                }
            }
        }
        
        return nil
    }
}
