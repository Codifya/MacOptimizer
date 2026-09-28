#!/bin/bash
# Local release: universal build -> Developer ID signing (hardened runtime) -> DMG ->
# notarization -> stapling -> Gatekeeper checks -> checksum.
#
# Flow: the app is signed, placed in a signed DMG, and the DMG is submitted to the notary
# service once. Notarizing the DMG also notarizes the app inside it; the ticket is stapled
# to the DMG. See docs/RELEASING.md.
#
# Environment:
#   SIGN_IDENTITY   codesign identity (default: Developer ID Application: OSMAN CAGRI GENC (N83DXM47FV))
#   NOTARY_PROFILE  notarytool keychain profile (default: codifya-notary)
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID
#                   notarize with an App Store Connect API key instead of the profile (CI)
#   DRY_RUN=1       sign and package, but skip notarization and stapling
#   UNIVERSAL=0     build for the host architecture only (default: universal arm64 + x86_64)
#   SCRATCH_PATH    SwiftPM scratch path (default: .build)
#   ALLOW_DIRTY=1   allow a real (non-dry) release from a dirty working tree
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

APP_NAME="MacOptimizer"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: OSMAN CAGRI GENC (N83DXM47FV)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-codifya-notary}"
DRY_RUN="${DRY_RUN:-0}"
ENTITLEMENTS="${REPO_ROOT}/Scripts/MacOptimizer.entitlements"
VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
DIST_DIR="${REPO_ROOT}/dist"
STAGE_DIR="${DIST_DIR}/stage"
APP_BUNDLE="${STAGE_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

step() { printf '\n==> %s\n' "$*"; }
fail() { echo "error: $*" >&2; exit 1; }

preflight() {
    step "Preflight (version ${VERSION}, dry run: ${DRY_RUN})"
    if [[ -n "$(git status --porcelain)" ]]; then
        if [[ "${DRY_RUN}" == "1" || "${ALLOW_DIRTY:-0}" == "1" ]]; then
            echo "warning: working tree is dirty"
        else
            fail "working tree is dirty; commit first or set ALLOW_DIRTY=1"
        fi
    fi
    security find-identity -v -p codesigning | grep -qF "\"${SIGN_IDENTITY}\"" \
        || fail "signing identity not found in keychain: ${SIGN_IDENTITY}"
    [[ -f "${ENTITLEMENTS}" ]] || fail "missing ${ENTITLEMENTS}"
    plutil -lint "${ENTITLEMENTS}" >/dev/null
}

build_app() {
    step "Building app bundle"
    rm -rf "${STAGE_DIR}"
    mkdir -p "${STAGE_DIR}"
    UNIVERSAL="${UNIVERSAL:-1}" OUTPUT_DIR="${STAGE_DIR}" "${REPO_ROOT}/Scripts/build_app.sh"
    lipo -info "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
}

# The bundle must contain exactly one Mach-O (the main executable); the SwiftPM resource
# bundle is data only. If this ever changes, nested code must be signed explicitly first.
assert_single_executable() {
    local machos=0 f
    while IFS= read -r -d '' f; do
        if file -b "${f}" | head -n 1 | grep -q 'Mach-O'; then
            machos=$((machos + 1))
        fi
    done < <(find "${APP_BUNDLE}" -type f -print0)
    [[ "${machos}" == "1" ]] || fail "expected 1 Mach-O in the bundle, found ${machos}; sign nested code explicitly"
}

sign_app() {
    step "Signing app (hardened runtime, secure timestamp)"
    assert_single_executable
    codesign --force --options runtime --timestamp \
        --entitlements "${ENTITLEMENTS}" \
        --sign "${SIGN_IDENTITY}" \
        "${APP_BUNDLE}"
    codesign --verify --strict --deep --verbose=2 "${APP_BUNDLE}"
    codesign -dv --verbose=4 "${APP_BUNDLE}" 2>&1 | grep -E '^(Identifier|Format|CodeDirectory|Authority|Timestamp|TeamIdentifier|Runtime Version)'
    step "Gatekeeper assessment of the app (rejected as 'Unnotarized' before notarization)"
    spctl -a -vv "${APP_BUNDLE}" 2>&1 || true
}

create_dmg() {
    step "Creating ${DMG_PATH}"
    local dmg_root="${DIST_DIR}/dmg-root"
    rm -rf "${dmg_root}" "${DMG_PATH}" "${DMG_PATH}.sha256"
    mkdir -p "${dmg_root}"
    ditto "${APP_BUNDLE}" "${dmg_root}/${APP_NAME}.app"
    ln -s /Applications "${dmg_root}/Applications"
    hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "${dmg_root}" \
        -fs HFS+ -format UDZO -ov "${DMG_PATH}"
    rm -rf "${dmg_root}"
    codesign --force --timestamp --sign "${SIGN_IDENTITY}" "${DMG_PATH}"
    codesign --verify --strict --verbose=2 "${DMG_PATH}"
}

notarize() {
    if [[ "${DRY_RUN}" == "1" ]]; then
        step "DRY_RUN=1: skipping notarization and stapling"
        return
    fi
    local auth=()
    if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
        # CI: App Store Connect API key file (never committed).
        [[ -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]] \
            || fail "NOTARY_KEY_PATH requires NOTARY_KEY_ID and NOTARY_ISSUER_ID"
        auth=(--key "${NOTARY_KEY_PATH}" --key-id "${NOTARY_KEY_ID}" --issuer "${NOTARY_ISSUER_ID}")
        step "Notarizing (API key ${NOTARY_KEY_ID})"
    else
        auth=(--keychain-profile "${NOTARY_PROFILE}")
        step "Notarizing (keychain profile ${NOTARY_PROFILE})"
    fi
    xcrun notarytool submit "${DMG_PATH}" "${auth[@]}" --wait
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
}

final_checks() {
    step "Gatekeeper assessment of the DMG"
    if [[ "${DRY_RUN}" == "1" ]]; then
        spctl -a -t open --context context:primary-signature -vv "${DMG_PATH}" 2>&1 || true
    else
        spctl -a -t open --context context:primary-signature -vv "${DMG_PATH}"
    fi
    step "Checksum"
    (cd "${DIST_DIR}" && shasum -a 256 "$(basename "${DMG_PATH}")" > "$(basename "${DMG_PATH}").sha256")
    cat "${DMG_PATH}.sha256"
}

preflight
build_app
sign_app
create_dmg
notarize
final_checks
step "Done: ${DMG_PATH}"
