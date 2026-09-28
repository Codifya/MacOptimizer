# Security Policy

MacOptimizer Pro deletes files, terminates processes and runs system commands, so its safety
rules matter. This document describes what the code actually enforces and how to report a
problem.

## Supported versions

| Version | Status |
| --- | --- |
| 3.1.0 and later | Supported. v3.1.0 is being prepared and will be the first Developer ID-signed and notarized release. |
| 2.1.0 – 3.0.0 | **Not safe. Do not use.** These releases contain known safety defects: a command injection in the update screen, and deletion paths that skipped the preview and confirmation. They were ad-hoc signed and not notarized. |

## Deletion pipeline

Every file removal in the app and the CLI goes through `SafeOperationExecutor`:

1. **Plan and preview.** Scans produce a `CleaningPlan`. Paths are canonicalised with
   `URL.resolvingSymlinksInPath()` and classified by `OperationRiskClassifier`; forbidden paths
   are never added. The plan is shown before anything is removed. The CLI prints it and needs
   `--execute --yes`.
2. **Confirmation is enforced.** `SafetyPolicyEngine` returns `allowed`, `requiresConfirmation` or
   `denied`. The executor throws when a `requiresConfirmation` decision arrives without a
   confirmation, and always refuses `denied`.
3. **Re-validation.** Right before acting, the executor resolves the path again and stops if it
   no longer resolves to the validated location or has become forbidden.
4. **Trash by default.** The app's cleaners move items to the Trash. The executor permits
   permanent removal only inside approved cache and log folders (for example
   `~/Library/Caches/`, `~/Library/Logs/`, Xcode DerivedData, npm/Yarn/Cargo/Gradle/pip caches).
5. **Emptying the Trash** is a separate, permanent action with its own confirmation (in the CLI,
   `--include-trash`). It removes only entries directly inside `~/.Trash` and never follows
   symlinks to their targets.

### Protected paths

`PathProtectionPolicy` forbids:

- system locations: `/`, `/System`, `/Library` (except `/Library/Caches/` and
  `/Library/Logs/DiagnosticReports/`), `/usr`, `/bin`, `/sbin`, `/var`, `/etc`, `/dev`,
  `/private`, `/Volumes`, `/cores`, `/opt`, and `/Users` outside your own home folder;
- in your home folder: the folder itself, Desktop, Documents, Downloads, Movies, Music, Pictures,
  Applications, `Library`, `Library/Application Support`, `Library/Keychains`, `Library/Mail`,
  `Library/Messages`, `Library/Photos`, `Library/Safari`, `Library/Preferences`,
  `Library/Containers`, `Library/Group Containers`, `Library/LaunchAgents`,
  `Library/Mobile Documents`, shell and Git configuration files, and everything under `.ssh`,
  `.gnupg`, `.aws`, `.config` and `.git`.

The exact lists are in `Sources/MacOptimizer/Core/Security/PathProtectionPolicy.swift`.

## Process termination

Force-quitting from the Memory screen and terminating a process suggested by the AI assistant
ask for confirmation first. The quit button in the dashboard's top-process card sends a normal
quit request (the app's terminate, or SIGTERM) without a separate prompt. PID 0 (`kernel_task`), PID 1
(`launchd`), the app's own process, a list of about 40 system processes (`WindowServer`,
`loginwindow`, `securityd`, `tccd`, `Dock`, `Finder`, `mds`, `powerd`, …) and executables under
`/System/Library/CoreServices/`, `/usr/libexec/` and `/System/Library/Frameworks/` cannot be
terminated. The watchdog never terminates processes on its own.

## Command execution

- There is no shell execution (`/bin/sh -c`, `zsh -c`) anywhere in the app.
- System tools run through `SandboxedCommandRunner`, which accepts only an allow-list of absolute
  executable paths (`dscacheutil`, `killall`, `mdutil`, `qlmanage`, `lsregister`, `atsutil`,
  `launchctl`, `csrutil`, `spctl`, `defaults`, `socketfilterfw`), drops arguments that contain
  `;`, `|`, `&`, `` ` `` or `$`, and times out after 15 seconds by default.
- `/bin/ps`, `/bin/kill` and `brew` run as a fixed executable with an argument array. Homebrew
  upgrades accept only a validated cask token (`[a-z0-9@._+-]`); data from remote appcasts is
  never used as a command. Links from appcasts are opened only for `http` and `https` URLs.
- All child processes go through `ProcessExecutor`: output is drained while the child runs and
  capped, and a timed-out child gets SIGTERM and then SIGKILL.

## Secrets

The NVIDIA NIM API key is stored in the macOS Keychain
(`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). The copy of the AI configuration kept in
UserDefaults has an empty key field. A key saved in UserDefaults by an older version is migrated
to the Keychain.

## Threat model summary

| Threat | Mitigation in the code | Limits |
| --- | --- | --- |
| Deleting the wrong files | Path policy, plan preview, enforced confirmation, Trash by default | The Trash itself is emptied permanently when you confirm it |
| Symlink swaps between check and use | Canonicalisation, then re-validation right before acting | A narrow race between the last check and the file operation remains |
| Command injection | No shell; allow-listed executables; argument filtering; validated Homebrew tokens | — |
| Killing critical processes | PID and name/path protection lists; confirmation for force quit and AI suggestions | Name lists are maintained by hand |
| Data sent to the cloud | NVIDIA NIM is off by default and needs a disclosure; app names need a separate opt-in | See [PRIVACY.md](PRIVACY.md) for exactly what is sent |
| Tampered downloads | From v3.1.0: Developer ID signature and notarization (in preparation), plus GitHub build-provenance attestation | Releases up to v3.0.0 were not notarized |

The app is not sandboxed and has no privileged helper. It runs with your user's permissions only.
There is no audit log of file operations; the History screen lists completed operations from
UserDefaults.

## Reporting a vulnerability

Please do not open a public issue for security problems.

1. Email **info@codifya.com** with a description, the affected version, steps to
   reproduce and the impact you expect.
2. We aim to acknowledge reports within 48 hours and to agree on a fix timeline with you.

Repository: https://github.com/Codifya/MacOptimizer
