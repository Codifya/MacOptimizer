#!/bin/bash
# Builds MacOptimizer.app from the SwiftPM executable.
#
# Environment:
#   SCRATCH_PATH  SwiftPM scratch path (default: .build)
#   OUTPUT_DIR    where MacOptimizer.app is written (default: repo root)
#   UNIVERSAL=1   build a universal (arm64 + x86_64) binary
#   BUILD_NUMBER  CFBundleVersion override (default: git rev-list --count HEAD)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

APP_NAME="MacOptimizer"
BUNDLE_ID="com.osmancagrigenc.MacOptimizer"
SCRATCH_PATH="${SCRATCH_PATH:-.build}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"

# Single version source: the VERSION file at the repo root.
VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: VERSION must be MAJOR.MINOR.PATCH, got '${VERSION}'" >&2
    exit 1
fi
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "${REPO_ROOT}" rev-list --count HEAD 2>/dev/null || echo 1)}"

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "Building ${APP_NAME} ${VERSION} (${BUILD_NUMBER}) in release mode, universal=${UNIVERSAL:-0}..."
swift build -c release --scratch-path "${SCRATCH_PATH}" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BUILD_DIR="$(swift build -c release --scratch-path "${SCRATCH_PATH}" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

mkdir -p "${OUTPUT_DIR}"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
RESOURCE_BUNDLE="${APP_NAME}_${APP_NAME}.bundle"

echo "Creating bundle: ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Bundle.module resolves this SwiftPM resource bundle at runtime (localizations live here).
cp -R "${BUILD_DIR}/${RESOURCE_BUNDLE}" "${RESOURCES_DIR}/"
for lang in en tr; do
    if [[ ! -d "${RESOURCES_DIR}/${RESOURCE_BUNDLE}/Contents/Resources/${lang}.lproj" \
       && ! -d "${RESOURCES_DIR}/${RESOURCE_BUNDLE}/${lang}.lproj" ]]; then
        echo "error: ${lang}.lproj missing from ${RESOURCE_BUNDLE}" >&2
        exit 1
    fi
done

# App icon, built from the master PNG Resources/Brand/AppIcon-1024.png.
"${REPO_ROOT}/Scripts/build_icns.sh" "${RESOURCES_DIR}/AppIcon.icns"

# LSUIElement is false on purpose: MacOptimizer is a regular windowed app with a
# Dock icon; the menu bar extra is optional.
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>MacOptimizer Pro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>tr</string>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Osman Cagri Genc (Codifya). Licensed under Apache-2.0.</string>
</dict>
</plist>
EOF
plutil -lint "${CONTENTS_DIR}/Info.plist" >/dev/null

echo "${APP_BUNDLE} created (version ${VERSION}, build ${BUILD_NUMBER})."
