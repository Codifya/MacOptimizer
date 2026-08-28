import Foundation

/// Policy engine component that protects macOS system-level launch daemons and background agents.
public struct LaunchItemProtectionPolicy: Sendable {
    
    /// Checks if a launch agent or daemon is a protected macOS system service.
    public static func isProtectedLaunchItem(path: String, label: String) -> Bool {
        let canonicalPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
        
        // 1. System launch items in /System/Library and /Library/LaunchDaemons must be protected
        if canonicalPath.hasPrefix("/System/Library/LaunchAgents") ||
            canonicalPath.hasPrefix("/System/Library/LaunchDaemons") ||
            canonicalPath.hasPrefix("/Library/LaunchDaemons") {
            return true
        }
        
        // 2. Apple internal service labels
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanLabel.hasPrefix("com.apple.") {
            return true
        }
        
        return false
    }
}
