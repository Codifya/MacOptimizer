# 🤝 Contributing to MacOptimizer Pro

Thank you for your interest in contributing to **MacOptimizer Pro**! We welcome bug reports, feature suggestions, architecture improvements, and code contributions from the macOS open-source community.

---

## 🧭 Code of Conduct

All contributors and maintainers are expected to adhere to standard respectful, inclusive, and professional communication standards.

---

## 🛠️ Development Setup

### Prerequisites
* macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
* Xcode 15.0+ / Xcode 16.0+ (with Command Line Tools installed: `xcode-select --install`)
* Swift 5.9+
* Git

### Building from Source
```bash
# Clone the repository
git clone https://github.com/osmancagrigenc/MacOsOptimizer.git
cd MacOsOptimizer

# Run unit tests
swift test

# Build debug binary
swift build

# Build standalone .app bundle
./Scripts/build_app.sh
```

---

## 📐 Architecture & Coding Guidelines

1. **Zero-Harm First**: Every filesystem or process operation MUST be validated through `SafetyPolicyEngine`. Never write direct file removal code without policy checks.
2. **Swift Concurrency**: Use native Swift `async`/`await`, `TaskGroup`, and actors. Avoid legacy dispatch queues or callback pyramids.
3. **Darwin & Native APIs Over Shell Commands**: Prefer Darwin Mach Kernel C APIs (`host_statistics64`, `sysctlbyname`), `FileManager`, and `ProcessInfo` over executing `/bin/sh` or `/bin/ps`.
4. **Clean UI & Liquid Glass**: Adhere to SwiftUI best practices with fluid responsive sizing (`ViewThatFits`, `LazyVGrid` adaptive columns, `maxWidth: .infinity`).
5. **No Secrets in Code**: Never commit API keys, personal paths, or tokens. API keys must use `KeychainManager`.

---

## 🧪 Testing Requirements

* All new features and policy changes **must include unit tests** in `Tests/MacOptimizerTests/`.
* Verify tests before opening a pull request:
  ```bash
  swift test --enable-code-coverage
  ```
* All property-based safety tests must pass with 0 failures.

---

## 🚀 Pull Request Workflow

1. Fork the repository and create a descriptive branch:
   ```bash
   git checkout -b feature/awesome-telemetry-chart
   ```
2. Commit your changes following standard Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`).
3. Ensure `swift test` passes cleanly.
4. Open a Pull Request against the `main` branch with a clear summary of changes, motivation, and test coverage evidence.
