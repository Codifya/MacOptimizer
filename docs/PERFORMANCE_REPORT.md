# MacOptimizer Pro — Performance, Memory & Concurrency Hardening Report

Companion to [`PERFORMANCE_BASELINE.md`](PERFORMANCE_BASELINE.md), which has the method and the
"before" data.

> **Status note:** this report was written for the hardening pull request (#1), which was prepared
> on Linux. That pull request was later built and tested on macOS before it was merged, and CI now
> runs the full suite on macOS. Later changes are reflected in the "Remaining risks" section: RAM
> purge was removed (#5) and the first CPU sample no longer uses a placeholder (#5).

**Evidence levels used below**

- **Measured**: executed with Swift 6.0.3 on Linux against the shipping source files.
- **Simulated**: the production scheduler driven by a fake clock and a fake sampler.
- **Static**: derived exactly from the code.
- `REQUIRES_INSTRUMENTS_VALIDATION`: needs a Mac. The runs to do this are listed at the end.

## Executive summary

The app sampled everything every 2.5 s, whether or not anyone was looking. Each tick invalidated the
whole SwiftUI tree, and child processes went through a runner that deadlocks on outputs larger than
64 KB. Its "parallel" scans were serialised on actors while blocking the cooperative thread pool.
Several collections grew without limit.

This pass does the following:

1. **One owned monitoring loop** (`MonitoringCoordinator`) replaces the timer and its unowned
   per-tick Tasks. Cycles can no longer overlap.
2. **Tiered, demand-driven sampling.** Each tier has its own interval. `ps` runs only when a screen
   or the watchdog consumes it. When the window is hidden, sampling drops from 2.5 s to 10 s
   (watchdog on) or 60 s (idle).
3. **Metric state isolated** in `LiveMetricsStore`. A metrics tick no longer touches `AppState`, and
   unchanged values publish nothing.
4. **A single hardened child-process executor** (`ProcessExecutor`): concurrent pipe draining,
   bounded output, SIGTERM→SIGKILL escalation, cancellation, and no parked threads. Both command
   runners use it.
5. **Scanners are truly parallel and cancellable.** Blocking I/O moved off the cooperative pool, with
   autorelease pools per 256 entries and a 64 KB partial-hash prefilter for duplicates.
6. **Every long-lived collection is bounded**, and telemetry fetches are downsampled inside SQLite.
7. **Security fix found during the process audit**: remote update metadata could reach `zsh -c`.

## Architecture

**Previous**

```
Timer (2.5 s, never paused)
  └─ Task ─ refreshMetrics() ─ Task (unowned, may overlap)
        └─ SystemMonitorService: mem, cpu, disk, battery, net, hw, (ps every 3rd tick)
        └─ AutonomousGuardService.evaluateCycle
        └─ AppState (@Published ×7) ─► every observing view re-renders
```

**New**

```
AppState (@MainActor, user-driven state only)
  ├─ MonitoringDemand ← selectedTab, NSApp occlusion/hide, watchdog on/off
  ├─ MonitoringCoordinator (@MainActor, single owned loop, weak self)
  │     ├─ MetricsSchedulePolicy (pure): which tiers are due, tick length
  │     ├─ SystemMetricsSampling  ← SystemMonitorService (actor)
  │     └─ handler ─► LiveMetricsStore.apply (publishes changed values only)
  │                ├─► TelemetryStore.recordAndPrune (60 s tier)
  │                └─► AutonomousGuardService (fresh-process flag)
  └─ metrics: LiveMetricsStore ─► only metric leaf views observe it

Blocking work ─► runBlocking (GCD, cancellation flag) ─► FileSizeCalculator / scanners
Child processes ─► ProcessExecutor (poll(2) reader, output cap, timeout, SIGKILL, cancel)
```

### Monitoring tiers

| Tier | Class | Visible | Hidden + watchdog | Hidden, idle |
| --- | --- | ---: | ---: | ---: |
| `core` (memory, CPU, network) | CRITICAL | 2.5 s | 10 s | 60 s |
| `disk` | NORMAL | 30 s | 30 s* | 60 s* |
| `battery` | NORMAL | 30 s | 120 s | 120 s |
| `telemetry` (SQLite row) | NORMAL | 60 s | 60 s | 60 s |
| `hardware` (uptime; identity is static) | UI_ONLY | 60 s | off | off |
| `processes` (`/bin/ps`) | UI_ONLY (+ watchdog) | 7.5 s on Dashboard/Memory, otherwise off | 20 s | off |

\* A tier's interval is quantised up to the tick length.

Menu bar monitoring keeps working: the `MenuBarExtra` popover is an app window, so opening it marks
the app visible and restores the 2.5 s cadence immediately (`updateDemand` wakes the sleeping loop).

## Memory

| Issue | Fix | Bound after |
| --- | --- | --- |
| `autonomousAlerts` unbounded | `prependBounded` | 200 |
| `chatMessages` unbounded | `appendBounded` | 100 |
| `optimizationHistory` unbounded (persisted) | `prependBounded` on add and load | 500 |
| Live chart history held as view `@State`, reseeded with 10 fake points on every appearance | `RingBuffer` in `LiveMetricsStore` | 30 samples. Monotonic `Int` ids, no per-sample UUID |
| `fetchHistory` materialised every row in the window | `GROUP BY` bucket downsampling in SQL | `maxPoints` rows (verified with sqlite3: 48 h of rows → 50) |
| Telemetry DB growth | 60 s recording, pruning at most hourly (`recordAndPrune`) | ≈ 2 880 rows (48 h) |
| Autoreleased objects during directory walks on GCD threads | `autoreleasepool` per 256 entries (`FileSizeCalculator.entriesPerPool`) | One slice of objects |
| One MainActor `Task` per hashed or cleaned file | `ProgressThrottle` (≤ 10 deliveries/s, final always delivered) | **Measured**: 100 000 reports → 2 deliveries |
| Icon `NSImage` per row per render | `AppIconCache` (`NSCache`, `countLimit` 256, 64 pt) | 256, and evicts under memory pressure |
| `mach_host_self()` ×2 per tick without deallocation | Acquired once (`static let hostPort`) | 1 |
| Child process output retained without limit | `ProcessExecutor` `outputLimit` (default 4 MB, `ps` 2 MB) | **Measured**: 20 MB output → 1 MB kept, child still completes |
| Watchdog PID tracker | Filtered to currently hot PIDs every fresh sample | Number of hot processes |

Before and after RSS figures: `REQUIRES_INSTRUMENTS_VALIDATION` (see Allocations / VM Tracker runs).

## CPU / energy

| Work item per hour | Before (static) | After, Dashboard visible (simulated) | After, other screen visible | After, hidden + watchdog | After, hidden idle |
| --- | ---: | ---: | ---: | ---: | ---: |
| Scheduler cycles | 1 440 | 1 440 | 1 440 | 360 | **60** |
| `/bin/ps` spawns | 480 | 480 | **0** | **180** | **0** |
| Disk capacity lookups | 1 440 | 120 | 120 | 120 | 60 |
| Battery IORegistry dictionary reads | 1 440 | 120 | 120 | 30 | 30 |
| Hardware sampling | 1 440 | 60 | 60 | 0 | 0 |
| Static `sysctl` string reads | ≥ 5 760 | once per launch | once | once | once |
| `AppState.objectWillChange` from metrics | ≈ 10 080 | **0** | 0 | 0 | 0 |
| Unowned Task allocations | 2 880 | 0 | 0 | 0 | 0 |

Other CPU work removed:

- **`ps` parsing**: header suppressed via `pid=,…`; `Substring` splitting instead of
  `components(separatedBy:)` plus `trimmingCharacters` per line; capacity reserved.
- **Duplicate hashing**: files with equal size but a different first 64 KB are no longer read end
  to end. Only size **and** prefix collisions get a full SHA-256. **Measured**: files differing only
  in the last byte, or only in the first byte, are both classified correctly.
- **`SafetyGuard.protectedUserPaths`** is built once instead of on every path check.
- **App scan** de-duplication is O(1) (`Set`) instead of `Array.contains`.
- **Autonomous Guard pulse** animates only while the watchdog is active, and never with Reduce Motion.

CPU % before and after: `REQUIRES_INSTRUMENTS_VALIDATION`.

## Concurrency

### Risks found and eliminated

| Risk | Resolution | Evidence |
| --- | --- | --- |
| **P0: pipe deadlock** in both runners (`waitUntilExit` before reading; reading only in `terminationHandler`) | `ProcessExecutor`: one GCD reader drains stdout and stderr with `poll(2)`/`read(2)` while the child runs | **Measured**: 200 KB in 4 ms (old runner: hang); 64 concurrent runs correct in 0.05 s |
| **P0**: timeout ineffective against a child that ignores or blocks SIGTERM | SIGTERM, then SIGKILL after 2 s | **Measured**: TERM-ignoring child reaped in 2.3 s |
| **P0**: overlapping refresh cycles | Single loop; `refreshNow` only wakes it; `start()` is idempotent | **Measured**: `start()` ×3 plus 20 `refreshNow` → max 1 cycle in flight |
| **P0**: blocking I/O on actor executors / the cooperative pool (thread starvation) | `runBlocking` moves directory walks, hashing, plist parsing and deletions onto GCD. Scanner services became stateless `Sendable` classes | Swift 6 strict-concurrency typecheck of all non-UI sources |
| Cross-actor head-of-line blocking (app scanner → junk actor) | Shared stateless `FileSizeCalculator` | — |
| `checkAllAppUpdates` racing `scanApps` | Awaits the in-flight `appScanTask` | — |
| No cancellation | Owned `junkScanTask`, `duplicateScanTask` and `appScanTask`; cancel buttons for junk and duplicate scans; `CancellationFlag` polled per file or pool slice | **Measured**: cancelled duplicate scan and size walk return immediately; `runBlocking` observes cancellation in < 1 s |
| Continuation resumed twice or never | `Execution.finish` is idempotent under the lock; launch failure and pre-launch cancellation resume exactly once | **Measured**: missing-executable and cancel paths |
| Watchdog counted a single cached `ps` sample as three consecutive readings | `processesAreFresh`; the streak resets when a process cools down | Unit tests |

### Lock inventory (after)

| Lock | Owner | Protects | Nesting | Callbacks under lock |
| --- | --- | --- | --- | --- |
| `NSLock` | `ProcessExecutor.Execution` | Output buffers, lifecycle flags, continuation | Never nested | None: `Process`, `kill` and `continuation.resume` all run after unlock |
| `NSLock` | `CancellationFlag` | One `Bool` | Leaf | None |
| `NSLock` | `ProgressThrottle` | Last-delivery timestamp | Leaf | None: the sink runs after unlock |

There is no `DispatchSemaphore`, `DispatchQueue.sync`, `DispatchGroup.wait`, `waitUntilExit`,
`Timer`, `Task.detached` or `while true` anywhere in `Sources/` (verified by grep). No path has the
main actor wait synchronously on background work: every bridge is an `async` continuation.

### Task lifecycle

| Long-lived work | Owner | Stop condition |
| --- | --- | --- |
| Monitoring loop | `MonitoringCoordinator.loopTask` | `stop()`, task cancellation, or coordinator deallocation (weak capture; **measured**) |
| Loop sleep | `MonitoringCoordinator.sleeper` | Cancelled by `wake()`, `stop()` or loop cancellation |
| Junk, duplicate and app scans | `AppState.*ScanTask` | `cancel*Scan()`; they also check `Task.isCancelled` before publishing |
| Child processes | `ProcessExecutor` call | Exit, timeout (TERM→KILL) or task cancellation |
| Pipe reader | `Execution.startReader` | EOF on both pipes, or ≤ 100 ms after the result is final |
| Visibility observers | `AppState.visibilityObservers` | Removed in `stopMonitoring()` |

## UI

**Rendering**

- `DashboardView` observes `AppState` only. Five metric-observing subviews
  (`DashboardHardwareHeader`, `DashboardGaugesGrid`, `DashboardLiveDetailCards`,
  `LiveTopProcessesCard` and `TelemetryHistoryCard`) re-render on ticks. The AI banner, hero card and
  quick actions do not.
- In the sidebar, only `SidebarMemoryBadge` and `SidebarAvailableMemoryText` observe metrics. The
  navigation `List` no longer rebuilds every 2.5 s.
- `MenuBarView` observes `LiveMetricsStore` for metrics and `AppState` for app state.
- Screens that show no metrics (Settings, App Manager, Junk Cleaner, Startup, Security, History,
  Updates, AI) no longer re-evaluate on metrics ticks. That removes, for example, the App Manager's
  per-tick filter and sort over all installed apps.
- `TopProcessesCard` receives five rows instead of the full process array.
- The chart and history rows use stable ids (no `UUID()` during rendering).

**Responsive layout**

- Dashboard header badges fall back through `ViewThatFits`: full → model plus thermal → model only.
- Live telemetry card: the title and a fixed 220 pt picker become a flexible
  (`min 200 / ideal 240 / max 280`) picker, stacking vertically in narrow windows.
- History picker: fixed 260 pt becomes flexible (`min 180 / ideal 260 / max 280`).
- Existing adaptive `LazyVGrid`s (gauges 155 pt, banners 270 pt, bottom 320 pt) are kept as the
  dashboard breakpoints: 1 column in narrow windows, 2 in medium, 3–4 in wide.

## Background processing summary

| | Before | After |
| --- | --- | --- |
| Polling loops | 1 timer with 7 samplers, never paused | 1 owned loop, 6 independently scheduled tiers, visibility-aware |
| `ps` spawns / h | 480 always | 0–480 depending on demand (table above) |
| Persisted telemetry | none (feature silently broken) | 1 row / min, pruned beyond 48 h |
| Scan progress deliveries | 1 main-actor Task per file | ≤ 10 / s |

## Security (found during the process audit)

- The update button passed `updateInfo.downloadURL` to `zsh -c` whenever it started with `"brew "`.
  That value can come from a **remote Sparkle appcast**, which made it a command injection. It is now
  fixed:
  - `SystemCommandRunner.runShell` is removed.
  - Homebrew upgrades run `brew` directly, only for `updateSource == .homebrew`, with the cask token
    validated against `[a-z0-9@._+-]`.
  - The timeout is 900 s and output is capped at 256 KB.
  - Non-Homebrew links open only for `http`/`https` schemes.
- `brew outdated` now runs with `HOMEBREW_NO_AUTO_UPDATE=1` and a 30 s timeout.

## Tests

- **New**: `Tests/MacOptimizerTests/PerformanceHardeningTests.swift`, with 29 tests:
  - bounds: ring buffer, bounded arrays, chart history, unchanged-value publishing, declared caps;
  - process execution: large output, output cap, timeout, TERM-ignoring child, cancellation, missing
    binary, 32 concurrent runs;
  - `withTimeout`, `runBlocking` cancellation and `ProgressThrottle`;
  - scheduler: spawn budget over a simulated hour, idempotent start with no overlap, stop, release
    ends the loop, navigation does not multiply workers;
  - watchdog: stale-sample and streak-reset rules;
  - duplicate finder correctness and cancellation, and the size walk across pool slices;
  - cancelled junk scan, Homebrew token validation, and bounded telemetry history.
- **Linux validation run during this pass** (Swift 6.0.3, shipping sources):
  - concurrency harness 14/14, coordinator harness 13/13, duplicate and size harness 6/6;
  - the SQL downsampling query verified with sqlite3;
  - Swift 6 language-mode typecheck of every non-UI source file (with Linux shims for AppKit, IOKit
    and CryptoKit symbols) is clean.
- **Not run here**: the XCTest suite and the SwiftUI/AppKit targets need macOS. CI
  (`.github/workflows/ci.yml`, now macos-15 with Xcode 16.4) runs `swift build` and `swift test`.

## Remaining risks

1. **No macOS build was performed in this environment.** The SwiftUI and AppKit files
   (`AppState`, the views, `SystemMonitorService`, `TelemetryStore`, `AppIconView`) were only
   syntax-checked here. (Resolved: the pull request was built and tested on macOS before merge,
   and CI builds it on macOS.)
2. `ps` is still spawned while a process screen is visible (every 7.5 s). A `libproc`
   (`proc_listallpids`, `proc_pid_rusage`) implementation would remove the spawn, but it cannot read
   RSS or CPU of root-owned processes (for example `WindowServer`) without privileges, whereas setuid
   `ps` can. Revisit only with a privileged helper.
3. The first CPU sample reported a placeholder (15 %) until a delta existed. (Resolved in #5: CPU
   usage now needs two real samples.)
4. Visibility is app-level occlusion. A visible but fully covered main window counts as hidden,
   which is intended.
5. `MemoryOptimizerService.purgeMemory` allocated and touched up to 256 MB by design. (Resolved in
   #5: RAM purge was removed.)
6. `BENCHMARKS.md` numbers predated this pass and were not reproducible from the code. For example,
   the junk walk was serialised on an actor, not parallel. (Resolved: the numbers were removed.)

## Recommended Instruments runs

Run on a Release build (`./Scripts/build_app.sh`), on both Apple Silicon and Intel if available.

| Template | Scenario | What to record / pass criterion |
| --- | --- | --- |
| **Allocations** (with VM Tracker) | Launch, Dashboard visible 10 min; then hidden 10 min; then 50 cycles through every sidebar tab | Persistent bytes plateau after about 2 min; no per-tab growth; Generation analysis between navigation rounds ≈ 0 |
| **Allocations** | Junk scan + duplicate scan of a large home folder (≥ 200k files), then cancel mid-scan | Peak transient memory bounded (autorelease slices); returns to baseline after completion or cancel |
| **Leaks** | Same navigation loop; open and close the menu bar popover 50× | Zero leaks attributable to MacOptimizer |
| **Time Profiler** | Dashboard visible; Memory tab with search typing; App Manager with 300+ apps | Main thread < 5 % average at idle; no SwiftUI body time in non-metric screens during ticks |
| **SwiftUI** (View Body / View Properties) | Settings or App Manager visible for 60 s | ~0 body evaluations of those views per metrics tick |
| **Swift Concurrency** | Monitoring for 5 min, plus a junk scan | Task count stable; no growth in alive Tasks; no cooperative-pool thread blocked in I/O |
| **System Trace** | Window hidden, watchdog on / off, 15 min each | Wakeups ≈ 1 per 10 s (watchdog) / 1 per 60 s (idle); `ps` spawns 3/min and 0/min respectively |
| **Energy Log** (or `powermetrics --samplers tasks`) | Idle hidden 30 min | Energy impact ≈ 0; no timer wakeups at 2.5 s |
| **Activity Monitor / `footprint`** | 1 h, 8 h, 24 h left open on the Dashboard | RAM(8 h) ≈ RAM(1 h) within OS cache noise |

Record the results in the "After" column of `docs/PERFORMANCE_BASELINE.md`.
