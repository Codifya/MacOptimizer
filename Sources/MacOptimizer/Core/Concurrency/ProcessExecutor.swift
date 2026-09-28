import Foundation

/// Result of a child process run through `ProcessExecutor`.
public struct ProcessOutput: Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String
    public let isTimedOut: Bool
    public let isCancelled: Bool
    /// True when output exceeded the byte limit and the excess was discarded.
    public let isTruncated: Bool
    public let durationMs: Double

    public var isSuccess: Bool { exitCode == 0 && !isTimedOut && !isCancelled }
}

/// Single, hardened entry point for spawning child processes.
///
/// Guarantees (the previous runners violated the first three):
/// * stdout/stderr are drained concurrently by a poll(2) reader, so a child that
///   writes more than the 64 KB pipe buffer can never deadlock against us;
/// * retained output is capped (`outputLimit`), so a chatty child cannot grow our heap;
/// * a timeout sends SIGTERM and escalates to SIGKILL after a grace period, so a child that ignores
///   or blocks SIGTERM cannot hang the caller;
/// * Swift task cancellation terminates the child;
/// * no thread is ever parked waiting (no `waitUntilExit`, no semaphores) and the continuation is
///   resumed exactly once.
public enum ProcessExecutor {
    public static let defaultOutputLimit = 4 * 1024 * 1024
    static let killGracePeriod: TimeInterval = 2.0
    static let drainGracePeriod: TimeInterval = 0.25

    public static func run(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: TimeInterval,
        outputLimit: Int = defaultOutputLimit
    ) async -> ProcessOutput {
        let execution = Execution(outputLimit: outputLimit)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                execution.start(
                    executableURL: executableURL,
                    arguments: arguments,
                    environment: environment,
                    timeout: timeout,
                    continuation: continuation
                )
            }
        } onCancel: {
            execution.stop(reason: .cancelled)
        }
    }
}

/// Mutable state of one child process. All fields are guarded by `lock`; the lock is never held
/// while calling into Foundation/Process or resuming the continuation, so it cannot participate
/// in a lock-ordering cycle.
private final class Execution: @unchecked Sendable {
    enum StopReason { case timeout, cancelled }

    private let lock = NSLock()
    private let outputLimit: Int
    private let queue = DispatchQueue(label: "MacOptimizer.ProcessExecutor", qos: .utility)
    private let startTime = ProcessInfo.processInfo.systemUptime

    private let process = Process()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()

    // Guarded by `lock`
    private var stdoutData = Data()
    private var stderrData = Data()
    private var truncated = false
    private var streamsClosed = false
    private var terminated = false
    private var launched = false
    private var finished = false
    private var timedOut = false
    private var cancelled = false
    private var continuation: CheckedContinuation<ProcessOutput, Never>?
    private var timeoutTimer: DispatchSourceTimer?

    init(outputLimit: Int) {
        self.outputLimit = max(0, outputLimit)
    }

    func start(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        continuation: CheckedContinuation<ProcessOutput, Never>
    ) {
        lock.lock()
        self.continuation = continuation
        let alreadyCancelled = cancelled
        lock.unlock()

        if alreadyCancelled {
            finish(exitCode: -3, launchError: nil)
            return
        }

        process.executableURL = executableURL
        process.arguments = arguments
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        process.terminationHandler = { [weak self] _ in
            self?.didTerminate()
        }

        do {
            try process.run()
        } catch {
            finish(exitCode: -1, launchError: error.localizedDescription)
            return
        }

        startReader()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + max(0.05, timeout))
        timer.setEventHandler { [weak self] in self?.stop(reason: .timeout) }

        lock.lock()
        launched = true
        let cancelledDuringLaunch = cancelled
        timeoutTimer = timer
        lock.unlock()

        timer.resume()
        if cancelledDuringLaunch { stop(reason: .cancelled) }
    }

    /// Terminates the child (SIGTERM, then SIGKILL after a grace period).
    func stop(reason: StopReason) {
        lock.lock()
        switch reason {
        case .timeout: timedOut = true
        case .cancelled: cancelled = true
        }
        let shouldSignal = launched && !terminated
        lock.unlock()

        guard shouldSignal else { return }
        process.terminate()
        let pid = process.processIdentifier
        queue.asyncAfter(deadline: .now() + ProcessExecutor.killGracePeriod) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let stillRunning = !self.terminated
            self.lock.unlock()
            if stillRunning && pid > 0 { kill(pid, SIGKILL) }
        }
    }

    /// Drains stdout and stderr on one GCD thread using poll(2) + read(2).
    /// Unlike `readabilityHandler` this behaves identically on every platform, never parks a
    /// cooperative-pool thread, and can be abandoned (100 ms poll slices) once the result is final.
    private func startReader() {
        let outFD = stdoutPipe.fileHandleForReading.fileDescriptor
        let errFD = stderrPipe.fileHandleForReading.fileDescriptor
        DispatchQueue.global(qos: .utility).async { [self] in
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            var fds = [pollfd(fd: outFD, events: Int16(POLLIN), revents: 0),
                       pollfd(fd: errFD, events: Int16(POLLIN), revents: 0)]
            var open = [true, true]
            while open[0] || open[1] {
                if isAbandoned { break }
                for i in 0..<2 { fds[i].fd = open[i] ? (i == 0 ? outFD : errFD) : -1; fds[i].revents = 0 }
                let ready = poll(&fds, nfds_t(fds.count), 100)
                if ready < 0 {
                    if errno == EINTR { continue }
                    break
                }
                if ready == 0 { continue }
                for i in 0..<2 where open[i] && fds[i].revents != 0 {
                    let count = buffer.withUnsafeMutableBytes { read(fds[i].fd, $0.baseAddress, $0.count) }
                    if count > 0 {
                        append(buffer[0..<count], isStdout: i == 0)
                    } else if count == 0 || (errno != EINTR && errno != EAGAIN) {
                        open[i] = false
                    }
                }
            }
            readerDidFinish()
        }
    }

    private var isAbandoned: Bool {
        lock.lock(); defer { lock.unlock() }
        return finished
    }

    private func append(_ bytes: ArraySlice<UInt8>, isStdout: Bool) {
        lock.lock()
        let used = stdoutData.count + stderrData.count
        let room = max(0, outputLimit - used)
        if room < bytes.count { truncated = true }
        let accepted = bytes.prefix(room)
        if isStdout { stdoutData.append(contentsOf: accepted) } else { stderrData.append(contentsOf: accepted) }
        lock.unlock()
    }

    private func readerDidFinish() {
        lock.lock()
        streamsClosed = true
        let done = terminated
        lock.unlock()
        if done { finish(exitCode: nil, launchError: nil) }
    }

    private func didTerminate() {
        lock.lock()
        terminated = true
        let done = streamsClosed
        lock.unlock()

        if done {
            finish(exitCode: nil, launchError: nil)
        } else {
            // A grandchild may still hold the pipe open; never wait on it forever.
            queue.asyncAfter(deadline: .now() + ProcessExecutor.drainGracePeriod) { [weak self] in
                self?.finish(exitCode: nil, launchError: nil)
            }
        }
    }

    private func finish(exitCode forcedExitCode: Int32?, launchError: String?) {
        lock.lock()
        guard !finished, let continuation else {
            lock.unlock()
            return
        }
        finished = true
        self.continuation = nil
        let timer = timeoutTimer
        timeoutTimer = nil
        let out = stdoutData
        let err = stderrData
        let wasTruncated = truncated
        let wasTimedOut = timedOut
        let wasCancelled = cancelled
        let didTerminate = terminated
        stdoutData = Data()
        stderrData = Data()
        lock.unlock()

        timer?.cancel()

        let exitCode: Int32
        if let forcedExitCode {
            exitCode = forcedExitCode
        } else if wasTimedOut {
            exitCode = -2
        } else if wasCancelled {
            exitCode = -3
        } else {
            exitCode = didTerminate ? process.terminationStatus : -1
        }

        let stderrText = launchError ?? String(decoding: err, as: UTF8.self)
        continuation.resume(returning: ProcessOutput(
            exitCode: exitCode,
            standardOutput: String(decoding: out, as: UTF8.self),
            standardError: stderrText,
            isTimedOut: wasTimedOut,
            isCancelled: wasCancelled,
            isTruncated: wasTruncated,
            durationMs: (ProcessInfo.processInfo.systemUptime - startTime) * 1000.0
        ))
    }
}
