# 📝 Changelog

All notable changes to **MacOptimizer Pro** are documented in this file following the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) standard.

---

## [2.1.0] - 2026-08-28

### Added
* **Zero-Harm Security Policy Engine**: Refactored monolithic safety validation into modular policy evaluators (`PathProtectionPolicy`, `ProcessProtectionPolicy`, `ApplicationProtectionPolicy`, `LaunchItemProtectionPolicy`, `SafetyPolicyEngine`).
* **Symlink Resolution & Traversal Guard**: Integrated `URL.resolvingSymlinksInPath()` into path evaluation to neutralize symlink-based data loss attacks.
* **Operation Risk Classifier**: Introduced `OperationRisk` enum (`.safe`, `.low`, `.medium`, `.destructive`, `.forbidden`) to classify every user or automated action before execution.
* **Dry-Run Cleaning Engine**: Added `CleaningPlan` supporting two-phase preview, byte estimation, and user confirmation.
* **macOS Keychain Integration**: Created `KeychainManager` utilizing `Security.framework` for encrypted credential storage and automatic migration from `UserDefaults`.
* **Multi-Provider AI Architecture**: Added `AIProvider` protocol supporting `LocalHeuristicProvider` (100% offline), `OllamaProvider` (local LLMs), `NvidiaNIMProvider` (cloud), and `OpenAICompatibleProvider`.
* **Sandboxed Command Runner**: Whitelist-only execution mechanism with argument sanitization and 15s watchdog protection.
* **SQLite Telemetry Store**: High-concurrency WAL-mode SQLite time-series storage for system performance metrics.
* **Expanded Test Suite**: 23 test suites containing 120+ property-based assertions covering path protection, symlink attacks, daemon protection, dry-run plans, and AI providers.
* **Open Source Governance**: Added Apache-2.0 License, `SECURITY.md` (STRIDE threat model), `CONTRIBUTING.md`, `ARCHITECTURE.md`, `PRIVACY.md`, `ROADMAP.md`, and `BENCHMARKS.md`.

---

## [2.0.0] - 2026-08-28

### Added
* **Native Liquid Glass UI**: Modern macOS Sonoma/Sequoia aesthetic with responsive grid layouts.
* **Microsecond Mach-O Header Parser**: Direct binary header inspection without spawning `lipo` subprocesses.
* **Parallel Junk Scanner**: Concurrent file system analysis using Swift `TaskGroup`.
* **Deep App Uninstaller**: Discovery of orphaned caches and preferences across `~/Library`.
* **Autonomous Guard**: 7/24 background watchdog detecting runaway processes and memory pressure.
* **Sparkle & Homebrew Updater**: Real-time update checks for installed applications.
* **macOS Maintenance Scripts**: QuickLook cache reset, DNS flush, Spotlight reindexing, and safe RAM release.
