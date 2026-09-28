import Foundation
import AppKit

/// Service for optimizing and purging macOS RAM, freeing inactive cache, and managing processes safely
public actor MemoryOptimizerService {
    public static let shared = MemoryOptimizerService()
    
    public struct OptimizationResult: Sendable {
        public let initialFreeBytes: UInt64
        public let finalFreeBytes: UInt64
        public let freedBytes: UInt64
        public let durationSeconds: Double
        public let success: Bool
        public let message: String
    }
    
    public init() {}
    
    /// RAM purge requires administrator privileges and is not available without escalation.
    public func purgeMemory() async -> OptimizationResult {
        return OptimizationResult(
            initialFreeBytes: 0,
            finalFreeBytes: 0,
            freedBytes: 0,
            durationSeconds: 0,
            success: false,
            message: "RAM boşaltma bu uygulama tarafından yönetici yetkisi olmadan gerçekleştirilemiyor. Bellek baskısı yüksekse açık uygulamaları kapatın."
        )
    }
    
    /// Safely terminates a process by PID after verifying it is not a protected system or kernel process
    public func terminateProcess(pid: Int32, name: String = "", path: String = "", force: Bool = false) async -> Bool {
        // Enforce strict safety guard
        guard SafetyGuard.isProcessKillable(pid: pid, name: name, path: path) else {
            return false
        }
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            if force {
                return app.forceTerminate()
            } else {
                return app.terminate()
            }
        } else {
            let signal = force ? "-9" : "-15"
            let result = await SystemCommandRunner.run(executable: "/bin/kill", arguments: [signal, "\(pid)"], timeoutSeconds: 5.0)
            return result.isSuccess
        }
    }
}
