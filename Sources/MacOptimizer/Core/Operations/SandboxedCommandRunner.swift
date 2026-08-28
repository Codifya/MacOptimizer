import Foundation

/// Whitelist of approved macOS system executables.
public enum ApprovedExecutable: String, Sendable, CaseIterable {
    case dscacheutil = "/usr/bin/dscacheutil"
    case killall     = "/usr/bin/killall"
    case mdutil      = "/usr/bin/mdutil"
    case qlmanage    = "/usr/bin/qlmanage"
    case lsregister  = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    case atsutil     = "/usr/bin/atsutil"
}

/// Execution result for sandboxed commands.
public struct CommandExecutionResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let durationMs: Double
    
    public var isSuccess: Bool { exitCode == 0 }
}

/// Sandbox runner that prevents arbitrary shell command execution and enforces executable whitelisting and timeouts.
public struct SandboxedCommandRunner: Sendable {
    
    /// Runs a whitelisted executable with explicit arguments and timeout protection.
    public static func run(
        executable: ApprovedExecutable,
        arguments: [String],
        timeoutSeconds: TimeInterval = 15.0
    ) async -> CommandExecutionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: executable.rawValue)
        
        // Sanitize arguments to prevent injection
        let sanitizedArgs = arguments.filter { arg in
            !arg.contains(";") && !arg.contains("|") && !arg.contains("&") && !arg.contains("`") && !arg.contains("$")
        }
        process.arguments = sanitizedArgs
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        return await withCheckedContinuation { continuation in
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
            timer.schedule(deadline: .now() + timeoutSeconds)
            timer.setEventHandler {
                if process.isRunning {
                    process.terminate()
                }
                timer.cancel()
            }
            timer.resume()
            
            process.terminationHandler = { proc in
                timer.cancel()
                let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                
                let outStr = String(data: stdoutData, encoding: .utf8) ?? ""
                let errStr = String(data: stderrData, encoding: .utf8) ?? ""
                
                continuation.resume(returning: CommandExecutionResult(
                    exitCode: proc.terminationStatus,
                    stdout: outStr,
                    stderr: errStr,
                    durationMs: elapsedMs
                ))
            }
            
            do {
                try process.run()
            } catch {
                timer.cancel()
                continuation.resume(returning: CommandExecutionResult(
                    exitCode: -1,
                    stdout: "",
                    stderr: "Çalıştırma hatası: \(error.localizedDescription)",
                    durationMs: 0
                ))
            }
        }
    }
}
