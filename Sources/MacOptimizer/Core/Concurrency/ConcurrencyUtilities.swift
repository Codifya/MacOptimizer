import Foundation

// MARK: - Timeout

public struct OperationTimeoutError: Error, Equatable, Sendable {
    public let seconds: TimeInterval
}

/// Runs `operation` and throws `OperationTimeoutError` if it has not finished within `seconds`.
/// The operation is cancelled on timeout, so it must be cancellation-cooperative to stop promptly.
public func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            throw OperationTimeoutError(seconds: seconds)
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw CancellationError()
        }
        return result
    }
}

// MARK: - Cancellation flag

/// Thread-safe flag that lets synchronous (non-async) work observe Swift task cancellation.
public final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
    }
}

// MARK: - Blocking work bridge

/// Runs synchronous, potentially long blocking work (directory traversal, hashing, plist parsing)
/// on a GCD global queue instead of the Swift cooperative thread pool.
///
/// The cooperative pool only has one thread per core; parking those threads in `readdir`/`read`
/// starves every other async task in the app (including metrics sampling). GCD can grow its pool for
/// blocking work. Task cancellation is forwarded through `CancellationFlag`, which the work polls.
public func runBlocking<T: Sendable>(
    qos: DispatchQoS.QoSClass = .utility,
    _ work: @escaping @Sendable (CancellationFlag) -> T
) async -> T {
    let flag = CancellationFlag()
    return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: qos).async {
                continuation.resume(returning: work(flag))
            }
        }
    } onCancel: {
        flag.cancel()
    }
}

// MARK: - Progress throttling

/// Coalesces high-frequency progress callbacks (one per file, thousands per second) into at most
/// one delivery per `interval`. The final (>= 1.0) update is always delivered.
/// Previously every callback spawned its own MainActor Task, flooding the main thread during scans.
public final class ProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private let interval: TimeInterval
    private var lastDelivery: TimeInterval = -.infinity
    private let sink: @Sendable (String, Double) -> Void

    public init(interval: TimeInterval = 0.1, sink: @escaping @Sendable (String, Double) -> Void) {
        self.interval = interval
        self.sink = sink
    }

    public func report(_ message: String, _ progress: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        let isFinal = progress >= 1.0
        let shouldDeliver = isFinal || now - lastDelivery >= interval
        if shouldDeliver { lastDelivery = now }
        lock.unlock()
        if shouldDeliver { sink(message, progress) }
    }

    /// Convenience adaptor matching the services' `progressHandler` parameter type.
    public var handler: @Sendable (String, Double) -> Void {
        { [self] message, progress in self.report(message, progress) }
    }
}
