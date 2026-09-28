# Changelog

All notable changes to MacOptimizer Pro are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [3.1.0] - 2026-09-29

The safety release. v2.1.0–v3.0.0 contain known safety defects; use v3.1.0 or later.

### Release

- First Developer ID-signed, hardened-runtime and notarized release, shipped as a universal
  (Apple silicon and Intel) DMG. One version source (`VERSION`); the release script signs,
  notarizes, staples and verifies. (#21)
- New app icon. (#24)
- The dashboard quit button, like every other process-termination path, now asks for
  confirmation and sends SIGTERM. The Autonomous Guard's terminate button now shows its
  confirmation dialog on its own screen. (#23)
- The App Manager screens are localized; the CLI prints English labels only; the offline
  assistant shows a localized system summary. (#20)

### Security

- Removed a command injection in the update screen: a remote Sparkle appcast could make the app
  run shell code. The shell runner is gone; Homebrew upgrades run `brew` directly with a
  validated cask token, and appcast links open only for `http`/`https` URLs. (#1)
- One deletion pipeline for the app and the CLI: plan preview, enforced confirmation in
  `SafeOperationExecutor`, re-validation of the path right before acting, Trash by default, and
  permanent removal only inside approved cache folders. "Smart optimize", "Empty Trash", the AI
  clean action and the CLI no longer delete without a preview and confirmation. (#3)
- Emptying the Trash is a separate, confirmed action that removes Trash entries only, never the
  targets of symlinks. Trash items are no longer pre-selected. (#3)
- Uninstaller leftovers are opt-in and matched by a validated bundle identifier. (#3)

### Changed

- The CLI needs `--execute --yes` to clean and `--include-trash` to touch the Trash. It no longer
  treats Cocoa launch arguments (such as `-AppleLanguages`) as commands. (#3, #7)
- AI assistant: local heuristics are the default; NVIDIA NIM runs only after an in-app disclosure
  is accepted; running app names and PIDs are sent only with a separate opt-in. (#4)
- Monitoring runs in one owned loop with tiered, visibility-aware sampling; process execution
  drains pipes concurrently with bounded output and SIGTERM/SIGKILL timeouts; scans run in
  parallel and can be cancelled; in-memory collections are bounded. (#1)
- Telemetry history is now actually recorded (one row per minute, kept for 48 hours). (#1)
- English and Turkish localization. The app follows the macOS system language; the CLI and the
  prompts sent to NVIDIA NIM are English. (#7–#19)

### Fixed

- Maintenance commands report their real exit codes instead of always reporting success. (#5)
- The security score no longer adds points for a disabled firewall or unconditionally; states
  that cannot be read are shown as unknown. (#5)
- The CLI `status` command measures CPU from two real samples instead of printing a fixed
  value. (#5)
- Battery health is calculated correctly on Apple Silicon. (#5)
- Charts no longer show made-up seed data. (#5)

### Removed

- RAM purge (the app, the menu bar, the CLI `purge-ram` command, the AI action and the watchdog
  auto-heal option). It could not free memory without administrator rights but reported
  success. (#5)
- The unused Ollama and OpenAI-compatible AI providers. (#4)

### Tests and CI

- The test suite is hermetic: injected command runners, temporary SQLite files, a fake home
  folder and a throwaway Keychain item. CI runs all tests on macOS with Xcode 16.4 (Swift 6) and
  checks that the clipboard and Keychain are unchanged. The suite now has 87 test methods.
  (#2, #6, #7)
- Gitleaks runs as a CLI in CI. (#2)

## [2.2.0] – [3.0.0] - 2026-08-28

Released the same day as 2.1.0 without changelog entries; see the
[GitHub releases](https://github.com/Codifya/MacOptimizer/releases). They added the cleaning plan
preview, Swift Charts, thermal and swap metrics, the SQLite telemetry store, the watchdog rules,
the menu bar extra, the CLI, developer cache cleaning, the uninstaller, the security overview, the
duplicate finder, battery and network telemetry. **These releases are unsafe**: see 3.1.0.

## [2.1.0] - 2026-08-28

First public release. **Unsafe**: see 3.1.0.

### Added

- Modular safety policies (`PathProtectionPolicy`, `ProcessProtectionPolicy`,
  `ApplicationProtectionPolicy`, `LaunchItemProtectionPolicy`, `SafetyPolicyEngine`) with
  symlink resolution, and the `OperationRisk` levels.
- `CleaningPlan` for a preview before cleaning. (In this release some delete actions bypassed it.)
- `KeychainManager` for the API key, with migration from UserDefaults.
- An `AIProvider` protocol. Only the local heuristics and NVIDIA NIM were ever used; the Ollama
  and OpenAI-compatible providers were never wired into the app and were removed in 3.1.0.
- `SandboxedCommandRunner` with an executable allow-list and a 15 s timeout. (A separate shell
  runner still existed and was removed in 3.1.0.)
- An SQLite telemetry store. (Nothing was written to it until 3.1.0.)
- A test suite of 23 test methods in one file (earlier notes called them "23 suites with 120+
  assertions"). There were 36 by v3.0.0.
- Apache-2.0 license and the project documents.
- Also included (earlier notes listed them as a separate 2.0.0, which was never tagged): the
  SwiftUI interface, the Mach-O architecture detector, the junk scanner, the app uninstaller,
  Sparkle and Homebrew update checks, maintenance commands and an in-app watchdog. The watchdog
  ran only while the app was open (it was described as "7/24"), and the "safe RAM release" did
  not reliably free memory.
