# 🛡️ Privacy Policy & Commitments

**MacOptimizer Pro** is committed to maximum transparency, data security, and user privacy.

---

## 🔒 Core Privacy Principles

1. **Offline-First by Default**:
   * All system monitoring, memory analysis, disk cleaning, and watchdog features execute 100% locally on your Mac.
   * Telemetry metrics and optimization logs never leave your device.

2. **Zero Third-Party Telemetry & Tracking**:
   * MacOptimizer contains **NO tracking SDKs, NO analytics beacons, NO advertising frameworks, and NO fingerprinting**.

3. **Secure Credential Storage**:
   * Any API keys you choose to configure (e.g. NVIDIA NIM API Key or custom OpenAI endpoint tokens) are stored exclusively in the encrypted **macOS Keychain** (`Security.framework`).
   * They are never saved in plain text or synced to external servers.

4. **Transparent AI Diagnostics**:
   * If you choose to use local AI (via Ollama or built-in heuristic rules), **0 bytes** of data leave your computer.
   * If you enable cloud AI (NVIDIA NIM or custom API), only anonymous hardware metrics (e.g. CPU load %, RAM percentage, disk capacity) are sent to the LLM for diagnosis. No file contents, personal documents, or sensitive paths are ever transmitted.
