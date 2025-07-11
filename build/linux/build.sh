#!/usr/bin/env bash
set -eu

VERSION="$1"
BUILD_TEMP="$2"
TARGET="${3:-deb}"  # deb or rpm

PKG_ROOT="$BUILD_TEMP/${TARGET}_pkgroot"
BIN_DIR="$PKG_ROOT/usr/local/bin"
LIB_DIR="$PKG_ROOT/usr/local/lib/giv"
SHARE_TEMPLATES_DIR="$PKG_ROOT/usr/local/share/giv/templates"

# Clean and prepare dirs
rm -rf "$PKG_ROOT"
mkdir -p "$BIN_DIR" "$LIB_DIR" "$SHARE_TEMPLATES_DIR"

# Install main script
cp src/giv.sh "$BIN_DIR/giv"
chmod +x "$BIN_DIR/giv"

# Copy supporting scripts
find src -type f -name '*.sh' ! -name 'giv.sh' -exec cp {} "$LIB_DIR/" \;

# Copy templates
cp -r templates/* "$SHARE_TEMPLATES_DIR/"

# fpm build
PKG_NAME="giv"
DESC="Git history AI assistant CLI tool"
MAINTAINER="itlackey <noreply@github.com>"

OUT_DIR="./dist/${VERSION}/${TARGET}"
mkdir -p "$OUT_DIR"
fpm -s dir -t "$TARGET" \
    -n "$PKG_NAME" \
    -v "$VERSION" \
    --description "$DESC" \
    --maintainer "$MAINTAINER" \
    --prefix=/ \
    -C "$PKG_ROOT" \
    -p "$OUT_DIR/${PKG_NAME}_VERSION_ARCH.$TARGET"

printf "%s build completed. Files are in %s\n" "$TARGET" "$OUT_DIR"
