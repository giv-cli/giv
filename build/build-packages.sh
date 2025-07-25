#!/bin/bash
set -euo pipefail

# Build all packages using containerized environment
# This script orchestrates the build process inside the giv-packages container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build all giv packages using containerized build environment.

OPTIONS:
    -v, --version VERSION   Override version detection
    -f, --force-build       Force rebuild of container
    -c, --clean             Clean dist directory before build
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Build all packages for detected version
    $0 -v 1.2.3             # Build packages for specific version
    $0 -f                   # Force rebuild container and packages
    $0 -c                   # Clean dist directory first
EOF
}

# Parse arguments
VERSION_OVERRIDE=""
FORCE_BUILD=false
CLEAN_DIST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION_OVERRIDE="$2"
            shift 2
            ;;
        -f|--force-build)
            FORCE_BUILD=true
            shift
            ;;
        -c|--clean)
            CLEAN_DIST=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Ensure container is built
echo "Ensuring giv-packages container is available..."
if [[ "$FORCE_BUILD" == "true" ]]; then
    "$SCRIPT_DIR/container-build.sh" -f
else
    if ! docker image inspect giv-packages:latest >/dev/null 2>&1; then
        echo "Container not found, building..."
        "$SCRIPT_DIR/container-build.sh"
    else
        echo "✓ Container already exists"
    fi
fi

# Detect version if not overridden
if [[ -n "$VERSION_OVERRIDE" ]]; then
    VERSION="$VERSION_OVERRIDE"
else
    VERSION=$(sed -n 's/__VERSION="\([^"]*\)"/\1/p' src/lib/system.sh)
fi

if [[ -z "$VERSION" ]]; then
    echo "ERROR: Could not detect version from src/lib/system.sh" >&2
    exit 1
fi

DIST_DIR="./dist/${VERSION}"

echo "Building GIV CLI version $VERSION using containerized environment..."

# Clean dist directory if requested
if [[ "$CLEAN_DIST" == "true" ]]; then
    echo "Cleaning dist directory..."
    rm -rf "$DIST_DIR"
fi

mkdir -p "$DIST_DIR"

# Run the actual build inside the container
echo "Starting containerized build process..."
if "$SCRIPT_DIR/container-run.sh" /workspace/build/build-packages-container.sh "$VERSION"; then
    echo "✓ Containerized build completed successfully"
    echo "Build artifacts are available in: $DIST_DIR"
else
    echo "ERROR: Containerized build failed" >&2
    exit 1
fi