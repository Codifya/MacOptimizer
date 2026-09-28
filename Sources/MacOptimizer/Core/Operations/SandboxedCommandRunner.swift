import Foundation

/// Whitelist of approved macOS system executables.
public enum ApprovedExecutable: String, Sendable, CaseIterable {
    case dscacheutil = "/usr/bin/dscacheutil"
    case killall     = "/usr/bin/killall"
    case mdutil      = "/usr/bin/mdutil"
    case qlmanage    = "/usr/bin/qlmanage"
    case lsregister  = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    case atsutil     = "/usr/bin/atsutil"
    case launchctl   = "/bin/launchctl"
    case csrutil     = "/usr/bin/csrutil"
    case spctl       = "/usr/sbin/spctl"
    case defaults    = "/usr/bin/defaults"
    case socketfilterfw = "/usr/libexec/ApplicationFirewall/socketfilterfw"
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
    /// Execution goes through `ProcessExecutor` (concurrent pipe draining, bounded output,
    /// SIGTERM→SIGKILL escalation, cancellation), so a chatty or hung tool cannot stall the caller.
    public static func run(
        executable: ApprovedExecutable,
        arguments: [String],
        timeoutSeconds: TimeInterval = 15.0
    ) async -> CommandExecutionResult {
        // Sanitize arguments to prevent injection
        let sanitizedArgs = sanitizedArguments(arguments)
        
        let output = await ProcessExecutor.run(
            executableURL: URL(fileURLWithPath: executable.rawValue),
            arguments: sanitizedArgs,
            timeout: timeoutSeconds
        )
        
        return CommandExecutionResult(
            exitCode: output.exitCode,
            stdout: output.standardOutput,
            stderr: output.exitCode == -1 ? "Çalıştırma hatası: \(output.standardError)" : output.standardError,
            durationMs: output.durationMs
        )
    }

    static func sanitizedArguments(_ arguments: [String]) -> [String] {
        arguments.filter { arg in
            !arg.contains(";") && !arg.contains("|") && !arg.contains("&") && !arg.contains("`") && !arg.contains("$")
        }
    }
}
