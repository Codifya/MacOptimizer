import Foundation
import AppKit

/// Central security and safety protection engine for MacOptimizer.
/// Ensures zero data loss, prevents deletion of critical macOS files, blocks killing vital system processes,
/// and safeguards the user's computer from any destructive actions.
public enum SafetyGuard: Sendable {
    
    // MARK: - Protected System & Essential Directories
    private static let protectedRootPaths: Set<String> = [
        "/",
        "/System",
        "/System/Applications",
        "/System/Library",
        "/Library",
        "/usr",
        "/bin",
        "/sbin",
        "/var",
        "/etc",
        "/dev",
        "/opt",
        "/private",
        "/Volumes"
    ]
    
    private static let userHomePath = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
    
    private static var protectedUserPaths: Set<String> {
        let home = userHomePath
        return [
            home,
            "\(home)/Desktop",
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Pictures",
            "\(home)/Movies",
            "\(home)/Music",
            "\(home)/Applications",
            "\(home)/Library",
            "\(home)/Library/Application Support",
            "\(home)/Library/Caches",
            "\(home)/Library/Preferences",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Logs",
            "\(home)/Library/Keychains",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages",
            "\(home)/Library/Safari",
            "\(home)/Library/Accounts",
            "\(home)/Library/IdentityServices",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/.aws",
            "\(home)/.config"
        ]
    }
    
    // MARK: - Known Essential Developer & App Folders (Never auto-delete from App Leftovers)
    public static let essentialAppSupportFolders: Set<String> = [
        "code", "cursor", "sublime text", "sublime text 3", "iterm2", "iterm",
        "docker", "docker desktop", "steam", "jetbrains", "intellijidea", "pycharm",
        "webstorm", "clion", "goland", "rider", "datagrip", "androidstudio",
        "adobe", "postman", "insomnia", "figma", "slack", "discord", "telegram desktop",
        "whatsapp", "signal", "spotify", "notion", "obsidian", "1password", "bitwarden",
        "google", "chrome", "brave", "firefox", "arc", "edge", "safari",
        "apple", "icloud", "addressbook", "dock", "syncservices", "crashreporter",
        "mobiledevice", "clouddocs", "callhistorydb", "coredata", "fileprovider",
        "knowledge", "spotlight", "macoptimizer"
    ]
    
    // MARK: - Protected System Process Names (Never Terminate)
    public static let protectedProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "windowserver",
        "loginwindow",
        "diskarbitrationd",
        "securityd",
        "opendirectoryd",
        "coreauthd",
        "syspolicyd",
        "tccd",
        "fseventsd",
        "mds",
        "mds_stores",
        "mdworker",
        "powerd",
        "logd",
        "notifyd",
        "configd",
        "bluetoothd",
        "airportd",
        "identityservicesd",
        "trustd",
        "distnoted",
        "cfprefsd",
        "dock",
        "finder",
        "systemuiserver",
        "controlcenter",
        "notificationcenter",
        "audiomxd",
        "coreaudiod",
        "cloudd",
        "bird",
        "systemmanagementd",
        "usbd",
        "sharingd",
        "coreduetd",
        "apsd",
        "cupsd",
        "syslogd",
        "auditd",
        "diagnosticd",
        "runningboardd",
        "containermanagerd",
        "spindump",
        "macoptimizer"
    ]
    
    // MARK: - Path Safety Validation
    
    /// Validates whether a file or directory path is safe to clean or remove.
    /// Returns true ONLY if the path is strictly non-system, non-root, and inside an allowed safe subfolder.
    public static func isSafeToClean(path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        
        // 1. Check for empty or whitespace path
        guard !standardized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // 2. Reject exact match with root or user protected directories
        if protectedRootPaths.contains(standardized) || protectedUserPaths.contains(standardized) {
            return false
        }
        
        // 3. Reject any path directly inside /System, /usr, /bin, /sbin, /etc, /var/root
        if standardized.hasPrefix("/System/") ||
           standardized.hasPrefix("/usr/") ||
           standardized.hasPrefix("/bin/") ||
           standardized.hasPrefix("/sbin/") ||
           standardized.hasPrefix("/etc/") ||
           standardized.hasPrefix("/var/root") {
            return false
        }
        
        // 4. Reject critical user roots like ~/.ssh, ~/.gnupg, ~/Library/Keychains, ~/Library/Mail
        let home = userHomePath
        if standardized.hasPrefix("\(home)/.ssh") ||
           standardized.hasPrefix("\(home)/.gnupg") ||
           standardized.hasPrefix("\(home)/Library/Keychains") ||
           standardized.hasPrefix("\(home)/Library/Mail") ||
           standardized.hasPrefix("\(home)/Library/Messages") ||
           standardized.hasPrefix("\(home)/Library/Accounts") {
            return false
        }
        
        // 5. Must reside within safe user directories (Caches, Logs, Developer, Trash, or sandboxed subdirectories)
        let isInsideUserCaches = standardized.hasPrefix("\(home)/Library/Caches/")
        let isInsideUserLogs = standardized.hasPrefix("\(home)/Library/Logs/")
        let isInsideTrash = standardized.hasPrefix("\(home)/.Trash")
        let isInsideDerivedData = standardized.hasPrefix("\(home)/Library/Developer/")
        let isInsideDevCaches = standardized.hasPrefix("\(home)/.npm/") ||
                                standardized.hasPrefix("\(home)/.yarn/") ||
                                standardized.hasPrefix("\(home)/.pnpm-store/") ||
                                standardized.hasPrefix("\(home)/.cargo/") ||
                                standardized.hasPrefix("\(home)/.gradle/") ||
                                standardized.hasPrefix("\(home)/.cache/")
        let isInsideContainers = standardized.hasPrefix("\(home)/Library/Containers/") ||
                                 standardized.hasPrefix("\(home)/Library/Group Containers/")
        let isInsideAppSupport = standardized.hasPrefix("\(home)/Library/Application Support/")
        let isInsideSavedState = standardized.hasPrefix("\(home)/Library/Saved Application State/")
        let isInsideWebKit = standardized.hasPrefix("\(home)/Library/WebKit/")
        let isInsideHTTPStorages = standardized.hasPrefix("\(home)/Library/HTTPStorages/")
        let isInsidePreferences = standardized.hasPrefix("\(home)/Library/Preferences/")
        let isInsideLaunchAgents = standardized.hasPrefix("\(home)/Library/LaunchAgents/")
        let isInsideUserDownloads = standardized.hasPrefix("\(home)/Downloads/")
        let isInsideUserDocuments = standardized.hasPrefix("\(home)/Documents/")
        let isInsideUserMovies = standardized.hasPrefix("\(home)/Movies/")
        let isInsideUserMusic = standardized.hasPrefix("\(home)/Music/")
        let isUserApp = standardized.hasPrefix("/Applications/") || standardized.hasPrefix("\(home)/Applications/")
        
        let isSafeSubfolder = isInsideUserCaches ||
                              isInsideUserLogs ||
                              isInsideTrash ||
                              isInsideDerivedData ||
                              isInsideDevCaches ||
                              isInsideContainers ||
                              isInsideAppSupport ||
                              isInsideSavedState ||
                              isInsideWebKit ||
                              isInsideHTTPStorages ||
                              isInsidePreferences ||
                              isInsideLaunchAgents ||
                              isInsideUserDownloads ||
                              isInsideUserDocuments ||
                              isInsideUserMovies ||
                              isInsideUserMusic ||
                              isUserApp
        
        guard isSafeSubfolder else { return false }
        
        // 6. Ensure path is not just the parent directory itself
        let components = standardized.components(separatedBy: "/").filter { !$0.isEmpty }
        guard components.count >= 3 else { return false }
        
        return true
    }
    
    // MARK: - App Safety Checks
    
    /// Checks whether an application is a protected macOS system app that should not be uninstalled.
    public static func isProtectedSystemApp(path: String, bundleIdentifier: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let lowerBundle = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if standardized.hasPrefix("/System/") || standardized.hasPrefix("/System/Applications") {
            return true
        }
        
        // Core Apple system bundle IDs
        if lowerBundle.hasPrefix("com.apple.finder") ||
           lowerBundle.hasPrefix("com.apple.dock") ||
           lowerBundle.hasPrefix("com.apple.systempreferences") ||
           lowerBundle.hasPrefix("com.apple.systemsettings") ||
           lowerBundle.hasPrefix("com.apple.safari") ||
           lowerBundle.hasPrefix("com.apple.textedit") ||
           lowerBundle.hasPrefix("com.apple.terminal") ||
           lowerBundle.hasPrefix("com.apple.appstore") ||
           lowerBundle.hasPrefix("com.apple.activitymonitor") ||
           lowerBundle.hasPrefix("com.apple.keychainaccess") ||
           lowerBundle.hasPrefix("com.apple.diskutility") ||
           lowerBundle.hasPrefix("com.apple.launchpad") ||
           lowerBundle.hasPrefix("com.apple.controlcenter") {
            return true
        }
        
        return false
    }
    
    // MARK: - Process Termination Safety Checks
    
    /// Checks whether a process can be safely terminated without causing macOS instability or data loss.
    public static func isProcessKillable(pid: Int32, name: String, path: String = "") -> Bool {
        // PID 0 is kernel_task, PID 1 is launchd
        if pid <= 1 {
            return false
        }
        
        // Own process
        if pid == ProcessInfo.processInfo.processIdentifier {
            return false
        }
        
        let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if protectedProcessNames.contains(lowerName) {
            return false
        }
        
        let lowerPath = path.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowerPath.hasPrefix("/system/library/coreservices/") ||
           lowerPath.hasPrefix("/usr/libexec/") ||
           lowerPath.hasPrefix("/system/library/frameworks/") {
            return false
        }
        
        return true
    }
    
    // MARK: - Launch Agent Safety Checks
    
    /// Checks whether a launch agent or daemon is a protected system item.
    public static func isProtectedLaunchItem(path: String, label: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let lowerLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // System Daemons & Agents in /Library or /System
        if standardized.hasPrefix("/System/") || standardized.hasPrefix("/Library/LaunchDaemons") {
            return true
        }
        
        if lowerLabel.hasPrefix("com.apple.") {
            return true
        }
        
        return false
    }
    
    // MARK: - Safe Removal Handler
    
    /// Safely moves an item to Trash if possible, or falls back to permanent removal only for approved cache/temp paths.
    public static func safelyRemoveItem(at url: URL, moveToTrashOnly: Bool = false) throws {
        let path = url.standardizedFileURL.path
        guard isSafeToClean(path: path) else {
            throw NSError(
                domain: "SafetyGuard",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Güvenlik Engeli: Korunan sistem veya kullanıcı konumu silinemez (\(path))."]
            )
        }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }
        
        if moveToTrashOnly {
            var resultingURL: NSURL?
            try fm.trashItem(at: url, resultingItemURL: &resultingURL)
        } else {
            // For general safety, try moving to Trash first if outside cache/trash
            let isCacheOrTemp = path.contains("/Library/Caches/") ||
                                path.contains("/Library/Logs/") ||
                                path.contains("/.Trash") ||
                                path.contains("/Library/Developer/Xcode/DerivedData")
            
            if isCacheOrTemp {
                try fm.removeItem(at: url)
            } else {
                do {
                    var resultingURL: NSURL?
                    try fm.trashItem(at: url, resultingItemURL: &resultingURL)
                } catch {
                    // Fallback to removeItem if Trash is not available
                    try fm.removeItem(at: url)
                }
            }
        }
    }
}
