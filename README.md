# ⚡ MacOptimizer Pro

<div align="center">

![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B%20%28Sonoma%2FSequoia%29-blue?logo=apple&style=flat-square)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-purple?style=flat-square)
![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square)
![Security](https://img.shields.io/badge/Security-Zero--Harm%20Engine-red?logo=apple&style=flat-square)
![Tests](https://img.shields.io/badge/Tests-120%2B%20Passed-success?style=flat-square)

**Security-First, Open-Source, Native macOS System Health & Optimization Toolkit**

[Features](#-key-features) • [Zero-Harm Architecture](#-zero-harm-architecture) • [AI Platform](#-multi-provider-ai-platform) • [Benchmarks](#-performance-benchmarks) • [Installation](#-installation) • [Contributing](#-contributing)

</div>

---

## 📖 Overview

**MacOptimizer Pro** is an open-source, enterprise-grade system health, telemetry, and optimization toolkit crafted exclusively for macOS. Built purely in **Swift 5.9+** with **SwiftUI** and native **Darwin Mach Kernel APIs**, it delivers microsecond-level hardware telemetry, autonomous watchdog protection, and memory optimization without the bloat, battery drain, or questionable security practices of traditional cleaners.

---

## ✨ Key Features

* 📊 **Low-Overhead Telemetry**: Direct Darwin Mach kernel inspection (`host_statistics64`, `sysctlbyname`) for memory pressure, swap usage, CPU load, and battery health with near-zero CPU footprint.
* 🛡️ **Zero-Harm Defense-in-Depth**: Modular safety policy engine preventing accidental file deletion, symlink traversal attacks, and macOS system daemon termination.
* 🔍 **Two-Phase Dry-Run Cleaning**: Scans caches, developer build leftovers (Xcode `DerivedData`, CocoaPods, NPM, Yarn, Cargo), browser caches, and orphan app directories with complete preview and byte estimation before execution.
* 🚀 **Microsecond Binary Architecture Parser**: Direct Mach-O binary header inspection to distinguish Apple Silicon (ARM64), Universal, and Intel (x86_64) binaries without slow subprocess calls.
* 🤖 **Multi-Provider AI Copilot**: Decoupled AI diagnostic engine supporting **100% Offline Heuristics**, **Local Ollama LLMs**, and **Enterprise Cloud NIM** (Llama 3.3, DeepSeek R1).
* 🐕 **7/24 Autonomous Watchdog**: Background watchdog that detects memory spikes and runaway processes, offering auto-healing with user approval.
* 🔐 **Keychain Secret Storage**: Encrypted credential storage via native macOS `Security.framework`.
* 📱 **Liquid Glass Responsive UI**: Adaptive layouts scaling smoothly from 13" MacBook Airs up to 5K Studio Displays and Split View.

---

## 🛡️ Zero-Harm Architecture

MacOptimizer adheres to strict defense-in-depth principles:

```mermaid
graph TD
    UserAction["User or AI Trigger"] --> Risk["OperationRiskClassifier (safe / low / medium / destructive / forbidden)"]
    Risk --> Policy["SafetyPolicyEngine (Modular Security Rules)"]
    Policy --> Symlink["Symlink & Path Canonicalization (resolvingSymlinksInPath)"]
    Symlink --> DryRun["Dry-Run Preview (CleaningPlan)"]
    DryRun --> Confirmation["User Explicit Confirmation"]
    Confirmation --> Executor["SafeOperationExecutor (Atomic & Trash Fallback)"]
    Executor --> Audit["Encrypted SQLite WAL Audit Trail"]
```

1. **System & User Path Protection**: Hard boundaries protecting system root directories (`/System`, `/Library`, `/usr`, `/private`) and essential user directories (`~`, `~/Desktop`, `~/Documents`, `~/Downloads`, `~/.ssh`, `~/.gnupg`, `~/Library/Keychains`).
2. **Symlink Attack Resistance**: Canonicalizes all filesystem paths with `URL.resolvingSymlinksInPath()` before evaluating deletion permissions.
3. **Anti-Kernel Panic Protection**: Blocks termination of PID 0 (`kernel_task`), PID 1 (`launchd`), and 35+ critical macOS daemons (`WindowServer`, `loginwindow`, `securityd`, `opendirectoryd`, `tccd`, `Dock`, `Finder`, etc.).
4. **Sandboxed Command Execution**: Replaces raw shell execution with a strictly whitelisted runner (`dscacheutil`, `killall`, `mdutil`, `qlmanage`) with 15-second watchdog timers.

---

## 🤖 Multi-Provider AI Platform

Choose the intelligence provider that matches your privacy and performance needs:

| Provider | Privacy & Network | Capabilities |
| :--- | :--- | :--- |
| **Local Heuristics** | 100% Offline • Zero Network | Instant rule-based memory, CPU bottleneck, and junk diagnosis. |
| **Ollama Local** | 100% Offline • Localhost Only | On-device local LLM reasoning (Llama 3.2, DeepSeek-R1:8B) via `localhost:11434`. |
| **NVIDIA NIM** | Cloud HTTPS API | Enterprise-scale diagnostic reasoning with Llama 3.3 70B and DeepSeek R1. |
| **OpenAI-Compatible** | Custom Endpoint | Connect to your self-hosted vLLM, LM Studio, or OpenAI servers. |

---

## 🏎️ Performance Benchmarks

*Tested on MacBook Pro 14" (Apple M3 Pro, 18 GB RAM, macOS 15.0)*:

* **Mach-O Header Detection**: **0.04 ms** (vs ~4.8 ms with `lipo` — **~120x faster**).
* **Mach VM Telemetry Read**: **< 0.02 ms** (vs ~45 ms with `ps` / `top`).
* **Multi-Category Parallel Scan**: **0.72 s** for 50,000 files using Swift `TaskGroup`.
* **Watchdog Background CPU Load**: **~0.01%** (zero impact on battery life).

For full benchmark specifications, see [BENCHMARKS.md](BENCHMARKS.md).

---

## 📥 Installation

### Option 1: Download Release
Download the notarized `MacOptimizer.dmg` from the [Latest Releases](https://github.com/osmancagrigenc/MacOsOptimizer/releases) page and drag it to `/Applications`.

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/osmancagrigenc/MacOsOptimizer.git
cd MacOsOptimizer

# Run unit tests (120+ assertions)
swift test

# Build and package the .app bundle
./Scripts/build_app.sh

# Open the application
open MacOptimizer.app
```

---

## 🧪 Testing & Verification

MacOptimizer includes comprehensive property-based safety tests, symlink attack validations, daemon protection verifications, and dry-run plan checks:

```bash
swift test --enable-code-coverage
```

---

## 📜 Documentation

* [Architecture & Data Flow](ARCHITECTURE.md)
* [Security Policy & Threat Model](SECURITY.md)
* [Privacy Commitments](PRIVACY.md)
* [Contributing Guidelines](CONTRIBUTING.md)
* [Roadmap](ROADMAP.md)
* [Changelog](CHANGELOG.md)
* [Performance Benchmarks](BENCHMARKS.md)

---

## 📄 License

MacOptimizer is licensed under the **Apache License, Version 2.0**. See the [LICENSE](LICENSE) file for details.
