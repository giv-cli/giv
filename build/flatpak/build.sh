#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"
FLATPAK_BUILD_TEMP="$2/flatpak"
FLATPAK_DIST_DIR="./dist/${VERSION}/flatpak"

# Prepare staging dir
rm -rf "$FLATPAK_BUILD_TEMP"
mkdir -p "$FLATPAK_BUILD_TEMP/src" "$FLATPAK_BUILD_TEMP/templates"

# Copy and rename main script
cp src/giv.sh "$FLATPAK_BUILD_TEMP/src/giv"
chmod +x "$FLATPAK_BUILD_TEMP/src/giv"
# Copy libraries
find src -type f -name '*.sh' ! -name 'giv.sh' -exec cp {} "$FLATPAK_BUILD_TEMP/src/" \;
# Copy templates
cp -r templates/* "$FLATPAK_BUILD_TEMP/templates/"

# Copy and substitute version in manifest
sed "s/{{VERSION}}/${VERSION}/g" build/flatpak/flatpak.json > "$FLATPAK_BUILD_TEMP/flatpak.json"

# Move to dist dir
mkdir -p "${FLATPAK_DIST_DIR}"
rm -rf "${FLATPAK_DIST_DIR:?}/"*
mv "$FLATPAK_BUILD_TEMP"/* "${FLATPAK_DIST_DIR}/"

printf "Flatpak build completed. Files are in %s\n" "${FLATPAK_DIST_DIR}"
printf "To build the flatpak, run:\n  flatpak-builder build-dir flatpak.json --force-clean\n"
