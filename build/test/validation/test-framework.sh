#!/bin/bash
# Simple test to validate the framework is working

set -e

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

echo "Testing validation framework..."

# Test 1: Check that all validator scripts are executable
echo "Checking validator executables..."
for validator in npm pypi deb rpm docker; do
    if [[ -x "$SCRIPT_DIR/${validator}-validator.sh" ]]; then
        echo "✓ ${validator}-validator.sh is executable"
    else
        echo "✗ ${validator}-validator.sh is not executable"
        exit 1
    fi
done

# Test 2: Check common functions are available
echo "Testing common functions..."
if source "$SCRIPT_DIR/common.sh"; then
    echo "✓ common.sh sourced successfully"
else
    echo "✗ Failed to source common.sh"
    exit 1
fi

# Test 3: Test version detection
echo "Testing version detection..."
if source "$SCRIPT_DIR/../../config.sh" && VERSION=$(get_version); then
    echo "✓ Version detected: $VERSION"
else
    echo "✗ Failed to detect version"
    exit 1
fi

# Test 4: Check Docker environment files exist
echo "Testing Docker environments..."
for platform in ubuntu debian fedora alpine arch; do
    if [[ -f "$SCRIPT_DIR/../docker/$platform/Dockerfile" ]]; then
        echo "✓ Docker environment for $platform exists"
    else
        echo "✗ Docker environment for $platform missing"
        exit 1
    fi
done

# Test 5: Test package validator help
echo "Testing package validator..."
if "$SCRIPT_DIR/package-validator.sh" --help >/dev/null 2>&1; then
    echo "✓ Package validator help works"
else
    echo "✗ Package validator help failed"
    exit 1
fi

echo ""
echo "🎉 All framework tests passed!"
echo ""
echo "Framework Summary:"
echo "- 5 package validators: npm, pypi, deb, rpm, docker"
echo "- 5 Docker test environments: ubuntu, debian, fedora, alpine, arch"
echo "- Version detection: $VERSION"
echo "- Main orchestrator: package-validator.sh"
echo ""
echo "To run validation (requires built packages):"
echo "  ./build/test/validation/package-validator.sh -b -c"
echo ""
echo "To test specific package/platform combinations:"
echo "  ./build/test/validation/package-validator.sh -p ubuntu -k npm,deb"