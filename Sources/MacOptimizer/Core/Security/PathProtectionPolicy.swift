import Foundation

/// Policy engine component that validates filesystem paths against system rules and symlink attacks.
public struct PathProtectionPolicy: Sendable {
    
    /// Critical macOS root & system directory prefixes that must NEVER be modified or cleaned.
    public static let forbiddenSystemPrefixes: [String] = [
        "/",
        "/System",
        "/System/Applications",
        "/System/Library",
        "/System/Volumes",
        "/Library",
        "/Library/Apple",
        "/Library/Application Support/Apple",
        "/Library/Preferences",
        "/Library/Extensions",
        "/Library/Frameworks",
        "/Library/Keychains",
        "/Library/LaunchDaemons",
        "/Library/SystemExtensions",
        "/usr",
        "/bin",
        "/sbin",
        "/var",
        "/var/root",
        "/etc",
        "/dev",
        "/private",
        "/private/var",
        "/private/etc",
        "/Volumes",
        "/cores",
        "/opt",
        "/Users"
    ]
    
    /// User root and critical data directories that must NEVER be cleaned directly.
    public static var forbiddenUserPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().standardizedFileURL.path
        return [
            home,
            "\(home)/Desktop",
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Movies",
            "\(home)/Music",
            "\(home)/Pictures",
            "\(home)/Applications",
            "\(home)/Library",
            "\(home)/Library/Application Support",
            "\(home)/Library/Keychains",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages",
            "\(home)/Library/Photos",
            "\(home)/Library/Safari",
            "\(home)/Library/Preferences",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Mobile Documents",
            "\(home)/.ssh",
            "\(home)/.gnupg",
            "\(home)/.aws",
            "\(home)/.config",
            "\(home)/.zshrc",
            "\(home)/.bash_profile",
            "\(home)/.bashrc",
            "\(home)/.gitconfig"
        ]
    }
    
    /// Whitelist of safe parent directories where item-level deletion is permitted.
    public static var safeParentPrefixes: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().standardizedFileURL.path
        return [
            "\(home)/Library/Caches/",
            "\(home)/Library/Logs/",
            "\(home)/Library/Developer/Xcode/DerivedData/",
            "\(home)/Library/Developer/Xcode/Archives/",
            "\(home)/Library/Developer/Xcode/iOS DeviceSupport/",
            "\(home)/Library/Developer/Xcode/watchOS DeviceSupport/",
            "\(home)/Library/Developer/CoreSimulator/Caches/",
            "\(home)/.npm/_cacache/",
            "\(home)/.yarn/cache/",
            "\(home)/.cargo/registry/cache/",
            "\(home)/.gradle/caches/",
            "\(home)/.cache/pip/",
            "\(home)/Library/Caches/Homebrew/",
            "\(home)/Library/Caches/pypoetry/",
            "\(home)/Library/Caches/uv/",
            "\(home)/Library/Caches/CocoaPods/",
            "\(home)/.Trash/",
            "/Library/Caches/",
            "/Library/Logs/DiagnosticReports/"
        ]
    }
    
    /// Evaluates if a given path is completely forbidden from deletion/cleaning.
    /// Resolves symlinks first to prevent symlink traversal attacks.
    public static func isForbiddenPath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        
        let url = URL(fileURLWithPath: trimmed).resolvingSymlinksInPath()
        let canonicalPath = url.standardizedFileURL.path
        
        // 1. Check exact match with forbidden system paths
        for forbidden in forbiddenSystemPrefixes {
            if canonicalPath == forbidden || trimmed == forbidden {
                return true
            }
        }
        
        // 2. Check exact match with forbidden user paths
        for forbidden in forbiddenUserPaths {
            if canonicalPath == forbidden || trimmed == forbidden {
                return true
            }
        }
        
        // 3. Reject if path is within root system folders (unless it's an approved cache/log folder)
        let systemRoots = ["/System", "/usr", "/bin", "/sbin", "/etc", "/dev", "/private", "/cores", "/opt", "/Volumes", "/Library", "/Users", "/var"]
        for sysRoot in systemRoots {
            if canonicalPath == sysRoot || canonicalPath.hasPrefix("\(sysRoot)/") || trimmed == sysRoot || trimmed.hasPrefix("\(sysRoot)/") {
                // If it's inside /Users/username (and not /Users itself), allow subpath validation
                let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().standardizedFileURL.path
                if (canonicalPath.hasPrefix("\(home)/") || canonicalPath == home) && sysRoot == "/Users" {
                    continue
                }
                
                // If it's an approved cache inside /Library, allow
                if sysRoot == "/Library" && (canonicalPath.hasPrefix("/Library/Caches/") || canonicalPath.hasPrefix("/Library/Logs/DiagnosticReports/")) {
                    continue
                }
                
                return true
            }
        }
        
        // 4. Protect essential developer & cloud config dirs in user home
        let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().standardizedFileURL.path
        let protectedHiddenDirs = [
            "\(home)/.ssh", "\(home)/.gnupg", "\(home)/.aws", "\(home)/.config", "\(home)/.git"
        ]
        for pDir in protectedHiddenDirs {
            if canonicalPath == pDir || canonicalPath.hasPrefix("\(pDir)/") || trimmed == pDir || trimmed.hasPrefix("\(pDir)/") {
                return true
            }
        }
        
        return false
    }
    
    /// Verifies if a file or folder is inside an approved cleanable cache / temporary directory.
    public static func isCleanableCachePath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        let url = URL(fileURLWithPath: trimmed).resolvingSymlinksInPath()
        let canonicalPath = url.standardizedFileURL.path
        
        // Forbidden check must take absolute precedence
        if isForbiddenPath(canonicalPath) || isForbiddenPath(trimmed) {
            return false
        }
        
        // Ensure path is deeply nested inside an approved prefix
        for prefix in safeParentPrefixes {
            if (canonicalPath.hasPrefix(prefix) && canonicalPath != prefix && canonicalPath != String(prefix.dropLast())) ||
               (trimmed.hasPrefix(prefix) && trimmed != prefix && trimmed != String(prefix.dropLast())) {
                return true
            }
        }
        
        return false
    }
}
