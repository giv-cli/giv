#!/bin/bash
set -euo pipefail

VERSION="$1"
HOMEBREW_DIR="./dist/${VERSION}/homebrew"

# Validate inputs
if [[ -z "${VERSION:-}" ]]; then
    echo "ERROR: VERSION parameter is required" >&2
    exit 1
fi

if [[ ! -d "$HOMEBREW_DIR" ]]; then
    echo "ERROR: Homebrew package directory not found: $HOMEBREW_DIR" >&2
    exit 1
fi

# Validate formula file exists
if [[ ! -f "$HOMEBREW_DIR/giv.rb" ]]; then
    echo "ERROR: Homebrew formula giv.rb not found in $HOMEBREW_DIR" >&2
    exit 1
fi

echo "Homebrew publishing requires manual steps:"
echo "1. Create a GitHub release with tarball attached"
echo "2. Update the Homebrew formula with the correct URL and SHA256"
echo "3. Submit a pull request to homebrew-core repository"
echo ""
echo "Formula location: $HOMEBREW_DIR/giv.rb"
echo "Version: $VERSION"
echo ""
echo "To publish to Homebrew:"
echo "1. Fork https://github.com/Homebrew/homebrew-core"
echo "2. Copy $HOMEBREW_DIR/giv.rb to Formula/ directory in your fork"
echo "3. Update the url and sha256 in the formula"
echo "4. Test with: brew install --build-from-source ./Formula/giv.rb"
echo "5. Submit pull request to homebrew-core"
echo ""
echo "For tap-based distribution (easier):"
echo "1. Create a homebrew-giv repository"
echo "2. Add the formula to Formula/giv.rb"
echo "3. Users can install with: brew install giv-cli/giv/giv"

# For now, we'll just validate the formula syntax
echo "Validating Homebrew formula syntax..."
if command -v brew >/dev/null 2>&1; then
    if brew formula-syntax "$HOMEBREW_DIR/giv.rb"; then
        echo "Homebrew formula syntax is valid"
    else
        echo "WARNING: Homebrew formula syntax validation failed"
        exit 1
    fi
else
    echo "WARNING: brew command not found, skipping formula validation"
fi

echo "Homebrew formula prepared at: $HOMEBREW_DIR/giv.rb"