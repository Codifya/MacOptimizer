#!/bin/bash
# Builds AppIcon.icns from the 1024x1024 master PNG.
#
# Usage: Scripts/build_icns.sh <output.icns> [master.png]
#   master defaults to Resources/Brand/AppIcon-1024.png. To change the app icon, replace
#   that file. If it is missing, the placeholder generator (Scripts/make_icon.swift)
#   writes it first.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:?usage: build_icns.sh <output.icns> [master.png]}"
MASTER="${2:-${REPO_ROOT}/Resources/Brand/AppIcon-1024.png}"

if [[ ! -f "${MASTER}" ]]; then
    echo "Master icon missing; generating placeholder at ${MASTER}"
    swift "${REPO_ROOT}/Scripts/make_icon.swift" "${MASTER}"
fi

width="$(sips -g pixelWidth "${MASTER}" | awk '/pixelWidth/ {print $2}')"
height="$(sips -g pixelHeight "${MASTER}" | awk '/pixelHeight/ {print $2}')"
if [[ "${width}" != "1024" || "${height}" != "1024" ]]; then
    echo "error: ${MASTER} must be 1024x1024 PNG, got ${width}x${height}" >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT
ICONSET="${WORK_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET}"

# name:pixels for every iconset rendition macOS expects.
for spec in \
    icon_16x16.png:16 icon_16x16@2x.png:32 \
    icon_32x32.png:32 icon_32x32@2x.png:64 \
    icon_128x128.png:128 icon_128x128@2x.png:256 \
    icon_256x256.png:256 icon_256x256@2x.png:512 \
    icon_512x512.png:512 icon_512x512@2x.png:1024; do
    name="${spec%%:*}"
    px="${spec##*:}"
    sips -s format png -z "${px}" "${px}" "${MASTER}" --out "${ICONSET}/${name}" >/dev/null
done

mkdir -p "$(dirname "${OUTPUT}")"
iconutil -c icns "${ICONSET}" -o "${OUTPUT}"
echo "Wrote ${OUTPUT}"
