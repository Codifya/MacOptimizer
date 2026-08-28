import Foundation

/// Policy engine component that protects essential macOS system applications from being modified or uninstalled.
public struct ApplicationProtectionPolicy: Sendable {
    
    /// Protected Apple system application bundle identifiers.
    public static let protectedBundlePrefixes: [String] = [
        "com.apple.Safari",
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.SystemSettings",
        "com.apple.Terminal",
        "com.apple.mail",
        "com.apple.AppStore",
        "com.apple.launchd",
        "com.apple.Console",
        "com.apple.ActivityMonitor",
        "com.apple.DiskUtility",
        "com.apple.Keychain-Access"
    ]
    
    /// Checks if an application is a protected macOS system application.
    public static func isProtectedApp(path: String, bundleIdentifier: String) -> Bool {
        let canonicalPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
        
        // 1. All applications located in /System are read-only and protected by SIP
        if canonicalPath.hasPrefix("/System/Applications") || canonicalPath.hasPrefix("/System/Library") {
            return true
        }
        
        // 2. Core Apple utilities and applications
        let cleanId = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanId.hasPrefix("com.apple.") {
            for protected in protectedBundlePrefixes {
                if cleanId.localizedCaseInsensitiveCompare(protected) == .orderedSame || cleanId.hasPrefix(protected) {
                    return true
                }
            }
        }
        
        return false
    }
}
