#!/bin/bash
set -euo pipefail

# Container build helper script
# Builds the giv-packages container with all necessary tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="giv-packages"
IMAGE_TAG="latest"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.packages"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build the giv-packages container with all necessary build tools.

OPTIONS:
    -t, --tag TAG       Container tag (default: latest)
    -n, --name NAME     Container image name (default: giv-packages)
    -f, --force         Force rebuild (no cache)
    -q, --quiet         Quiet build output
    -h, --help          Show this help message

EXAMPLES:
    $0                          # Build with default settings
    $0 -t v1.0.0               # Build with specific tag
    $0 -f                      # Force rebuild without cache
    $0 -n my-giv-packages      # Use custom image name
EOF
}

# Parse arguments
FORCE_BUILD=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_BUILD=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
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

FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"

echo "Building container image: $FULL_IMAGE_NAME"
echo "Dockerfile: $DOCKERFILE"
echo "Build context: $PROJECT_ROOT"

# Check if Dockerfile exists
if [[ ! -f "$DOCKERFILE" ]]; then
    echo "ERROR: Dockerfile not found: $DOCKERFILE" >&2
    exit 1
fi

# Build arguments
BUILD_ARGS=()
BUILD_ARGS+=("-t" "$FULL_IMAGE_NAME")
BUILD_ARGS+=("-f" "$DOCKERFILE")

if [[ "$FORCE_BUILD" == "true" ]]; then
    BUILD_ARGS+=("--no-cache")
fi

if [[ "$QUIET" == "true" ]]; then
    BUILD_ARGS+=("--quiet")
else
    BUILD_ARGS+=("--progress=plain")
fi

# Add the build context (project root)
BUILD_ARGS+=("$PROJECT_ROOT")

echo "Running: docker build ${BUILD_ARGS[*]}"

# Build the container
if docker build "${BUILD_ARGS[@]}"; then
    echo "✓ Container build successful: $FULL_IMAGE_NAME"
    
    # Show image info
    echo
    echo "Image details:"
    docker images "$IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    echo
    echo "Container is ready for use with:"
    echo "  ./build/container-run.sh [COMMAND]"
else
    echo "ERROR: Container build failed" >&2
    exit 1
fi