#!/bin/bash
set -euo pipefail

VERSION="$1"
NPM_DIR="./dist/${VERSION}/npm"

# Validate inputs
if [[ -z "${VERSION:-}" ]]; then
    echo "ERROR: VERSION parameter is required" >&2
    exit 1
fi

if [[ ! -d "$NPM_DIR" ]]; then
    echo "ERROR: npm package directory not found: $NPM_DIR" >&2
    exit 1
fi

cd "$NPM_DIR"

# Validate package.json exists and is valid
if [[ ! -f "package.json" ]]; then
    echo "ERROR: package.json not found in $NPM_DIR" >&2
    exit 1
fi

# Validate package with npm pack --dry-run
echo "Validating npm package..."
if ! npm pack --dry-run; then
    echo "ERROR: npm package validation failed" >&2
    exit 1
fi

# Check if already published
echo "Checking if version $VERSION is already published..."
if npm view "giv@$VERSION" version 2>/dev/null; then
    echo "WARNING: Version $VERSION already published to npm"
    echo "Skipping npm publish"
    exit 0
fi

# Publish with error handling
echo "Publishing giv@$VERSION to npm..."
if npm publish --access public; then
    echo "Successfully published giv@$VERSION to npm"
else
    echo "ERROR: Failed to publish to npm" >&2
    exit 1
fi