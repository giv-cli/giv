#!/bin/bash
# RPM package validator
# Tests .rpm package installation and functionality on RPM-based platforms

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

# Configuration
DOCKER_DIR="$SCRIPT_DIR/../docker"
WORKSPACE="/workspace"

main() {
    local platform="${1:-fedora}"
    local version="${2:-}"
    
    if [[ -z "$version" ]]; then
        log_error "Version parameter is required"
        exit 1
    fi
    
    # Only test on RPM-based platforms
    case "$platform" in
        fedora|centos|rhel)
            ;;
        *)
            log_warning "RPM packages not supported on $platform, skipping"
            exit 0
            ;;
    esac
    
    log_info "Starting RPM package validation on $platform (version: $version)"
    
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
    
    # Ensure RPM package is built
    if ! ensure_package_built "rpm" "$version"; then
        log_error "RPM package not available for testing"
        stop_container "$container_name"
        exit 1
    fi
    
    # Run validation tests
    local exit_code=0
    
    # Test 1: Validate build environment
    validate_build_environment "$container_name" || exit_code=1
    
    # Test 2: Install RPM package
    test_rpm_install "$container_name" "$version" || exit_code=1
    
    # Test 3: Validate installation 
    validate_giv_installation "$container_name" "rpm" || exit_code=1
    
    # Test 4: Test package metadata
    test_package_metadata "$container_name" || exit_code=1
    
    # Test 5: Test core functionality
    test_giv_functionality "$container_name" || exit_code=1
    
    # Test 6: Cleanup and verify removal
    cleanup_package "$container_name" "rpm" "giv" || exit_code=1
    
    # Stop container
    stop_container "$container_name"
    
    # Print test summary and exit
    if test_summary; then
        log_success "RPM package validation completed successfully on $platform"
        exit 0
    else
        log_error "RPM package validation failed on $platform"
        exit 1
    fi
}

test_rpm_install() {
    local container="$1"
    local version="$2"
    
    test_start "Installing RPM package (version $version)"
    
    # Find the .rpm file
    local rpm_file
    if ! rpm_file=$(find "./dist/$version" -name "giv*.rpm" | head -1); then
        test_fail "No .rpm file found in ./dist/$version"
        return 1
    fi
    
    if [[ ! -f "$rpm_file" ]]; then
        test_fail "RPM package not found: $rpm_file"
        return 1
    fi
    
    log_info "Found RPM package: $rpm_file"
    
    # Install the package using rpm or dnf
    local rpm_name
    rpm_name=$(basename "$rpm_file")
    
    # Try dnf first (preferred), then fall back to rpm
    if exec_in_container "$container" "sudo dnf install -y '$WORKSPACE/$rpm_file'"; then
        test_pass "RPM package installed successfully with dnf"
        return 0
    elif exec_in_container "$container" "sudo yum install -y '$WORKSPACE/$rpm_file'"; then
        test_pass "RPM package installed successfully with yum"
        return 0
    elif exec_in_container "$container" "sudo rpm -i '$WORKSPACE/$rpm_file'"; then
        test_pass "RPM package installed successfully with rpm"
        return 0
    else
        test_fail "Failed to install RPM package"
        return 1
    fi
}

test_package_metadata() {
    local container="$1"
    
    test_start "Testing package metadata"
    
    # Check if package is properly registered
    if exec_in_container "$container" "rpm -qa | grep -q giv"; then
        test_pass "Package is registered in RPM database"
    else
        test_fail "Package not found in RPM database"
        return 1
    fi
    
    # Check package information
    if exec_in_container "$container" "rpm -qi giv"; then
        test_pass "Package information available"
    else
        test_fail "Failed to get package information"
        return 1
    fi
    
    # List package files
    if exec_in_container "$container" "rpm -ql giv | head -10"; then
        test_pass "Package file list available"
    else
        test_fail "Failed to list package files"
        return 1
    fi
    
    # Verify package integrity
    if exec_in_container "$container" "rpm -V giv"; then
        test_pass "Package integrity verified"
    else
        test_fail "Package integrity check failed"
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
    
    # Test SELinux context (if available)
    if exec_in_container "$container" "command -v getenforce >/dev/null 2>&1"; then
        if exec_in_container "$container" "ls -Z /usr/bin/giv 2>/dev/null"; then
            test_pass "SELinux context available"
        else
            log_warning "SELinux context check skipped"
        fi
    fi
    
    return 0
}

# Run main function with provided arguments
main "$@"