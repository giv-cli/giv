#!/bin/bash
set -euo pipefail

VERSION="$1"
PYPI_DIR="./dist/${VERSION}/pypi"

# Validate inputs
if [[ -z "${VERSION:-}" ]]; then
    echo "ERROR: VERSION parameter is required" >&2
    exit 1
fi

if [[ ! -d "$PYPI_DIR" ]]; then
    echo "ERROR: PyPI package directory not found: $PYPI_DIR" >&2
    exit 1
fi

cd "$PYPI_DIR"

# Validate setup.py exists
if [[ ! -f "setup.py" ]]; then
    echo "ERROR: setup.py not found in $PYPI_DIR" >&2
    exit 1
fi

# Install/check for twine and build tools
echo "Checking Python build dependencies..."
if ! command -v twine >/dev/null 2>&1; then
    echo "Installing twine..."
    pip install twine build
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/ dist/ *.egg-info/

# Build package
echo "Building Python package..."
if ! python setup.py sdist bdist_wheel; then
    echo "ERROR: Failed to build Python package" >&2
    exit 1
fi

# Check package with twine
echo "Validating package with twine..."
if ! twine check dist/*; then
    echo "ERROR: Package validation failed" >&2
    exit 1
fi

# Check if already published (optional - PyPI will reject duplicates anyway)
echo "Checking if version $VERSION is already published..."
if pip index versions giv 2>/dev/null | grep -q "Available versions: .*$VERSION"; then
    echo "WARNING: Version $VERSION may already be published to PyPI"
    echo "Attempting to publish anyway (PyPI will reject duplicates)"
fi

# Upload to PyPI
echo "Publishing giv==$VERSION to PyPI..."
if twine upload dist/* --non-interactive; then
    echo "Successfully published giv==$VERSION to PyPI"
else
    echo "ERROR: Failed to publish to PyPI" >&2
    exit 1
fi