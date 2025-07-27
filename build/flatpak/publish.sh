#!/bin/bash
set -euo pipefail

VERSION="$1"
FLATPAK_DIR="./dist/${VERSION}/flatpak"

# Validate inputs
if [[ -z "${VERSION:-}" ]]; then
    echo "ERROR: VERSION parameter is required" >&2
    exit 1
fi

if [[ ! -d "$FLATPAK_DIR" ]]; then
    echo "ERROR: Flatpak package directory not found: $FLATPAK_DIR" >&2
    exit 1
fi

cd "$FLATPAK_DIR"

# Check if flatpak-builder is installed
if ! command -v flatpak-builder >/dev/null 2>&1; then
    echo "ERROR: flatpak-builder not found" >&2
    echo "Install with your package manager:" >&2
    echo "  Ubuntu/Debian: sudo apt-get install flatpak-builder" >&2
    echo "  Fedora: sudo dnf install flatpak-builder" >&2
    echo "  Arch: sudo pacman -S flatpak-builder" >&2
    exit 1
fi

# Check if flatpak.json exists
if [[ ! -f "flatpak.json" ]]; then
    echo "ERROR: flatpak.json manifest not found in $FLATPAK_DIR" >&2
    exit 1
fi

echo "Building Flatpak package..."
if ! flatpak-builder build-dir flatpak.json --force-clean; then
    echo "ERROR: Failed to build Flatpak package" >&2
    exit 1
fi

echo "Flatpak build completed successfully"

# Information about publishing to Flathub
echo ""
echo "Flatpak publishing information:"
echo "=============================="
echo ""
echo "To publish to Flathub:"
echo "1. Fork https://github.com/flathub/flathub"
echo "2. Create a new repository: https://github.com/flathub/com.github.giv-cli.giv" 
echo "3. Add your manifest file (flatpak.json) to the repository"
echo "4. Test the build in the Flathub infrastructure"
echo "5. Submit for review following Flathub guidelines"
echo ""
echo "For more information: https://docs.flathub.org/docs/for-app-authors/submission/"
echo ""
echo "Build artifacts are in: $PWD/build-dir"