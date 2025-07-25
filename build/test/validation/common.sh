#!/bin/bash
# Common validation functions for package testing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_step() {
    echo -e "${BLUE}>>> $*${NC}"
}

# Test result tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

test_start() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_step "Test $TESTS_TOTAL: $*"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_success "$*"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "$*"
}

test_summary() {
    echo ""
    echo "==============================================="
    echo "Test Summary:"
    echo "  Total:  $TESTS_TOTAL"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo "==============================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "$TESTS_FAILED test(s) failed!"
        return 1
    fi
}

# Docker container management
start_container() {
    local image="$1"
    local name="$2"
    local workspace="${3:-/workspace}"
    
    log_info "Starting container $name from image $image"
    
    # Remove existing container if it exists
    docker rm -f "$name" 2>/dev/null || true
    
    # Start new container
    docker run -d \
        --name "$name" \
        --volume "$PWD:$workspace" \
        --workdir "$workspace" \
        "$image" \
        sleep infinity
    
    # Wait for container to be ready
    sleep 2
    
    if docker ps | grep -q "$name"; then
        log_success "Container $name started successfully"
        return 0
    else
        log_error "Failed to start container $name"
        return 1
    fi
}

stop_container() {
    local name="$1"
    
    log_info "Stopping container $name"
    docker rm -f "$name" 2>/dev/null || true
}

exec_in_container() {
    local container="$1"
    local cmd="$2"
    
    docker exec "$container" bash -c "$cmd"
}

exec_in_container_as_user() {
    local container="$1"
    local user="$2"
    local cmd="$3"
    
    docker exec --user "$user" "$container" bash -c "$cmd"
}

# File and command validation
check_file_exists() {
    local container="$1"
    local file="$2"
    
    if exec_in_container "$container" "test -f '$file'"; then
        test_pass "File exists: $file"
        return 0
    else
        test_fail "File missing: $file"
        return 1
    fi
}

check_command_exists() {
    local container="$1"
    local command="$2"
    
    if exec_in_container "$container" "command -v '$command' >/dev/null 2>&1"; then
        test_pass "Command available: $command"
        return 0
    else
        test_fail "Command not found: $command"
        return 1
    fi
}

check_command_output() {
    local container="$1"
    local command="$2"
    local expected="$3"
    
    local output
    if output=$(exec_in_container "$container" "$command" 2>&1); then
        if echo "$output" | grep -q "$expected"; then
            test_pass "Command output contains '$expected'"
            return 0
        else
            test_fail "Command output missing '$expected'. Got: $output"
            return 1
        fi
    else
        test_fail "Command failed: $command"
        return 1
    fi
}

# Package validation helpers
validate_giv_installation() {
    local container="$1"
    local package_manager="$2"
    
    test_start "Validating giv installation via $package_manager"
    
    # Check if giv command is available
    check_command_exists "$container" "giv"
    
    # Test basic functionality
    check_command_output "$container" "giv --version" "giv"
    check_command_output "$container" "giv --help" "Usage:"
    
    # Test that it can access templates and docs
    if exec_in_container "$container" "giv --help" | grep -q "available commands"; then
        test_pass "Help command shows available commands"
    else
        test_fail "Help command doesn't show expected content"
    fi
}

# Build environment validation
validate_build_environment() {
    local container="$1"
    
    test_start "Validating build environment"
    
    # Check essential tools
    check_command_exists "$container" "git"
    check_command_exists "$container" "curl"
    
    # Check that we can access the workspace
    check_file_exists "$container" "/workspace/src/giv.sh"
}

# Package cleanup
cleanup_package() {
    local container="$1"
    local package_manager="$2"
    local package_name="${3:-giv}"
    
    test_start "Cleaning up $package_name via $package_manager"
    
    case "$package_manager" in
        apt|dpkg)
            exec_in_container "$container" "sudo apt-get remove -y $package_name || true"
            exec_in_container "$container" "sudo apt-get purge -y $package_name || true"
            ;;
        yum|dnf|rpm)
            exec_in_container "$container" "sudo dnf remove -y $package_name || sudo yum remove -y $package_name || sudo rpm -e $package_name || true"
            ;;
        npm)
            exec_in_container "$container" "npm uninstall -g $package_name || true"
            ;;
        pip|pip3)
            exec_in_container "$container" "pip3 uninstall -y $package_name || pip uninstall -y $package_name || true"
            ;;
        snap)
            exec_in_container "$container" "sudo snap remove $package_name || true"
            ;;
        flatpak)
            exec_in_container "$container" "flatpak uninstall --user -y $package_name || true"
            ;;
    esac
    
    # Verify cleanup
    if ! exec_in_container "$container" "command -v giv >/dev/null 2>&1"; then
        test_pass "Package cleanup successful"
    else
        test_warning "Package may not have been completely removed"
    fi
}

# Report generation
generate_report() {
    local report_file="$1"
    local package_type="$2"
    local platform="$3"
    local status="$4"
    
    cat >> "$report_file" << EOF
{
  "package_type": "$package_type",
  "platform": "$platform", 
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "$status",
  "tests_total": $TESTS_TOTAL,
  "tests_passed": $TESTS_PASSED,
  "tests_failed": $TESTS_FAILED
}
EOF
}

# Utility functions
build_docker_image() {
    local dockerfile_dir="$1"
    local image_name="$2"
    
    log_info "Building Docker image $image_name from $dockerfile_dir"
    
    if docker build -t "$image_name" "$dockerfile_dir"; then
        log_success "Docker image $image_name built successfully"
        return 0
    else
        log_error "Failed to build Docker image $image_name"
        return 1
    fi
}

ensure_package_built() {
    local package_type="$1"
    local version="$2"
    local dist_dir="./dist/$version"
    
    case "$package_type" in
        npm)
            if [[ ! -d "$dist_dir/npm" ]]; then
                log_error "npm package not found at $dist_dir/npm"
                return 1
            fi
            ;;
        pypi)  
            if [[ ! -d "$dist_dir/pypi" ]]; then
                log_error "PyPI package not found at $dist_dir/pypi"
                return 1
            fi
            ;;
        deb)
            if ! find "$dist_dir" -name "*.deb" | head -1 | grep -q deb; then
                log_error "Debian package not found in $dist_dir"
                return 1
            fi
            ;;
        rpm)
            if ! find "$dist_dir" -name "*.rpm" | head -1 | grep -q rpm; then
                log_error "RPM package not found in $dist_dir"
                return 1
            fi
            ;;
    esac
    
    log_success "Package $package_type is available for testing"
    return 0
}