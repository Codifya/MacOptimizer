import Foundation

/// Asynchronous system command execution helper with timeout protection and cancellation support.
/// All execution is delegated to `ProcessExecutor`, which drains pipes concurrently and bounds output.
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
        timeoutSeconds: Double = 15.0,
        outputLimit: Int = ProcessExecutor.defaultOutputLimit
    ) async -> CommandResult {
        let output = await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: executable),
            arguments: arguments,
            environment: environment,
            timeout: timeoutSeconds,
            outputLimit: outputLimit
        )
        return CommandResult(
            exitCode: output.exitCode,
            standardOutput: output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            standardError: output.standardError.trimmingCharacters(in: .whitespacesAndNewlines),
            isTimedOut: output.isTimedOut
        )
    }
}
