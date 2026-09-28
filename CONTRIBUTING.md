# Contributing to MacOptimizer Pro

Thank you for your interest in contributing. Bug reports, suggestions and pull requests are
welcome.

## Code of conduct

Be respectful, inclusive and constructive.

## Development setup

### Prerequisites

- macOS 14 or later
- Xcode 16 or later (Swift 6 toolchain); CI uses Xcode 16.4
- Git

### Building from source

```bash
git clone https://github.com/Codifya/MacOptimizer.git
cd MacOptimizer

swift build              # debug build
swift test               # run the test suite
./Scripts/build_app.sh   # build MacOptimizer.app (unsigned)
```

## Guidelines

1. **Safety first.** Every file removal must go through `SafeOperationExecutor` with a
   `CleaningPlan` the user has reviewed and confirmed. Never call `FileManager.removeItem` or
   `trashItem` directly from a feature.
2. **No shell.** Run external tools through `SandboxedCommandRunner` (add the absolute path to
   `ApprovedExecutable`) or `SystemCommandRunner` with an argument array. Never build a shell
   command string, and never pass remote data as a command.
3. **Swift concurrency.** Use `async`/`await` and actors. Keep blocking file I/O off the
   cooperative thread pool (see `runBlocking`), and make long scans cancellable.
4. **Native APIs first.** Prefer Darwin, IOKit, `FileManager` and `ProcessInfo` over spawning
   processes.
5. **Localization.** User-facing strings go through `L10n` with English and Turkish entries. See
   [docs/LOCALIZATION.md](docs/LOCALIZATION.md). CLI output stays English.
6. **No secrets in code.** API keys go through `KeychainManager`.
7. **Honest results.** Report the real outcome of an operation (exit codes, bytes actually
   freed). Do not show success for work that did not happen.

## Tests

- New features and policy changes need tests in `Tests/MacOptimizerTests/`.
- Tests must be hermetic: they must not change the machine they run on. Use temporary
  directories, a fake home folder, injected command runners and throwaway Keychain items. CI
  checks that the clipboard and Keychain are unchanged after the run.
- Run the suite before opening a pull request:

  ```bash
  swift test
  ```

## Pull requests

1. Fork the repository and create a descriptive branch.
2. Use Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`).
3. Make sure `swift build` and `swift test` pass.
4. Open a pull request against `main` with a summary of the change, the motivation and how you
   tested it. Keep the documentation in line with what the code does.

Security problems: please follow [SECURITY.md](SECURITY.md) instead of opening a public issue.
