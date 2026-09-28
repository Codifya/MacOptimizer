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
    
    /// Built once (was a computed property that rebuilt a 26-element Set on every path check).
    private static let protectedUserPaths: Set<String> = {
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
    }()
    
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
        PathProtectionPolicy.isCleanableCachePath(path)
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
    
}
