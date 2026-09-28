import Foundation
import AppKit

/// Service for safely managing processes.
public actor MemoryOptimizerService {
    public static let shared = MemoryOptimizerService()
    
    public init() {}
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
