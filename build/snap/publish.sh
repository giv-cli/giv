#!/bin/bash
set -euo pipefail

VERSION="$1"
SNAP_DIR="./dist/${VERSION}/snap"

# Validate inputs
if [[ -z "${VERSION:-}" ]]; then
    echo "ERROR: VERSION parameter is required" >&2
    exit 1
fi

if [[ ! -d "$SNAP_DIR" ]]; then
    echo "ERROR: Snap package directory not found: $SNAP_DIR" >&2
    exit 1
fi

# Find the snap file
SNAP_FILE=$(find "$SNAP_DIR" -name "*.snap" | head -1)
if [[ -z "$SNAP_FILE" || ! -f "$SNAP_FILE" ]]; then
    echo "ERROR: Snap package file not found in $SNAP_DIR" >&2
    exit 1
fi

echo "Found snap package: $SNAP_FILE"

# Check if snapcraft is available
if ! command -v snapcraft >/dev/null 2>&1; then
    echo "ERROR: snapcraft command not found" >&2
    echo "Install with: sudo snap install snapcraft --classic" >&2
    exit 1
fi

# Check if logged in to Snap Store
if ! snapcraft whoami >/dev/null 2>&1; then
    echo "ERROR: Not logged in to Snap Store" >&2
    echo "Login with: snapcraft login" >&2
    exit 1
fi

# Check if snap name is registered
echo "Checking if snap name 'giv' is registered..."
if ! snapcraft list-registered | grep -q "giv"; then
    echo "ERROR: Snap name 'giv' is not registered to this account" >&2
    echo "Register with: snapcraft register giv" >&2
    exit 1
fi

# Upload to Snap Store
echo "Uploading $SNAP_FILE to Snap Store..."
if snapcraft upload "$SNAP_FILE"; then
    echo "Successfully uploaded snap package"
    
    # Get the revision number from the upload
    echo "Checking upload status..."
    snapcraft list-revisions giv
    
    echo ""
    echo "To release to a channel, run:"
    echo "snapcraft release giv <revision> <channel>"
    echo "Example: snapcraft release giv 1 stable"
    
else
    echo "ERROR: Failed to upload snap package" >&2
    exit 1
fi