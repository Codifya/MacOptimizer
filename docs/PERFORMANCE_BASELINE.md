# MacOptimizer Pro — Performance Baseline

Baseline for the performance, memory and concurrency hardening pass. It is taken at commit `35dacca`
(MacOptimizer Pro 3.0.0), before any change.

> **Status note:** the "Before" data describes v3.0.0 and is kept as a historical record. Some
> features mentioned here, such as RAM purge, were removed later. See
> [PERFORMANCE_REPORT.md](PERFORMANCE_REPORT.md) for the current state.

## How this baseline was established

This pass was carried out in a Linux container, not on a Mac. That limits what can be measured:

| Method | What it can establish | Used for |
| --- | --- | --- |
| **Static analysis of the code** | Exact, deterministic counts: timers, sampling cadence, process spawns per hour, `@Published` writes per tick, which collections are unbounded | Polling, process spawns, publish rate, memory bounds |
| **Linux reproduction (Swift 6.0.3)** | Real behaviour of the Foundation-only code (`Process`, pipes, GCD, Swift concurrency) | Pipe deadlock, timeout behaviour |
| **Scheduler simulation** | Exact sampling counts over a simulated hour, with a fake clock and a fake sampler | Before/after sampling budget |
| **Instruments on a Mac** | RSS, CPU %, wakeups, thread count, launch time, SwiftUI body counts | Not available here, so marked `REQUIRES_INSTRUMENTS_VALIDATION` |

No RAM, CPU, launch-time or thread-count figure in this document was invented. Any metric that needs
a Mac with Instruments is marked `REQUIRES_INSTRUMENTS_VALIDATION`. `docs/PERFORMANCE_REPORT.md`
lists the exact Instruments runs that should fill those cells.

## Summary table

| Metric | Before | Target | After |
| --- | ---: | ---: | ---: |
| Idle RAM | REQUIRES_INSTRUMENTS_VALIDATION | Flat plateau, no growth over 8 h | REQUIRES_INSTRUMENTS_VALIDATION |
| Monitoring RAM | REQUIRES_INSTRUMENTS_VALIDATION | Bounded by the fixed-capacity stores | REQUIRES_INSTRUMENTS_VALIDATION |
| Idle CPU | REQUIRES_INSTRUMENTS_VALIDATION | ≈ 0 % with the window hidden | REQUIRES_INSTRUMENTS_VALIDATION |
| Monitoring CPU | REQUIRES_INSTRUMENTS_VALIDATION | Constant cost per tick | REQUIRES_INSTRUMENTS_VALIDATION |
| Launch Time | REQUIRES_INSTRUMENTS_VALIDATION | Unchanged or better | REQUIRES_INSTRUMENTS_VALIDATION |
| Thread Count | REQUIRES_INSTRUMENTS_VALIDATION | No thread parked per child process | REQUIRES_INSTRUMENTS_VALIDATION |
| Process Spawn Rate (`/bin/ps`), dashboard visible | **480 / h** (static analysis) | ≤ 480 / h | **480 / h** (simulation) |
| Process Spawn Rate, other screen visible | **480 / h** | 0 | **0 / h** |
| Process Spawn Rate, window hidden, watchdog on | **480 / h** | ≤ 240 / h | **180 / h** |
| Process Spawn Rate, window hidden, watchdog off | **480 / h** | 0 | **0 / h** |
| Sampling cycles / h (window hidden, watchdog off) | **1 440** | ≤ 60 | **60** |
| `AppState.objectWillChange` per metrics tick | **7** (whole UI invalidated) | 0 | **0** (the metrics store publishes only changed values) |
| Unowned `Task`s created per tick | **2** (Timer → `Task` → `refreshMetrics` `Task`) | 0 | **0** (one owned loop) |
| Unbounded in-memory collections | **4** (alerts, chat, history, telemetry fetch) | 0 | **0** |
| `ps`-sized output (> 64 KB) through the command runner | **Hangs until timeout** (reproduced) | Completes | **4 ms for 200 KB** (measured) |

## 1. Polling inventory (before)

| # | Mechanism | Location | Interval | Pauses when hidden? | Work per fire |
| - | --- | --- | --- | --- | --- |
| 1 | `Timer.scheduledTimer` | `AppState.startMonitoring` | 2.5 s | **No** | Spawns a `Task`, which calls `refreshMetrics`, which spawns another `Task` |
| 2 | Tick → `fetchMemoryStats` | `SystemMonitorService` | 2.5 s | No | `mach_host_self()`, `host_statistics64`, `sysctl vm.swapusage` |
| 3 | Tick → `fetchCPUStats` | `SystemMonitorService` | 2.5 s | No | `mach_host_self()`, `host_statistics`, **2–4 `sysctlbyname` for the static CPU brand string** |
| 4 | Tick → `fetchDiskStats` | `SystemMonitorService` | 2.5 s | No | URL resource values, including `volumeAvailableCapacityForImportantUsage` (computes purgeable space) |
| 5 | Tick → `fetchBatteryStats` | `SystemMonitorService` | 2.5 s | No | `IOPSCopyPowerSourcesInfo` plus **a full `AppleSmartBattery` IORegistry property dictionary** |
| 6 | Tick → `fetchNetworkStats` | `SystemMonitorService` | 2.5 s | No | `getifaddrs` walk |
| 7 | Tick → `fetchHardwareInfo` | `SystemMonitorService` | 2.5 s | No | **Static model/chip/OS strings recomputed every tick**, plus uptime |
| 8 | Every 3rd tick → `fetchRunningProcesses` | `SystemMonitorService` | 7.5 s | No | **Spawns `/bin/ps -axo …`** and parses ~500–800 lines |
| 9 | Tick → `AutonomousGuardService.evaluateCycle` | `AppState` | 2.5 s | No (runs even when the watchdog is off, returning early) | Rule evaluation. The runaway rule counted the **cached** process list 3× |
| 10 | `onChange(of: cpu)` | `TelemetryHistoryCard` | 2.5 s | Stops only when off screen | Appends to view-local `@State`; history is lost on navigation |
| 11 | `repeatForever` animation | `AutonomousGuardView` | 60–120 fps | Stops only when off screen | Pulsed even when the watchdog was disabled |

All seven samplers (#2–#8) shared one timer, which is good. But nothing was **tiered**, nothing
**paused**, and no tier was **skipped when unused**. For example, `ps` ran while the user sat on the
Settings screen, or with every window closed.

### Derived hourly budget (before, any visibility state)

| Work item | Per hour |
| --- | ---: |
| Scheduler cycles | 1 440 |
| `/bin/ps` spawns | 480 |
| `AppleSmartBattery` IORegistry dictionary reads | 1 440 |
| Static `sysctlbyname` string reads (CPU brand ×2 paths, model) | ≥ 5 760 |
| `mach_host_self()` send rights acquired and never released | 2 880 |
| Unowned `Task` allocations | 2 880 |
| `AppState.objectWillChange` emissions from metrics | ≈ 10 080 |
| Telemetry rows persisted for the History screen | **0** (`TelemetryStore.record` was never called, so the History chart was always empty) |

## 2. Process execution inventory (before)

| Command | Call site | Frequency | Runner | Issues |
| --- | --- | --- | --- | --- |
| `/bin/ps -axo pid,rss,%cpu,comm` | `SystemMonitorService` | 7.5 s, forever | `SystemCommandRunner` | Output often exceeds 64 KB, which triggers the **pipe deadlock** below |
| `brew outdated --cask --json=v2` | `AppUpdateCheckerService` | On demand | `SystemCommandRunner` | Large JSON, so the same deadlock applies |
| `zsh -c <string from update metadata>` | `AppUpdatesView` | On click | `SystemCommandRunner.runShell` | **Shell injection**: a remote Sparkle appcast could set `downloadURL` to `brew …; <cmd>`. It also used a 15 s timeout for a real download, and `brew` is not on a GUI app's `PATH` |
| `/usr/sbin/purge`, `/bin/kill` | `MemoryOptimizerService` | On demand | `SystemCommandRunner` | — |
| `dscacheutil`, `killall`, `qlmanage`, `lsregister`, `mdutil`, `csrutil`, `spctl`, `defaults`, `launchctl` | Maintenance, privacy audit, startup manager | On demand | `SandboxedCommandRunner` | Same pipe deadlock. No SIGKILL escalation |

### P0: pipe-buffer deadlock (reproduced)

- **`SystemCommandRunner`** called `process.waitUntilExit()` **before** reading stdout or stderr. It
  also parked a GCD thread while waiting.
- **`SandboxedCommandRunner`** read the pipes only inside `terminationHandler`.

In both cases, a child that writes more than the kernel pipe buffer (64 KB) blocks in `write(2)` and
never exits. Only the timeout's SIGTERM releases it, and a child that ignores or blocks SIGTERM is
never released at all.

The original `SystemCommandRunner.swift` was compiled unmodified with Swift 6.0.3 on Linux and run
against `/usr/bin/head -c N /dev/zero` with `timeoutSeconds: 3.0`:

| Output size | Result |
| ---: | --- |
| 20 000 B | exit 0, 20 000 B, **0.01 s** |
| 200 000 B | **Did not return. Killed by the harness after 25 s** (the 3 s timeout never took effect on Linux) |

On macOS the SIGTERM does take effect, so the same call hangs for the full timeout. It then returns
exit `-2` with the output discarded. For `ps` (3 s timeout) this means that on a Mac with enough
processes, every process refresh stalled for 3 s and fell back to the stale cache.

## 3. Memory inventory (before)

| Holder | Growth | Bound |
| --- | --- | --- |
| `AppState.autonomousAlerts` | +1 per unique alert per 30 s | **None** |
| `AppState.chatMessages` | +2 per chat turn | **None** (only the last 6 were sent to the model) |
| `AppState.optimizationHistory` | +1 per operation, persisted to `UserDefaults` | **None**, and the whole array was JSON-encoded on every add |
| `TelemetryStore.fetchHistory` | Every raw row in the window materialised | O(rows): up to 69 120 rows for 48 h at 2.5 s |
| Directory enumeration on background threads | Autoreleased `NSURL` + resource-value dictionaries | Held until the thread's pool drained; no `autoreleasepool` in the size walks |
| Duplicate-scan progress | 1 MainActor `Task` per hashed file | O(files) tasks queued on the main actor |
| App icons | `NSWorkspace.icon(forFile:)` inside `body` | New `NSImage` per row per render, no cache |
| `mach_host_self()` | 2 send rights per tick | Kernel-side port reference growth for the whole session |
| `TelemetryHistoryCard.samples` | Capped at 30 (fine) | But view-local, seeded with 10 fake points on every appearance |

## 4. Concurrency inventory (before)

| Risk | Where | Severity |
| --- | --- | --- |
| Pipe deadlock (above) | Both command runners | **P0** |
| Overlapping refresh cycles: every tick spawned an unowned `Task`, with no in-flight guard. A slow `ps` or auto-purge (≥ 0.5 s) let cycles pile up and race on `AppState` assignment order | `AppState.refreshMetrics` | **P0** |
| "Parallel" `TaskGroup` scans serialised on an actor: `JunkCleanerService`, `AppScannerService` and `DuplicateFileFinderService` did blocking I/O **on actor executors**, parking cooperative-pool threads for whole scans | Scanner services | **P0** (starvation / UI stalls) |
| Cross-actor head-of-line blocking: the app scanner and uninstaller sized bundles via `JunkCleanerService.calculateSize`, so they queued behind a running junk scan | `AppScannerService`, `AppUninstallerService` | P1 |
| `checkAllAppUpdates()` right after `scanApps()` (dashboard quick action) checked the **empty** app list | `AppState` | P1 (logic race) |
| No cancellation anywhere: scans could not be stopped, and navigating away left them running | All scanners | P1 |
| Locks, semaphores, `DispatchQueue.sync`, `DispatchGroup.wait` | — | None found |

## 5. Rendering inventory (before)

- `AppState` was a single `ObservableObject` with about 60 `@Published` properties, including all live
  metrics. `MainView` (sidebar plus router), `MenuBarView` and the visible detail screen all observed
  it. Every 2.5 s tick therefore re-evaluated the sidebar `List`, the current screen and the menu bar
  view, whether or not they displayed a metric. That included Settings, the App Manager (re-running
  its filter and sort over all apps) and the Junk Cleaner.
- `AppManagerView.filteredApps` filtered and sorted inside `body` on every tick.
- `NSWorkspace.icon(forFile:)` was called inside row bodies.
- The `repeatForever` radar animation ran regardless of state.
