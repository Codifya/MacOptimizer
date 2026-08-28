# 🗺️ MacOptimizer Pro Roadmap

This roadmap outlines the past milestones and future evolution of MacOptimizer Pro toward version 3.0+.

---

## 🎯 Release Milestones

### `v2.0 — Production Native Core (Completed)`
- [x] Native SwiftUI Liquid Glass user interface.
- [x] Darwin Mach kernel telemetry (`host_statistics64`, `sysctlbyname`).
- [x] Microsecond-level binary Mach-O architecture detector.
- [x] Concurrent multi-category junk scanner with `TaskGroup`.
- [x] Deep app uninstaller & orphan cache detector.
- [x] Sparkle RSS and Homebrew update checker.
- [x] 7/24 Autonomous background watchdog.
- [x] NVIDIA NIM cloud AI Copilot integration.
- [x] Fully responsive layout for 13" laptops to 5K monitors.

---

### `v2.1 — Security Hardening & Open Source Ready (Completed)`
- [x] **Zero-Harm Policy Engine**: Modular `PathProtectionPolicy`, `ProcessProtectionPolicy`, `ApplicationProtectionPolicy`, and `LaunchItemProtectionPolicy`.
- [x] **Symlink Traversal Attack Protection**: Path canonicalization using `URL.resolvingSymlinksInPath()`.
- [x] **Operation Risk Classification**: `.safe`, `.low`, `.medium`, `.destructive`, and `.forbidden` classification.
- [x] **Dry-Run Plan Engine**: `CleaningPlan` preview lifecycle before any disk modifications.
- [x] **Keychain Secret Management**: Encrypted API key storage via macOS `Security.framework`.
- [x] **Sandboxed Command Runner**: Whitelisted binaries only with 15s watchdog timeout.
- [x] **Multi-Provider AI Platform**: Decoupled `AIProvider` supporting Local Heuristics, Ollama, NVIDIA NIM, and OpenAI endpoints.
- [x] **Telemetry Store**: Embedded SQLite database with WAL mode for time-series metrics.
- [x] **Massive Test Suite**: 23+ unit test suites with 120+ assertions passing.
- [x] **Open Source Guidelines**: Apache-2.0 License, `SECURITY.md` with STRIDE model, `CONTRIBUTING.md`, `ARCHITECTURE.md`, and `PRIVACY.md`.

---

### `v2.2 — Observability Charts & Advanced Telemetry (Upcoming)`
- [ ] Swift Charts integration for 1h, 24h, 7d, and 30d historical telemetry graphs.
- [ ] Thermal throttling and fan speed monitoring via IOKit.
- [ ] Network bandwidth per-process monitor.
- [ ] Disk IO read/write throughput metrics.

---

### `v3.0 — Production Distribution & Enterprise Pipeline (Target)`
- [ ] Automated GitHub Actions release pipeline with Apple Developer ID code signing.
- [ ] Apple Notarization via `xcrun notarytool` and ticket stapling.
- [ ] Compressed DMG installer generation.
- [ ] SPDX Software Bill of Materials (SBOM) generation.
- [ ] GitHub Artifact Attestation for verifiable supply-chain security.
- [ ] Modular plugin & custom automation rule engine.
