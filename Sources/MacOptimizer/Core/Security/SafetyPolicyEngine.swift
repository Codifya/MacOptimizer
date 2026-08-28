import Foundation

/// Policy decision returned after evaluating an operation against zero-harm rules.
public enum PolicyDecision: Sendable, Equatable {
    case allowed(risk: OperationRisk)
    case requiresConfirmation(risk: OperationRisk, warning: String)
    case denied(reason: String)
    
    public var isAllowed: Bool {
        switch self {
        case .allowed, .requiresConfirmation:
            return true
        case .denied:
            return false
        }
    }
}

/// Defines the target of a proposed system operation.
public enum OperationTarget: Sendable {
    case removeFile(path: String)
    case terminateProcess(pid: Int32, name: String, path: String? = nil)
    case uninstallApp(path: String, bundleIdentifier: String)
    case toggleLaunchItem(path: String, label: String)
    case removeLaunchItem(path: String, label: String)
    case executeMaintenance(taskIdentifier: String)
}

/// Central Security Policy Engine enforcing Zero-Harm, Symlink Protection, and Defense-in-Depth.
public struct SafetyPolicyEngine: Sendable {
    
    /// Evaluates any requested system operation against the safety policy matrix.
    public static func evaluate(_ target: OperationTarget) -> PolicyDecision {
        switch target {
        case .removeFile(let path):
            let canonical = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
            if PathProtectionPolicy.isForbiddenPath(canonical) {
                return .denied(reason: "Sistem kök dizinleri veya kullanıcı ana veri klasörleri silinemez: \(canonical)")
            }
            
            let risk = OperationRiskClassifier.classifyFileRemoval(path: canonical)
            if risk == .forbidden {
                return .denied(reason: "Güvenlik politikası bu yolun silinmesini engelledi.")
            }
            
            if risk == .destructive {
                return .requiresConfirmation(risk: risk, warning: "Bu işlem geri alınamaz bir dosya silme işlemidir.")
            }
            
            return .allowed(risk: risk)
            
        case .terminateProcess(let pid, let name, let path):
            if ProcessProtectionPolicy.isForbiddenProcess(pid: pid, name: name, path: path) {
                return .denied(reason: "macOS çekirdek ve sistem süreçleri (\(name), PID: \(pid)) sonlandırılamaz.")
            }
            return .allowed(risk: .medium)
            
        case .uninstallApp(let path, let bundleIdentifier):
            let canonical = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
            if ApplicationProtectionPolicy.isProtectedApp(path: canonical, bundleIdentifier: bundleIdentifier) {
                return .denied(reason: "macOS yerleşik sistem uygulamaları kaldırılamaz.")
            }
            return .requiresConfirmation(risk: .destructive, warning: "\(bundleIdentifier) uygulaması tüm ilişkili dosyalarıyla kaldırılacaktır.")
            
        case .toggleLaunchItem(let path, let label):
            if LaunchItemProtectionPolicy.isProtectedLaunchItem(path: path, label: label) {
                return .denied(reason: "macOS sistem launch daemon ve servisleri devre dışı bırakılamaz.")
            }
            return .allowed(risk: .low)
            
        case .removeLaunchItem(let path, let label):
            if LaunchItemProtectionPolicy.isProtectedLaunchItem(path: path, label: label) {
                return .denied(reason: "macOS sistem servisleri silinemez.")
            }
            return .requiresConfirmation(risk: .destructive, warning: "\(label) başlangıç servisi kalıcı olarak silinecektir.")
            
        case .executeMaintenance(let taskIdentifier):
            let risk = OperationRiskClassifier.classifyMaintenanceTask(taskIdentifier: taskIdentifier)
            return .allowed(risk: risk)
        }
    }
    
    // MARK: - Convenience Checkers
    public static func canDelete(path: String) -> Bool {
        return evaluate(.removeFile(path: path)).isAllowed
    }
    
    public static func canTerminateProcess(pid: Int32, name: String, path: String? = nil) -> Bool {
        return evaluate(.terminateProcess(pid: pid, name: name, path: path)).isAllowed
    }
    
    public static func canUninstallApp(path: String, bundleIdentifier: String) -> Bool {
        return evaluate(.uninstallApp(path: path, bundleIdentifier: bundleIdentifier)).isAllowed
    }
}
