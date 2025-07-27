#!/usr/bin/env bash
set -euo pipefail

# Validate package installations using containerized environment
# This script orchestrates validation inside the giv-packages container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate giv package installations using containerized environment.

OPTIONS:
    -v, --version VERSION   Override version detection
    -p, --packages LIST     Comma-separated list of packages to test
                           (deb,rpm,pypi,npm,homebrew,snap)
    -f, --force-build       Force rebuild of container
    -r, --report FILE       Generate validation report
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Test all packages for detected version
    $0 -v 1.2.3             # Test packages for specific version
    $0 -p deb,rpm           # Test only deb and rpm packages
    $0 -r report.json       # Generate validation report
EOF
}

# Parse arguments
VERSION_OVERRIDE=""
PACKAGES_LIST=""
FORCE_BUILD=false
REPORT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION_OVERRIDE="$2"
            shift 2
            ;;
        -p|--packages)
            PACKAGES_LIST="$2"
            shift 2
            ;;
        -f|--force-build)
            FORCE_BUILD=true
            shift
            ;;
        -r|--report)
            REPORT_FILE="$2"
            shift 2
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
    VERSION=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' src/giv.sh)
fi

if [[ -z "$VERSION" ]]; then
    echo "ERROR: Could not detect version from src/giv.sh" >&2
    exit 1
fi

echo "Validating GIV CLI version $VERSION using containerized environment..."

# Build container arguments
CONTAINER_ARGS=()
if [[ -n "$PACKAGES_LIST" ]]; then
    CONTAINER_ARGS+=("-e" "TEST_PACKAGES=$PACKAGES_LIST")
fi

if [[ -n "$REPORT_FILE" ]]; then
    CONTAINER_ARGS+=("-e" "REPORT_FILE=$REPORT_FILE")
fi

# Run the actual validation inside the container
echo "Starting containerized validation process..."
if "$SCRIPT_DIR/container-run.sh" "${CONTAINER_ARGS[@]}" /workspace/build/validate-installs-container.sh "$VERSION"; then
    echo "✓ Containerized validation completed successfully"
    
    if [[ -n "$REPORT_FILE" ]]; then
        echo "Validation report saved to: $REPORT_FILE"
    fi
else
    echo "ERROR: Containerized validation failed" >&2
    exit 1
fi

# All validation logic has been moved to validate-installs-container.sh
# This script now only orchestrates the containerized validation
