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
    
    /// Purges inactive and purgeable memory using safe memory allocation pressure cycling and the system purge command
    public func purgeMemory() async -> OptimizationResult {
        let startTime = Date()
        let initialStats = await SystemMonitorService.shared.fetchMemoryStats()
        let initialFree = initialStats.freeAndInactiveBytes
        
        // Dynamic, safe memory allocation calculation:
        // Cap allocation at max 256 MB or 1/4th of actual free memory to prevent system freeze/OOM crashes.
        let safeMaxAllocation: UInt64 = 256 * 1024 * 1024 // 256 MB max
        let targetAllocationBytes = Swift.min(safeMaxAllocation, Swift.max(64 * 1024 * 1024, initialStats.freeBytes / 4))
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let chunkSize = 32 * 1024 * 1024 // 32 MB chunks
                let count = max(1, Int(targetAllocationBytes) / chunkSize)
                var buffers: [UnsafeMutableRawPointer] = []
                
                defer {
                    for ptr in buffers {
                        free(ptr)
                    }
                    buffers.removeAll()
                }
                
                for _ in 0..<count {
                    if let ptr = malloc(chunkSize) {
                        // Gently touch memory pages without aggressive lock
                        memset(ptr, 0x00, chunkSize)
                        buffers.append(ptr)
                    }
                }
                
                // Allow kernel virtual memory subsystem to flush purgeable caches
                usleep(150_000) // 150ms
                continuation.resume()
            }
        }
        
        // Execute system purge utility if available
        _ = await SystemCommandRunner.run(executable: "/usr/sbin/purge", timeoutSeconds: 5.0)
        
        // Allow Mach kernel statistics to settle
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let finalStats = await SystemMonitorService.shared.fetchMemoryStats()
        let finalFree = finalStats.freeAndInactiveBytes
        let freed = finalFree > initialFree ? (finalFree - initialFree) : 0
        let duration = Date().timeIntervalSince(startTime)
        
        let message: String
        if freed > 25 * 1024 * 1024 {
            message = "\(ByteFormatter.formatMemory(freed)) RAM başarıyla serbest bırakıldı."
        } else {
            message = "Sistem sanal bellek sayfaları ve önbellekleri optimize edildi."
        }
        
        return OptimizationResult(
            initialFreeBytes: initialFree,
            finalFreeBytes: finalFree,
            freedBytes: freed,
            durationSeconds: duration,
            success: true,
            message: message
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
