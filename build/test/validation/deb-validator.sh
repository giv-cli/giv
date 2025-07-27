#!/bin/bash
# Debian package validator
# Tests .deb package installation and functionality on Debian-based platforms

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
    
    # Only test on Debian-based platforms
    case "$platform" in
        ubuntu|debian)
            ;;
        *)
            log_warning "Debian packages not supported on $platform, skipping"
            exit 0
            ;;
    esac
    
    log_info "Starting Debian package validation on $platform (version: $version)"
    
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
    
    # Ensure Debian package is built
    if ! ensure_package_built "deb" "$version"; then
        log_error "Debian package not available for testing"
        stop_container "$container_name"
        exit 1
    fi
    
    # Run validation tests
    local exit_code=0
    
    # Test 1: Validate build environment
    validate_build_environment "$container_name" || exit_code=1
    
    # Test 2: Install Debian package
    test_deb_install "$container_name" "$version" || exit_code=1
    
    # Test 3: Validate installation 
    validate_giv_installation "$container_name" "dpkg" || exit_code=1
    
    # Test 4: Test package metadata
    test_package_metadata "$container_name" || exit_code=1
    
    # Test 5: Test core functionality
    test_giv_functionality "$container_name" || exit_code=1
    
    # Test 6: Cleanup and verify removal
    cleanup_package "$container_name" "dpkg" "giv" || exit_code=1
    
    # Stop container
    stop_container "$container_name"
    
    # Print test summary and exit
    if test_summary; then
        log_success "Debian package validation completed successfully on $platform"
        exit 0
    else
        log_error "Debian package validation failed on $platform"
        exit 1
    fi
}

test_deb_install() {
    local container="$1"
    local version="$2"
    
    test_start "Installing Debian package (version $version)"
    
    # Find the .deb file
    local deb_file
    if ! deb_file=$(find "./dist/$version" -name "giv*.deb" | head -1); then
        test_fail "No .deb file found in ./dist/$version"
        return 1
    fi
    
    if [[ ! -f "$deb_file" ]]; then
        test_fail "Debian package not found: $deb_file"
        return 1
    fi
    
    log_info "Found Debian package: $deb_file"
    
    # Update package lists first
    if ! exec_in_container "$container" "sudo apt-get update -qq"; then
        test_fail "Failed to update package lists"
        return 1
    fi
    
    # Install the package using dpkg
    local deb_name
    deb_name=$(basename "$deb_file")
    
    if exec_in_container "$container" "sudo dpkg -i '$WORKSPACE/$deb_file'"; then
        test_pass "Debian package installed successfully"
        
        # Fix any dependency issues that might have occurred
        exec_in_container "$container" "sudo apt-get install -f -y" || true
        
        return 0
    else
        # If dpkg fails, try to fix dependencies and retry
        log_info "Attempting to fix dependencies..."
        exec_in_container "$container" "sudo apt-get install -f -y"
        
        if exec_in_container "$container" "sudo dpkg -i '$WORKSPACE/$deb_file'"; then
            test_pass "Debian package installed successfully after dependency fix"
            return 0
        else
            test_fail "Failed to install Debian package"
            return 1
        fi
    fi
}

test_package_metadata() {
    local container="$1"
    
    test_start "Testing package metadata"
    
    # Check if package is properly registered
    if exec_in_container "$container" "dpkg -l | grep -q giv"; then
        test_pass "Package is registered in dpkg database"
    else
        test_fail "Package not found in dpkg database"
        return 1
    fi
    
    # Check package information
    if exec_in_container "$container" "dpkg -s giv"; then
        test_pass "Package status information available"
    else
        test_fail "Failed to get package status"
        return 1
    fi
    
    # List package files
    if exec_in_container "$container" "dpkg -L giv | head -10"; then
        test_pass "Package file list available"
    else
        test_fail "Failed to list package files"
        return 1
    fi
    
    return 0
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
    
    # Test that config directory structure was created properly
    if exec_in_container "$container" "test -d /usr/share/giv || test -d /opt/giv"; then
        test_pass "Application files installed in correct location"
    else
        test_fail "Application files not found in expected locations"
        return 1
    fi
    
    return 0
}

# Run main function with provided arguments
main "$@"