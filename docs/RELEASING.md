# Releasing MacOptimizer

MacOptimizer ships as a Developer ID-signed, notarized DMG on GitHub Releases. It is not
sandboxed and is not distributed through the Mac App Store.

## Version

The `VERSION` file at the repo root is the only version source (`MAJOR.MINOR.PATCH`).
`Scripts/build_app.sh` writes it to `CFBundleShortVersionString`, and writes
`git rev-list --count HEAD` to `CFBundleVersion`. The CLI `version` command reads the bundle,
and the release tag must be `v<VERSION>` (the release workflow checks this).

To release a new version: bump `VERSION`, update `CHANGELOG.md`, merge, then follow the local
flow below.

## App icon

Replace `Resources/Brand/AppIcon-1024.png` (a 1024×1024 PNG) to change the icon.
`Scripts/build_icns.sh` renders every iconset size from it and runs `iconutil` during each
build. The current master is a placeholder drawn by `Scripts/make_icon.swift`, which runs
only when the master file is missing.

## Local release (current flow)

Requirements on the release Mac:

- The signing identity `Developer ID Application: OSMAN CAGRI GENC (N83DXM47FV)` in the login
  keychain.
- A notarytool keychain profile named `codifya-notary`
  (`xcrun notarytool store-credentials`).

```bash
# 1. Rehearsal: builds, signs and packages; skips notarization.
DRY_RUN=1 ./Scripts/release.sh

# 2. Real release, from a clean tree on main.
./Scripts/release.sh

# 3. Publish.
git tag v$(cat VERSION) && git push origin v$(cat VERSION)
gh release create v$(cat VERSION) dist/MacOptimizer-$(cat VERSION).dmg \
    dist/MacOptimizer-$(cat VERSION).dmg.sha256 --generate-notes
```

`Scripts/release.sh` does the following:

1. Builds a universal (arm64 + x86_64) bundle into `dist/stage/` (`UNIVERSAL=0` for the host
   architecture only).
2. Checks that the bundle contains exactly one Mach-O file. The SwiftPM resource bundle
   (localizations) is data, so the app is signed once, without `--deep`.
3. Signs with `codesign --force --options runtime --timestamp --entitlements
   Scripts/MacOptimizer.entitlements`, verifies with `codesign --verify --strict --deep`,
   and runs `spctl -a -vv`. Before notarization, `spctl` reports "Unnotarized Developer ID".
   That is expected.
4. Creates `dist/MacOptimizer-<version>.dmg` (the app plus an `/Applications` link) and signs
   the DMG.
5. Submits the DMG once with `notarytool submit --wait`, then staples and validates the
   ticket on the DMG. Notarizing the DMG also notarizes the app inside it. Gatekeeper checks
   the copied app online on first launch.
6. Runs `spctl -a -t open --context context:primary-signature -vv` on the DMG and writes
   `dist/MacOptimizer-<version>.dmg.sha256`.

Overrides: `SIGN_IDENTITY`, `NOTARY_PROFILE`, `SCRATCH_PATH`, and `ALLOW_DIRTY=1`. A real
release refuses to run from a dirty tree unless `ALLOW_DIRTY=1` is set. `dist/` is ignored
by git.

## Entitlements

`Scripts/MacOptimizer.entitlements` is intentionally empty. Hardened runtime comes from
`--options runtime`. The app is pure Swift with no JIT, plugins, third-party dylibs, Apple
Events or DYLD variables, so it needs no hardened-runtime exceptions. Keychain access to its
own items and outbound HTTPS both work without entitlements outside the sandbox. Add an
entitlement only for a need you have reproduced, and record the reason in the file's comment.

## CI (`.github/workflows/release.yml`)

On a `v*` tag:

- **build-unsigned** always runs. It checks that the tag matches `VERSION`, builds a
  universal unsigned DMG, and uploads it as a workflow artifact. It does not attach the DMG
  to a release.
- **sign-and-notarize** runs only when all of the following repository secrets exist.
  Without them, the job is skipped and the workflow still succeeds.

| Secret | Content |
|---|---|
| `MACOS_CERT_P12` | Base64 of the exported Developer ID Application certificate + private key (`base64 -i cert.p12`) |
| `MACOS_CERT_PASSWORD` | Password of that `.p12` |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect issuer ID |
| `ASC_KEY_P8` | Full text of the `.p8` API key |

  The job imports the certificate into a temporary keychain and writes the `.p8` to the
  runner temp directory with mode 600. It then runs `Scripts/release.sh`, which notarizes
  with `--key/--key-id/--issuer`, and creates a **draft** GitHub release with the notarized
  DMG and its checksum. The temporary keychain and key files are deleted even when the job
  fails. Use a Developer-role API key for CI, not an Admin one.

`ci.yml` builds the universal bundle on every PR. It checks the version, the icon, both
`.lproj` folders and both architectures.
