#!/bin/bash
set -euo pipefail

# Publish all packages using containerized environment
# This script orchestrates the publishing process inside the giv-packages container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [BUMP_TYPE] [VERSION_SUFFIX]

Publish giv packages using containerized build environment.

ARGUMENTS:
    BUMP_TYPE           Version bump type: major, minor, patch (default: patch)
    VERSION_SUFFIX      Version suffix like -beta, -rc1 (optional)

OPTIONS:
    -v, --version VERSION   Use specific version instead of bumping
    -p, --packages LIST     Comma-separated list of packages to publish
                           (npm,pypi,docker,github)
    -f, --force-build       Force rebuild of container
    -n, --no-build          Skip build step (use existing packages)
    --dry-run               Show what would be published without doing it
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Patch version bump and publish all
    $0 minor                # Minor version bump and publish all
    $0 major -beta          # Major version bump with beta suffix
    $0 -v 1.2.3             # Publish specific version
    $0 -p npm,pypi          # Publish only to npm and PyPI
    $0 --dry-run            # Show what would be published
EOF
}

# Parse arguments
VERSION_OVERRIDE=""
PACKAGES_LIST=""
FORCE_BUILD=false
NO_BUILD=false
DRY_RUN=false
BUMP_TYPE="patch"
VERSION_SUFFIX=""

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
        -n|--no-build)
            NO_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        major|minor|patch)
            BUMP_TYPE="$1"
            shift
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            # First non-option argument is version suffix
            if [[ -z "$VERSION_SUFFIX" ]]; then
                VERSION_SUFFIX="$1"
                shift
            else
                echo "ERROR: Unexpected argument: $1" >&2
                usage
                exit 1
            fi
            ;;
    esac
done

# Validate bump type
validate_bump_type() {
    local bump="$1"
    case "$bump" in
        major|minor|patch) ;;
        *)
            echo "ERROR: Invalid bump type: $bump" >&2
            echo "Valid options: major, minor, patch" >&2
            exit 1
            ;;
    esac
}

# Input validation functions
validate_version_format() {
    local version="$1"
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
        echo "ERROR: Invalid version format: $version" >&2
        echo "Expected format: X.Y.Z or X.Y.Z-suffix" >&2
        exit 1
    fi
}

validate_bump_type "$BUMP_TYPE"

VERSION_FILE="src/giv.sh"

# Validate version file exists
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "ERROR: Version file not found: $VERSION_FILE" >&2
    exit 1
fi

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

# Determine version to use
if [[ -n "$VERSION_OVERRIDE" ]]; then
    VERSION="$VERSION_OVERRIDE"
    echo "Using specified version: $VERSION"
else
    echo "Publishing using containerized environment..."
    echo "Bump type: $BUMP_TYPE"
    if [[ -n "$VERSION_SUFFIX" ]]; then
        echo "Version suffix: $VERSION_SUFFIX"
    fi
fi

# Build container arguments
CONTAINER_ARGS=()
if [[ -n "$PACKAGES_LIST" ]]; then
    CONTAINER_ARGS+=("-e" "PUBLISH_PACKAGES=$PACKAGES_LIST")
fi

if [[ "$DRY_RUN" == "true" ]]; then
    CONTAINER_ARGS+=("-e" "DRY_RUN=true")
fi

if [[ "$NO_BUILD" == "true" ]]; then
    CONTAINER_ARGS+=("-e" "NO_BUILD=true")
fi

# Pass through authentication environment variables
AUTH_ENV_VARS=("NPM_TOKEN" "PYPI_TOKEN" "DOCKER_HUB_PASSWORD" "GITHUB_TOKEN")
for env_var in "${AUTH_ENV_VARS[@]}"; do
    if [[ -n "${!env_var:-}" ]]; then
        CONTAINER_ARGS+=("-e" "$env_var=${!env_var}")
    fi
done

# Run the actual publishing inside the container
echo "Starting containerized publishing process..."
if [[ -n "$VERSION_OVERRIDE" ]]; then
    if "$SCRIPT_DIR/container-run.sh" "${CONTAINER_ARGS[@]}" /workspace/build/publish-packages-container.sh "$VERSION"; then
        echo "✓ Containerized publishing completed successfully"
    else
        echo "ERROR: Containerized publishing failed" >&2
        exit 1
    fi
else
    if "$SCRIPT_DIR/container-run.sh" "${CONTAINER_ARGS[@]}" /workspace/build/publish-packages-container.sh "$BUMP_TYPE" "$VERSION_SUFFIX"; then
        echo "✓ Containerized publishing completed successfully"
    else
        echo "ERROR: Containerized publishing failed" >&2
        exit 1
    fi
fi
