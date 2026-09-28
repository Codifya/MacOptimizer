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
   * Built-in local heuristics are the default and work offline. NVIDIA NIM is disabled by default and requires accepting an in-app disclosure before its first request.
   * NVIDIA NIM receives the Mac hardware model, chip, macOS version, RAM/CPU/disk percentages, detected junk size, and the chat messages sent to the assistant. The API key is sent only as the HTTPS authorization credential and is not part of the request body.
   * Running app names and process IDs are excluded by default. The separate “Çalışan uygulama adlarını dahil et” setting opts them into NVIDIA NIM requests. File paths and file contents are not included in AI requests.

5. **Other Network Requests**:
   * App update checks read the configured Sparkle appcasts of installed apps; a feed configured with plain HTTP is contacted over HTTP.
   * The VS Code update checker contacts the VS Code update API.
   * Homebrew update and package operations invoke `brew`, which may contact its configured repositories and services.
