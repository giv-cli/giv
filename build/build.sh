#! /bin/bash

BUILD_TEMP=$(mktemp -d)
DIST_DIR="./dist"
VERSION=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' ../giv/src/giv.sh)
printf "Building GIV CLI version %s...\n" "${VERSION}"
# npm build section
mkdir -p "${BUILD_TEMP}/npm"
cp -r src templates "${BUILD_TEMP}/npm/"
sed "s/{{VERSION}}/${VERSION}/g" build/npm/package.json.template > "${BUILD_TEMP}/npm/package.json"
cp README.md "${BUILD_TEMP}/npm/"  # Optional, but recommended
# Copy BUILD_TEMP to DIST_DIR
mkdir -p "${DIST_DIR}/npm"
cp -r "${BUILD_TEMP}/npm"/* "${DIST_DIR}/npm/"


printf "Build completed. Files are in %s\n" "${DIST_DIR}"