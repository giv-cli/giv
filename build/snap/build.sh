#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"
SNAP_BUILD_TEMP="$2/snap"
SNAP_DIST_DIR="./dist/${VERSION}/snap"

# Prepare build directory
rm -rf "$SNAP_BUILD_TEMP"
mkdir -p "$SNAP_BUILD_TEMP"/src "$SNAP_BUILD_TEMP"/templates

# Copy and rename entry script
cp src/giv.sh "$SNAP_BUILD_TEMP/src/giv"
chmod +x "$SNAP_BUILD_TEMP/src/giv"
# Copy helper libs
find src -type f -name '*.sh' ! -name 'giv.sh' -exec cp {} "$SNAP_BUILD_TEMP/src/" \;
# Copy templates
cp -r templates/* "$SNAP_BUILD_TEMP/templates/"

# Fill in version in snapcraft.yaml template
sed "s/{{VERSION}}/${VERSION}/g" build/snap/snapcraft.yaml > "$SNAP_BUILD_TEMP/snapcraft.yaml"

# Move to dist
mkdir -p "${SNAP_DIST_DIR}"
rm -rf "${SNAP_DIST_DIR:?}/"*
mv "$SNAP_BUILD_TEMP"/* "${SNAP_DIST_DIR}/"

printf "Snap build completed. Files are in %s\n" "${SNAP_DIST_DIR}"
printf "To build the snap, run:\n  cd %s && snapcraft\n" "${SNAP_DIST_DIR}"
