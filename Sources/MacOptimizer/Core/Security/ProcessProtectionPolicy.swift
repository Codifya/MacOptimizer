import Foundation

/// Policy engine component that protects macOS system daemons, core services, and kernel tasks.
public struct ProcessProtectionPolicy: Sendable {
    
    /// Protected system process names that must NEVER be killed to avoid macOS kernel panics or session crashes.
    public static let protectedSystemProcesses: Set<String> = [
        "kernel_task",
        "launchd",
        "WindowServer",
        "loginwindow",
        "diskarbitrationd",
        "securityd",
        "opendirectoryd",
        "coreauthd",
        "syspolicyd",
        "tccd",
        "trustd",
        "Dock",
        "Finder",
        "SystemUIServer",
        "ControlCenter",
        "NotificationCenter",
        "mds",
        "mds_stores",
        "mdworker",
        "powerd",
        "notifyd",
        "logd",
        "fseventsd",
        "configd",
        "distnoted",
        "usbd",
        "bluetoothd",
        "airportd",
        "identityservicesd",
        "sharingd",
        "coreduetd",
        "apsd",
        "cupsd",
        "syslogd",
        "auditd",
        "diagnosticd",
        "runningboardd",
        "containermanagerd",
        "spindump"
    ]
    
    /// Evaluates if a process is a protected macOS system process.
    public static func isForbiddenProcess(pid: Int32, name: String, path: String? = nil) -> Bool {
        // PID 0 (kernel_task), PID 1 (launchd), and self process cannot be terminated
        if pid <= 1 || pid == getpid() {
            return true
        }
        
        // Exact name match
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if protectedSystemProcesses.contains(cleanName) {
            return true
        }
        
        // Case-insensitive check
        if protectedSystemProcesses.contains(where: { $0.localizedCaseInsensitiveCompare(cleanName) == .orderedSame }) {
            return true
        }
        
        // Binary path protection
        if let binPath = path {
            let canonicalPath = URL(fileURLWithPath: binPath).resolvingSymlinksInPath().standardizedFileURL.path
            if canonicalPath.hasPrefix("/System/Library/CoreServices") ||
                canonicalPath.hasPrefix("/usr/libexec") ||
                canonicalPath.hasPrefix("/System/Library/Frameworks") ||
                canonicalPath.hasPrefix("/System/Applications") {
                return true
            }
        }
        
        return false
    }
}
