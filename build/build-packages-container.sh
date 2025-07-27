#!/bin/bash
set -euo pipefail

# Container-internal build script
# This script runs inside the giv-packages container and performs the actual build

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "ERROR: Version not provided" >&2
    exit 1
fi

echo "Building GIV CLI version $VERSION inside container..."

# Set up build environment
mkdir -p .tmp
BUILD_TEMP=$(mktemp -d -p .tmp)
DIST_DIR="./dist/${VERSION}"

echo "Build temp directory: $BUILD_TEMP"
echo "Distribution directory: $DIST_DIR"

# Clean and create dist directory
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# All necessary tools should be pre-installed in the container
echo "Verifying build tools..."

# Check for required tools
MISSING_TOOLS=()

if ! command -v fpm >/dev/null 2>&1; then
    MISSING_TOOLS+=("fpm")
fi

if ! command -v npm >/dev/null 2>&1; then
    MISSING_TOOLS+=("npm")
fi

if ! command -v python3 >/dev/null 2>&1; then
    MISSING_TOOLS+=("python3")
fi

if ! command -v gem >/dev/null 2>&1; then
    MISSING_TOOLS+=("gem")
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo "ERROR: Missing required build tools: ${MISSING_TOOLS[*]}" >&2
    echo "The container may not have been built correctly." >&2
    exit 1
fi

echo "✓ All required build tools are available"

# Prepare package files
mkdir -p "${BUILD_TEMP}/package"
cp -r src templates docs "${BUILD_TEMP}/package/"
echo "Copied src, templates, docs to ${BUILD_TEMP}/package/"

cp README.md "${BUILD_TEMP}/package/docs"
mv "${BUILD_TEMP}/package/src/giv.sh" "${BUILD_TEMP}/package/src/giv"

# Collect file lists for setup.py
SH_FILES=$(find "${BUILD_TEMP}/package/src" -type f -name '*.sh' -print0 | xargs -0 -I{} bash -c 'printf "src/%s " "$(basename "{}")"')
TEMPLATE_FILES=$(find "${BUILD_TEMP}/package/templates" -type f -print0 | xargs -0 -I{} bash -c 'printf "templates/%s " "$(basename "{}")"')
DOCS_FILES=$(find "${BUILD_TEMP}/package/docs" -type f -print0 | xargs -0 -I{} bash -c 'printf "docs/%s " "$(basename "{}")"')

export SH_FILES TEMPLATE_FILES DOCS_FILES

echo "Building packages..."

# Build each package type
echo "Building npm package..."
./build/npm/build.sh "${VERSION}" "${BUILD_TEMP}"

echo "Building PyPI package..."
./build/pypi/build.sh "${VERSION}" "${BUILD_TEMP}"

echo "Building Homebrew formula..."
./build/homebrew/build.sh "${VERSION}" "${BUILD_TEMP}"

echo "Building Scoop manifest..."
./build/scoop/build.sh "${VERSION}" "${BUILD_TEMP}"

echo "Building Linux packages (deb/rpm)..."
./build/linux/build.sh "${VERSION}" "${BUILD_TEMP}" "deb"
./build/linux/build.sh "${VERSION}" "${BUILD_TEMP}" "rpm"

echo "Building Snap package..."
./build/snap/build.sh "${VERSION}" "${BUILD_TEMP}"

echo "Building Flatpak package..."
./build/flatpak/build.sh "${VERSION}" "${BUILD_TEMP}"

echo "Building Docker image..."
./build/docker/build.sh "${VERSION}" "${BUILD_TEMP}"

# Clean up temp directory
rm -rf "${BUILD_TEMP}"

echo "Build completed successfully!"
echo "Artifacts are available in: ${DIST_DIR}"

# List built artifacts
echo
echo "Built artifacts:"
find "${DIST_DIR}" -type f -exec basename {} \; | sort