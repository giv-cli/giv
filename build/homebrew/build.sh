#!/usr/bin/env bash
set -eu

VERSION="$1"
HOMEBREW_BUILD_TEMP="$2/package"
HOMEBREW_DIST_DIR="./dist/${VERSION}/homebrew"


# Ensure dist directory exists
mkdir -p "$HOMEBREW_DIST_DIR"
cp -rf "${HOMEBREW_BUILD_TEMP}" "${HOMEBREW_DIST_DIR}/"

# Tarball everything (relative to the root of temp)
TARBALL_NAME="giv-${VERSION}.tar.gz"
tar -czf "$HOMEBREW_DIST_DIR/$TARBALL_NAME" -C "$HOMEBREW_BUILD_TEMP" .

# Calculate SHA256 for Homebrew formula
SHA256=$(shasum -a 256 "$HOMEBREW_DIST_DIR/$TARBALL_NAME" | awk '{print $1}')

# Prepare Formula (template below)
sed -e "s|{{VERSION}}|${VERSION}|g" \
    -e "s|{{TARBALL_URL}}|https://github.com/giv-cli/giv/releases/download/v${VERSION}/$TARBALL_NAME|g" \
    -e "s|{{SHA256}}|$SHA256|g" \
    build/homebrew/giv.rb > "$HOMEBREW_DIST_DIR/giv.rb"

sed -e "s|{{VERSION}}|${VERSION}|g" \
    -e "s|{{SHA256}}|$SHA256|g" \
    build/homebrew/giv.local.rb > "$HOMEBREW_DIST_DIR/giv.local.rb"

rm -rf "$HOMEBREW_DIST_DIR/package"
printf "Homebrew build completed. Files are in %s\n" "${HOMEBREW_DIST_DIR}"
printf "Upload %s to your releases, and update your tap with the new formula.\n" "$TARBALL_NAME"
