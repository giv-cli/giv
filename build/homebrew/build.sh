#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"
HOMEBREW_BUILD_TEMP="$2/homebrew"
HOMEBREW_DIST_DIR="./dist/${VERSION}/homebrew"

# Prepare temp
rm -rf "$HOMEBREW_BUILD_TEMP"
mkdir -p "$HOMEBREW_BUILD_TEMP/src" "$HOMEBREW_BUILD_TEMP/templates"

# Copy files
cp src/giv.sh "$HOMEBREW_BUILD_TEMP/src/giv"
chmod +x "$HOMEBREW_BUILD_TEMP/src/giv"
find src -type f -name '*.sh' ! -name 'giv.sh' -exec cp {} "$HOMEBREW_BUILD_TEMP/src/" \;
cp -r templates/* "$HOMEBREW_BUILD_TEMP/templates/"

# Tarball everything (relative to the root of temp)
TARBALL_NAME="giv-${VERSION}.tar.gz"
tar -czf "$HOMEBREW_DIST_DIR/$TARBALL_NAME" -C "$HOMEBREW_BUILD_TEMP" .

# Calculate SHA256 for Homebrew formula
SHA256=$(shasum -a 256 "$HOMEBREW_DIST_DIR/$TARBALL_NAME" | awk '{print $1}')

# Prepare Formula (template below)
sed -e "s|{{VERSION}}|${VERSION}|g" \
    -e "s|{{TARBALL_URL}}|https://github.com/itlackey/giv/releases/download/v${VERSION}/$TARBALL_NAME|g" \
    -e "s|{{SHA256}}|$SHA256|g" \
    build/homebrew/giv.rb > "$HOMEBREW_DIST_DIR/giv.rb"

printf "Homebrew build completed. Files are in %s\n" "${HOMEBREW_DIST_DIR}"
printf "Upload %s to your releases, and update your tap with the new formula.\n" "$TARBALL_NAME"
