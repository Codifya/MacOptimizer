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
    public struct Confirmation: Sendable {
        fileprivate init() {}
    }

    /// Created only by the UI after presenting the reviewed plan.
    public static func confirm(_ plan: CleaningPlan) -> Confirmation { Confirmation() }

    public static func emptyTrash(_ items: [URL], confirmation: Confirmation) throws {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").resolvingSymlinksInPath().standardizedFileURL
        for item in items {
            let target = item.resolvingSymlinksInPath().standardizedFileURL
            guard target.path.hasPrefix(trash.path + "/"), target == item.resolvingSymlinksInPath().standardizedFileURL else {
                throw NSError(domain: "SafeOperationExecutor", code: 403, userInfo: [NSLocalizedDescriptionKey: "Yalnızca doğrulanmış Çöp Sepeti öğeleri boşaltılabilir."])
            }
            try FileManager.default.removeItem(at: target)
        }
    }

    static func stillResolvesTo(_ url: URL, expected: URL) -> Bool {
        url.resolvingSymlinksInPath().standardizedFileURL == expected
    }

    static func mayDeletePermanently(_ path: String, policyHomeDirectory: URL? = nil) -> Bool {
        PathProtectionPolicy.isCleanableCachePath(path, homeDirectory: policyHomeDirectory)
    }
    
    /// Safely removes a file or directory after validating it against the SafetyPolicyEngine.
    public static func removeFile(at url: URL, moveToTrash: Bool = true, confirmation: Confirmation? = nil, policyHomeDirectory: URL? = nil) throws -> OperationExecutionResult {
        let canonicalURL = url.resolvingSymlinksInPath().standardizedFileURL
        let canonicalPath = canonicalURL.path
        let decision = SafetyPolicyEngine.evaluate(.removeFile(path: canonicalPath), homeDirectory: policyHomeDirectory)
        
        switch decision {
        case .denied(let reason):
            throw NSError(
                domain: "SafeOperationExecutor",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Güvenlik Engeli: \(reason)"]
            )
            
        case .requiresConfirmation(_, _) where confirmation == nil:
            throw NSError(domain: "SafeOperationExecutor", code: 403, userInfo: [NSLocalizedDescriptionKey: "Bu işlem için kullanıcı onayı gerekiyor."])
        case .allowed(let risk), .requiresConfirmation(let risk, _):
            let currentURL = url.resolvingSymlinksInPath().standardizedFileURL
            guard Self.stillResolvesTo(url, expected: canonicalURL), !PathProtectionPolicy.isForbiddenPath(currentURL.path, homeDirectory: policyHomeDirectory) else {
                throw NSError(domain: "SafeOperationExecutor", code: 403, userInfo: [NSLocalizedDescriptionKey: "Dosya yolu doğrulamadan sonra değişti."])
            }
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
                try fm.trashItem(at: canonicalURL, resultingItemURL: &resultingURL)
            } else {
                // If it's pure cache, we can remove it directly
                let isCacheOrTemp = Self.mayDeletePermanently(canonicalPath, policyHomeDirectory: policyHomeDirectory)
                if isCacheOrTemp {
                    try fm.removeItem(at: canonicalURL)
                } else {
                    var resultingURL: NSURL?
                    try fm.trashItem(at: canonicalURL, resultingItemURL: &resultingURL)
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
