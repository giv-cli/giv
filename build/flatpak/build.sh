#!/usr/bin/env bash
set -eu

VERSION="$1"
FLATPAK_BUILD_TEMP="$2"
FLATPAK_DIST_DIR="./dist/${VERSION}/flatpak"

rm -rf "${FLATPAK_DIST_DIR}"
mkdir -p "${FLATPAK_DIST_DIR}"

# Ensure file lists are set
SH_FILES="${SH_FILES:-}"
TEMPLATE_FILES="${TEMPLATE_FILES:-}"
DOCS_FILES="${DOCS_FILES:-}"

# Build sources array as valid JSON
SOURCES_JSON="["
for f in $SH_FILES $TEMPLATE_FILES $DOCS_FILES; do
    [ -n "$f" ] && SOURCES_JSON="$SOURCES_JSON{\"type\": \"file\", \"path\": \"$f\"},"
done
SOURCES_JSON="${SOURCES_JSON%,}]"  # Remove trailing comma, close array

# Use jq to replace sources array in the template
jq --argjson sources "$SOURCES_JSON" \
   --arg version "$VERSION" \
   '.sources = $sources | .version = $version' \
   build/flatpak/flatpak.json > "$FLATPAK_DIST_DIR/flatpak.json"

cp -r "${FLATPAK_BUILD_TEMP}/package/"* "${FLATPAK_DIST_DIR}/"


printf "Flatpak build completed. Files are in %s\n" "${FLATPAK_DIST_DIR}"
printf "To build the flatpak, run:\n  flatpak-builder build-dir flatpak.json --force-clean\n"
