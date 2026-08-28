import Foundation

/// Service for managing macOS Startup LaunchAgents, Daemons, and Login Items safely.
/// Prevents accidental corruption or deletion of critical macOS boot and system services.
public actor StartupManagerService {
    public static let shared = StartupManagerService()
    
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    
    public init() {}
    
    /// Scans all launch directories for startup agents and daemons
    public func scanStartupItems() async -> [LaunchAgentItem] {
        var items: [LaunchAgentItem] = []
        
        let locations: [(url: URL, type: LaunchItemType)] = [
            (homeDirectory.appendingPathComponent("Library/LaunchAgents"), .userAgent),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .systemAgent),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .systemDaemon)
        ]
        
        for loc in locations {
            guard let contents = try? fileManager.contentsOfDirectory(at: loc.url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for file in contents where file.pathExtension == "plist" {
                if let item = parseLaunchItem(at: file, type: loc.type) {
                    items.append(item)
                }
            }
        }
        
        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
    
    /// Parses a single launch agent plist file
    private func parseLaunchItem(at url: URL, type: LaunchItemType) -> LaunchAgentItem? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        
        let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let runAtLoad = plist["RunAtLoad"] as? Bool ?? true
        let disabled = plist["Disabled"] as? Bool ?? false
        let isEnabled = !disabled
        let isProtected = SafetyGuard.isProtectedLaunchItem(path: url.path, label: label)
        
        var args: [String] = []
        if let prog = plist["Program"] as? String {
            args.append(prog)
        }
        if let progArgs = plist["ProgramArguments"] as? [String] {
            args.append(contentsOf: progArgs)
        }
        
        var appName = label
        if let firstArg = args.first {
            let execURL = URL(fileURLWithPath: firstArg)
            appName = execURL.lastPathComponent
        }
        
        return LaunchAgentItem(
            id: url.path,
            label: label,
            path: url.path,
            programArguments: args,
            isEnabled: isEnabled,
            runAtLoad: runAtLoad,
            itemType: type,
            appName: appName,
            isProtected: isProtected
        )
    }
    
    /// Enables or disables a launch agent safely
    public func toggleItem(_ item: LaunchAgentItem, enable: Bool) async -> Bool {
        // Prevent disabling protected system daemons
        guard !item.isProtected || item.itemType == .userAgent else {
            return false
        }
        
        let result = await SystemCommandRunner.run(executable: "/bin/launchctl", arguments: [enable ? "load" : "unload", "-w", item.path], timeoutSeconds: 5.0)
        return result.isSuccess
    }
    
    /// Removes a launch agent file safely with SafetyGuard validation
    public func removeItem(_ item: LaunchAgentItem) async -> Bool {
        guard !item.isProtected && item.itemType == .userAgent else {
            return false
        }
        
        _ = await toggleItem(item, enable: false)
        do {
            try SafetyGuard.safelyRemoveItem(at: URL(fileURLWithPath: item.path))
            return true
        } catch {
            return false
        }
    }
}
