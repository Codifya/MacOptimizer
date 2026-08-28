import Foundation
import AppKit

/// Result of a safely executed system operation.
public struct OperationExecutionResult: Sendable {
    public let target: String
    public let risk: OperationRisk
    public let success: Bool
    public let message: String
    public let bytesFreed: Int64
    public let timestamp: Date
    
    public init(
        target: String,
        risk: OperationRisk,
        success: Bool,
        message: String,
        bytesFreed: Int64 = 0,
        timestamp: Date = Date()
    ) {
        self.target = target
        self.risk = risk
        self.success = success
        self.message = message
        self.bytesFreed = bytesFreed
        self.timestamp = timestamp
    }
}

/// Atomic, policy-governed executor for all filesystem, process, and maintenance operations.
public struct SafeOperationExecutor: Sendable {
    
    /// Safely removes a file or directory after validating it against the SafetyPolicyEngine.
    public static func removeFile(at url: URL, moveToTrash: Bool = true) throws -> OperationExecutionResult {
        let canonicalPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        let decision = SafetyPolicyEngine.evaluate(.removeFile(path: canonicalPath))
        
        switch decision {
        case .denied(let reason):
            throw NSError(
                domain: "SafeOperationExecutor",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Güvenlik Engeli: \(reason)"]
            )
            
        case .allowed(let risk), .requiresConfirmation(let risk, _):
            let fm = FileManager.default
            guard fm.fileExists(atPath: canonicalPath) else {
                return OperationExecutionResult(
                    target: canonicalPath,
                    risk: risk,
                    success: true,
                    message: "Dosya zaten mevcut değil."
                )
            }
            
            // Calculate size before deletion
            var fileSize: Int64 = 0
            if let attrs = try? fm.attributesOfItem(atPath: canonicalPath), let size = attrs[.size] as? Int64 {
                fileSize = size
            }
            
            if moveToTrash {
                var resultingURL: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &resultingURL)
            } else {
                // If it's pure cache, we can remove it directly
                let isCacheOrTemp = canonicalPath.contains("/Library/Caches/") ||
                                    canonicalPath.contains("/Library/Logs/") ||
                                    canonicalPath.contains("/.Trash") ||
                                    canonicalPath.contains("/Library/Developer/Xcode/DerivedData")
                if isCacheOrTemp {
                    try fm.removeItem(at: url)
                } else {
                    var resultingURL: NSURL?
                    try fm.trashItem(at: url, resultingItemURL: &resultingURL)
                }
            }
            
            return OperationExecutionResult(
                target: canonicalPath,
                risk: risk,
                success: true,
                message: "Öğe başarıyla temizlendi.",
                bytesFreed: fileSize
            )
        }
    }
    
    /// Safely terminates a non-system process after policy evaluation.
    public static func terminateProcess(pid: Int32, name: String, path: String? = nil, force: Bool = false) -> OperationExecutionResult {
        let decision = SafetyPolicyEngine.evaluate(.terminateProcess(pid: pid, name: name, path: path))
        
        switch decision {
        case .denied(let reason):
            return OperationExecutionResult(
                target: "\(name) (PID: \(pid))",
                risk: .forbidden,
                success: false,
                message: reason
            )
            
        case .allowed(let risk), .requiresConfirmation(let risk, _):
            let signal = force ? SIGKILL : SIGTERM
            let ret = kill(pid, signal)
            if ret == 0 {
                return OperationExecutionResult(
                    target: "\(name) (PID: \(pid))",
                    risk: risk,
                    success: true,
                    message: "\(name) işlemi sonlandırıldı."
                )
            } else {
                return OperationExecutionResult(
                    target: "\(name) (PID: \(pid))",
                    risk: risk,
                    success: false,
                    message: "İşlem sonlandırılamadı (Hata Kodu: \(errno))."
                )
            }
        }
    }
}
