import Foundation

/// Safe, asynchronous system command execution helper using Process with timeout protection and cancellation support
public enum SystemCommandRunner: Sendable {
    
    public struct CommandResult: Sendable {
        public let exitCode: Int32
        public let standardOutput: String
        public let standardError: String
        public let isTimedOut: Bool
        
        public var isSuccess: Bool {
            return exitCode == 0 && !isTimedOut
        }
        
        public init(exitCode: Int32, standardOutput: String, standardError: String, isTimedOut: Bool = false) {
            self.exitCode = exitCode
            self.standardOutput = standardOutput
            self.standardError = standardError
            self.isTimedOut = isTimedOut
        }
    }
    
    /// Runs an executable with arguments asynchronously and enforces a strict timeout to prevent hangs
    public static func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeoutSeconds: Double = 15.0
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                
                if let env = environment {
                    var currentEnv = ProcessInfo.processInfo.environment
                    for (k, v) in env {
                        currentEnv[k] = v
                    }
                    process.environment = currentEnv
                }
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                // Timeout watchdog timer
                let timeoutWorkItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWorkItem)
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    timeoutWorkItem.cancel()
                    
                    let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let stdout = String(data: outData, encoding: .utf8) ?? ""
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    
                    let isTimedOut = process.terminationReason == .uncaughtSignal
                    
                    continuation.resume(returning: CommandResult(
                        exitCode: isTimedOut ? -2 : process.terminationStatus,
                        standardOutput: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                        standardError: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                        isTimedOut: isTimedOut
                    ))
                } catch {
                    timeoutWorkItem.cancel()
                    continuation.resume(returning: CommandResult(
                        exitCode: -1,
                        standardOutput: "",
                        standardError: error.localizedDescription,
                        isTimedOut: false
                    ))
                }
            }
        }
    }
    
    /// Runs a safe command via /bin/zsh with arguments
    public static func runShell(_ command: String, timeoutSeconds: Double = 15.0) async -> CommandResult {
        return await run(executable: "/bin/zsh", arguments: ["-c", command], timeoutSeconds: timeoutSeconds)
    }
}
