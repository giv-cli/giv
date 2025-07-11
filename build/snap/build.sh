#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"
SNAP_BUILD_TEMP="$2"
SNAP_DIST_DIR="./dist/${VERSION}/snap"

# Move to dist
mkdir -p "${SNAP_DIST_DIR}"
rm -rf "${SNAP_DIST_DIR:?}/"*

# Fill in version in snapcraft.yaml template
sed "s/{{VERSION}}/${VERSION}/g" build/snap/snapcraft.yaml >"$SNAP_DIST_DIR/snapcraft.yaml"
cp -r "${SNAP_BUILD_TEMP}/package/"* "${SNAP_DIST_DIR}/"

printf "Snap build completed. Files are in %s\n" "${SNAP_DIST_DIR}"
printf "To build the snap, run:\n  cd %s && snapcraft\n" "${SNAP_DIST_DIR}"
