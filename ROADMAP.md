# Roadmap

This roadmap lists what is done and what comes next. Items move to done only when they are
merged and covered by the test suite or verified on macOS.

## History

v2.1.0 to v3.0.0 were published on 2026-08-28. They added the features the app still has
(telemetry, junk cleaner, uninstaller, duplicate finder, startup items, update checks, security
overview, watchdog, AI assistant, CLI), but a later audit found serious defects in them: a command
injection in the update screen, deletion paths without preview or confirmation, results reported
as successful when commands failed, and documentation that claimed more than the code did. Do not
use those releases.

## v3.1.0 — Safety release (in progress)

Done (merged to `main`):

- [x] Command injection removed: no shell execution; Homebrew runs directly with a validated token.
- [x] One deletion pipeline: plan preview, enforced confirmation, re-validation, Trash by default.
- [x] Honest results: real exit codes, RAM purge removed, security score without free points,
      fixed battery health formula, no invented chart data.
- [x] AI assistant: local heuristics by default; NVIDIA NIM only after a disclosure; app names
      only with a separate opt-in; unused providers removed.
- [x] Monitoring, process execution and scanner hardening (bounded memory, no pipe deadlocks,
      cancellable parallel scans, telemetry history recorded).
- [x] Hermetic test suite run in full by CI on macOS with Swift 6.
- [x] English and Turkish localization, following the system language.
- [x] Documentation aligned with the code.

Remaining:

- [ ] One version source for the app, the CLI and the release tag.
- [ ] Developer ID signing, hardened runtime, notarization and stapling of the DMG.

## Later (not scheduled)

- Split `AppState` into smaller feature models and inject services.
- Merge `Helpers/SafetyGuard` into the `Core/Security` policies.
- App icon, and applying the menu bar extra setting.
- Verify Homebrew update detection against current `brew` JSON output.
- Instruments measurements for the figures still marked `REQUIRES_INSTRUMENTS_VALIDATION` in
  [docs/PERFORMANCE_BASELINE.md](docs/PERFORMANCE_BASELINE.md).
