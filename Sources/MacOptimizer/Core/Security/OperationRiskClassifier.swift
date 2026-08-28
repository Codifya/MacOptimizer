import Foundation

/// Defines the security and damage risk level of any operation requested in the toolkit.
public enum OperationRisk: String, Comparable, CaseIterable, Sendable, Codable {
    case safe          // Read-only inspection, telemetry, hardware inspection
    case low           // In-memory RAM release, DNS flush, QuickLook thumbnail reset
    case medium        // Delete isolated user app caches, kill normal user processes
    case destructive   // Uninstall entire 3rd-party application, purge logs
    case forbidden     // System root deletion, PID 0/1 termination, deleting ~/Documents, modifying SIP
    
    public var displayName: String {
        switch self {
        case .safe: return "Güvenli (Salt Okunur)"
        case .low: return "Düşük Risk"
        case .medium: return "Orta Risk"
        case .destructive: return "Yüksek Risk (Geri Alınamaz)"
        case .forbidden: return "YASAKLI (Sistem Koruması)"
        }
    }
    
    public var badgeColor: String {
        switch self {
        case .safe: return "blue"
        case .low: return "green"
        case .medium: return "orange"
        case .destructive: return "red"
        case .forbidden: return "purple"
        }
    }
    
    public static func < (lhs: OperationRisk, rhs: OperationRisk) -> Bool {
        let order: [OperationRisk] = [.safe, .low, .medium, .destructive, .forbidden]
        guard let lIdx = order.firstIndex(of: lhs), let rIdx = order.firstIndex(of: rhs) else { return false }
        return lIdx < rIdx
    }
}

/// Classifies operations based on target type, path, process, and parameters.
public struct OperationRiskClassifier: Sendable {
    
    public static func classifyFileRemoval(path: String) -> OperationRisk {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let canonicalPath = url.standardizedFileURL.path
        
        // 1. Check if path is in forbidden system or root user paths
        if PathProtectionPolicy.isForbiddenPath(canonicalPath) {
            return .forbidden
        }
        
        // 2. Check if path is in approved cache / logs / trash subdirectories
        if PathProtectionPolicy.isCleanableCachePath(canonicalPath) {
            if canonicalPath.contains("/.Trash") {
                return .medium
            }
            return .low
        }
        
        // 3. User application deletion is destructive
        if canonicalPath.hasSuffix(".app") {
            return .destructive
        }
        
        // Default unverified file operations default to destructive
        return .destructive
    }
    
    public static func classifyProcessTermination(pid: Int32, name: String, path: String? = nil) -> OperationRisk {
        if ProcessProtectionPolicy.isForbiddenProcess(pid: pid, name: name, path: path) {
            return .forbidden
        }
        return .medium
    }
    
    public static func classifyMaintenanceTask(taskIdentifier: String) -> OperationRisk {
        switch taskIdentifier {
        case "dns", "quicklook", "clipboard", "purgeRAM":
            return .low
        case "spotlight", "trash":
            return .medium
        default:
            return .medium
        }
    }
}
