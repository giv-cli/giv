#!/bin/bash
# npm package validator
# Tests npm package installation and functionality across different platforms

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

# Configuration
DOCKER_DIR="$SCRIPT_DIR/../docker"
WORKSPACE="/workspace"

main() {
    local platform="${1:-ubuntu}"
    local version="${2:-}"
    
    if [[ -z "$version" ]]; then
        log_error "Version parameter is required"
        exit 1
    fi
    
    log_info "Starting npm validation on $platform (version: $version)"
    
    # Platform-specific Docker image names
    local image_name="giv-test-$platform"
    local container_name="giv-test-$platform"
    
    # Build Docker image for the platform
    if ! build_docker_image "$DOCKER_DIR/$platform" "$image_name"; then
        log_error "Failed to build Docker image for $platform"
        exit 1
    fi
    
    # Start test container
    if ! start_container "$image_name" "$container_name" "$WORKSPACE"; then
        log_error "Failed to start container"
        exit 1
    fi
    
    # Ensure npm package is built
    if ! ensure_package_built "npm" "$version"; then
        log_error "npm package not available for testing"
        stop_container "$container_name"
        exit 1
    fi
    
    # Run validation tests
    local exit_code=0
    
    # Test 1: Validate build environment
    validate_build_environment "$container_name" || exit_code=1
    
    # Test 2: Install npm package from local tarball
    test_npm_install "$container_name" "$version" || exit_code=1
    
    # Test 3: Validate installation 
    validate_giv_installation "$container_name" "npm" || exit_code=1
    
    # Test 4: Test core functionality
    test_giv_functionality "$container_name" || exit_code=1
    
    # Test 5: Cleanup and verify removal
    cleanup_package "$container_name" "npm" "giv" || exit_code=1
    
    # Stop container
    stop_container "$container_name"
    
    # Print test summary and exit
    if test_summary; then
        log_success "npm validation completed successfully on $platform"
        exit 0
    else
        log_error "npm validation failed on $platform"
        exit 1
    fi
}

test_npm_install() {
    local container="$1"
    local version="$2"
    
    test_start "Installing npm package (version $version)"
    
    # Find the npm tarball
    local npm_tarball
    if ! npm_tarball=$(find "./dist/$version" -name "giv-*.tgz" | head -1); then
        test_fail "No npm tarball found in ./dist/$version"
        return 1
    fi
    
    if [[ ! -f "$npm_tarball" ]]; then
        test_fail "npm tarball not found: $npm_tarball"
        return 1
    fi
    
    log_info "Found npm package: $npm_tarball"
    
    # Copy tarball to container workspace (it's already mounted)
    local tarball_name
    tarball_name=$(basename "$npm_tarball")
    
    # Install from local tarball
    if exec_in_container "$container" "npm install -g $WORKSPACE/$npm_tarball"; then
        test_pass "npm package installed successfully"
        return 0
    else
        test_fail "Failed to install npm package"
        return 1
    fi
}

test_giv_functionality() {
    local container="$1"
    
    test_start "Testing giv functionality"
    
    # Create a test git repository in the container
    local test_repo="/tmp/test-repo"
    exec_in_container "$container" "
        mkdir -p '$test_repo' && cd '$test_repo' &&
        git init -q &&
        git config user.name 'Test User' &&
        git config user.email 'test@example.com' &&
        echo 'Hello World' > README.md &&
        git add README.md &&
        git commit -q -m 'Initial commit' &&
        echo 'Updated content' >> README.md &&
        git add README.md &&
        git commit -q -m 'feat: update readme'
    "
    
    # Test giv message command (dry run to avoid needing API keys)
    if exec_in_container "$container" "cd '$test_repo' && giv message --dry-run"; then
        test_pass "giv message command works"
    else
        test_fail "giv message command failed"
        return 1
    fi
    
    # Test giv summary command
    if exec_in_container "$container" "cd '$test_repo' && giv summary --dry-run"; then
        test_pass "giv summary command works"
    else
        test_fail "giv summary command failed"
        return 1
    fi
    
    # Test giv config command
    if exec_in_container "$container" "cd '$test_repo' && giv config --help"; then
        test_pass "giv config command works"
    else
        test_fail "giv config command failed"
        return 1
    fi
    
    return 0
}

# Platform-specific npm setup
setup_npm_environment() {
    local container="$1"
    local platform="$2"
    
    case "$platform" in
        ubuntu|debian)
            # npm should already be installed from Dockerfile
            exec_in_container "$container" "npm --version" >/dev/null
            ;;
        fedora)
            # npm should already be installed from Dockerfile
            exec_in_container "$container" "npm --version" >/dev/null
            ;;
        alpine)
            # npm should already be installed from Dockerfile
            exec_in_container "$container" "npm --version" >/dev/null
            ;;
        arch)
            # npm should already be installed from Dockerfile
            exec_in_container "$container" "npm --version" >/dev/null
            ;;
        *)
            log_warning "Unknown platform: $platform, assuming npm is available"
            ;;
    esac
}

# Run main function with provided arguments
main "$@"