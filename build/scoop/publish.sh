#!/bin/bash
set -euo pipefail

VERSION="$1"
SCOOP_DIR="./dist/${VERSION}/scoop"

# Validate inputs
if [[ -z "${VERSION:-}" ]]; then
    echo "ERROR: VERSION parameter is required" >&2
    exit 1
fi

if [[ ! -d "$SCOOP_DIR" ]]; then
    echo "ERROR: Scoop package directory not found: $SCOOP_DIR" >&2
    exit 1
fi

# Validate scoop manifest exists
if [[ ! -f "$SCOOP_DIR/giv.json" ]]; then
    echo "ERROR: Scoop manifest giv.json not found in $SCOOP_DIR" >&2
    exit 1
fi

echo "Scoop publishing information:"
echo "============================"
echo ""
echo "Scoop packages are distributed through 'buckets' (Git repositories)."
echo ""
echo "Options for publishing:"
echo ""
echo "1. Official Scoop bucket (main):"
echo "   - Fork https://github.com/ScoopInstaller/Main"
echo "   - Add your manifest to bucket/giv.json"
echo "   - Submit a pull request"
echo "   - Must meet Scoop quality guidelines"
echo ""
echo "2. Create your own bucket (recommended for new apps):"
echo "   - Create a Git repository (e.g., scoop-giv)"
echo "   - Add the manifest file as giv.json"
echo "   - Users install with: scoop bucket add giv https://github.com/yourusername/scoop-giv"
echo "   - Then: scoop install giv"
echo ""
echo "3. Direct installation (for testing):"
echo "   - Users can install directly from URL:"
echo "   - scoop install https://raw.githubusercontent.com/yourusername/repo/main/giv.json"
echo ""

# Validate the manifest if possible
echo "Validating Scoop manifest..."

# Basic JSON validation
if command -v jq >/dev/null 2>&1; then
    if jq empty "$SCOOP_DIR/giv.json" 2>/dev/null; then
        echo "✓ JSON syntax is valid"
    else
        echo "ERROR: Invalid JSON in Scoop manifest" >&2
        exit 1
    fi
    
    # Check required fields
    required_fields=("version" "url" "bin" "description")
    for field in "${required_fields[@]}"; do
        if jq -e ".$field" "$SCOOP_DIR/giv.json" >/dev/null 2>&1; then
            echo "✓ Required field '$field' present"
        else
            echo "ERROR: Required field '$field' missing from manifest" >&2
            exit 1
        fi
    done
else
    echo "WARNING: jq not found, skipping JSON validation"
fi

echo ""
echo "Scoop manifest ready at: $SCOOP_DIR/giv.json"
echo "Version: $VERSION"
echo ""
echo "Next steps:"
echo "1. Ensure you have a GitHub release with the required binaries"
echo "2. Update the URL and hash in the manifest if needed"
echo "3. Choose a publishing method from the options above"