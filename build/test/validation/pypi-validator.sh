#!/bin/bash
# PyPI package validator
# Tests PyPI package installation and functionality across different platforms

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
    
    log_info "Starting PyPI validation on $platform (version: $version)"
    
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
    
    # Ensure PyPI package is built
    if ! ensure_package_built "pypi" "$version"; then
        log_error "PyPI package not available for testing"
        stop_container "$container_name"
        exit 1
    fi
    
    # Run validation tests
    local exit_code=0
    
    # Test 1: Validate build environment
    validate_build_environment "$container_name" || exit_code=1
    
    # Test 2: Setup Python environment
    setup_python_environment "$container_name" "$platform" || exit_code=1
    
    # Test 3: Install PyPI package from local wheel
    test_pypi_install "$container_name" "$version" || exit_code=1
    
    # Test 4: Validate installation 
    validate_giv_installation "$container_name" "pip" || exit_code=1
    
    # Test 5: Test core functionality
    test_giv_functionality "$container_name" || exit_code=1
    
    # Test 6: Cleanup and verify removal
    cleanup_package "$container_name" "pip" "giv" || exit_code=1
    
    # Stop container
    stop_container "$container_name"
    
    # Print test summary and exit
    if test_summary; then
        log_success "PyPI validation completed successfully on $platform"
        exit 0
    else
        log_error "PyPI validation failed on $platform"
        exit 1
    fi
}

setup_python_environment() {
    local container="$1"
    local platform="$2"
    
    test_start "Setting up Python environment"
    
    # Ensure pip is available and up to date
    case "$platform" in
        ubuntu|debian)
            exec_in_container "$container" "python3 -m pip --version" || {
                test_fail "pip not available"
                return 1
            }
            ;;
        fedora)
            exec_in_container "$container" "python3 -m pip --version" || {
                test_fail "pip not available"
                return 1
            }
            ;;
        alpine)
            exec_in_container "$container" "python3 -m pip --version" || {
                test_fail "pip not available"
                return 1
            }
            ;;
        arch)
            exec_in_container "$container" "python -m pip --version" || {
                test_fail "pip not available"
                return 1
            }
            ;;
    esac
    
    # Upgrade pip to latest version
    if exec_in_container "$container" "python3 -m pip install --upgrade pip || python -m pip install --upgrade pip"; then
        test_pass "Python environment ready"
        return 0
    else
        test_fail "Failed to setup Python environment"
        return 1
    fi
}

test_pypi_install() {
    local container="$1"
    local version="$2"
    
    test_start "Installing PyPI package (version $version)"
    
    # Find the wheel file
    local wheel_file
    if ! wheel_file=$(find "./dist/$version" -name "giv-*.whl" | head -1); then
        test_fail "No wheel file found in ./dist/$version"
        return 1
    fi
    
    if [[ ! -f "$wheel_file" ]]; then
        test_fail "Wheel file not found: $wheel_file"
        return 1
    fi
    
    log_info "Found PyPI package: $wheel_file"
    
    # Install from local wheel file
    local wheel_name
    wheel_name=$(basename "$wheel_file")
    
    # Try both python3 and python commands depending on platform
    if exec_in_container "$container" "python3 -m pip install '$WORKSPACE/$wheel_file' || python -m pip install '$WORKSPACE/$wheel_file'"; then
        test_pass "PyPI package installed successfully"
        
        # Verify the installation created the expected files
        check_command_exists "$container" "giv"
        return $?
    else
        test_fail "Failed to install PyPI package"
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
    
    # Test that Python entry point is working
    if exec_in_container "$container" "cd '$test_repo' && python3 -c 'import giv; print(\"Import successful\")' || python -c 'import giv; print(\"Import successful\")'"; then
        test_pass "Python module import works"
    else
        test_fail "Python module import failed"
        return 1
    fi
    
    return 0
}

# Run main function with provided arguments
main "$@"