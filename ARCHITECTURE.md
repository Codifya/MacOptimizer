# 🏛️ MacOptimizer Pro Architecture

MacOptimizer Pro is designed with a **Clean, Layered, Unidirectional Data Flow (UDF)** architecture, ensuring high performance, memory safety, and defense-in-depth protection.

---

## 🏗️ System Overview

```mermaid
graph TD
    subgraph UI ["🎨 SwiftUI Presentation Katmanı"]
        Views["MainView / Dashboard / Memory / Cleaner / AppManager / Autonomous / Copilot"]
    end

    subgraph State ["🧠 State Management"]
        AppState["AppState (@MainActor ObservableObject)"]
    end

    subgraph CoreSecurity ["🛡️ Security & Zero-Harm Engine"]
        RiskClassifier["OperationRiskClassifier"]
        SafetyEngine["SafetyPolicyEngine"]
        Policies["PathProtection / ProcessProtection / AppProtection / LaunchProtection"]
        SafeExec["SafeOperationExecutor (Atomic & Trash Fallback)"]
        CmdSandbox["SandboxedCommandRunner (Whitelisted Executables)"]
    end

    subgraph CoreTelemetry ["📊 Observability & Telemetry"]
        SysMon["SystemMonitorService (Mach host_statistics64 & sysctl)"]
        TelemetryStore["TelemetryStore (SQLite WAL Time-Series)"]
    end

    subgraph AIPlatform ["🤖 AI & Diagnostics Platform"]
        AIProvider["AIProvider Protocol"]
        Heuristics["LocalHeuristicProvider (Offline)"]
        Ollama["OllamaProvider (Local LLM)"]
        NIM["NvidiaNIMProvider (Enterprise Cloud)"]
        OpenAI["OpenAICompatibleProvider (Custom Endpoints)"]
    end

    subgraph Operations ["⚙️ Domain Operations"]
        CleaningPlan["CleaningPlan Engine (Dry-Run Lifecycle)"]
        AppScanner["AppScannerService (Mach-O Binary Parser)"]
        Uninstaller["AppUninstallerService (Orphan File Hunter)"]
        Updates["AppUpdateCheckerService (Sparkle & Homebrew)"]
        Watchdog["AutonomousGuardService (Background Healer)"]
    end

    Views --> AppState
    AppState --> CoreTelemetry
    AppState --> AIPlatform
    AppState --> Operations
    Operations --> CoreSecurity
    CoreSecurity --> Darwin["Darwin Mach Kernel & macOS FileSystem"]
```

---

## 🧩 Architectural Layers

### 1. Presentation Layer (`Views/`)
* **SwiftUI + Liquid Glass Design System**: Dynamic blurred backgrounds, responsive grids (`LazyVGrid` with `GridItem(.adaptive(minimum: ...))`), and smart toolbar folding with `ViewThatFits`.
* **Zero UI Lag**: All telemetry computations, directory tree scanning, and network requests are executed on background actors.

### 2. State Layer (`AppState.swift`)
* `@MainActor ObservableObject` that acts as the single source of truth for navigation, live gauges, AI recommendations, watchdog alarms, and background scan progress.

### 3. Security Engine (`Core/Security/`)
* **`OperationRiskClassifier`**: Classifies operations into `.safe`, `.low`, `.medium`, `.destructive`, and `.forbidden`.
* **`PathProtectionPolicy`**: Canonicalizes paths with `URL.resolvingSymlinksInPath()` and protects system roots and user personal directories.
* **`ProcessProtectionPolicy`**: Shields PID 0/1 and 35+ critical macOS daemons from being killed.
* **`SafeOperationExecutor`**: Governs actual file removals and process termination.

### 4. Telemetry & Storage (`Core/Telemetry/`)
* **`SystemMonitorService`**: Reads Mach VM statistics (`host_statistics64`) and kernel sysctl values in microseconds with near-zero CPU and battery footprint.
* **`TelemetryStore`**: Embedded SQLite database operating in WAL (Write-Ahead Logging) mode for thread-safe downsampled historical metrics.

### 5. Multi-Provider AI Platform (`Infrastructure/AI/`)
* Completely decoupled from raw system commands. AI generates structured `AIInsight` and `AIAction` recommendations which must pass through the `SafetyPolicyEngine` and require user confirmation before execution.
