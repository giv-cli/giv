#!/bin/bash
# Docker image validator
# Tests Docker image build and functionality

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

# Configuration
BUILD_DIR="$SCRIPT_DIR/../../.."
WORKSPACE="/workspace"

main() {
    local platform="${1:-docker}"  # Platform doesn't matter for Docker images
    local version="${2:-}"
    
    if [[ -z "$version" ]]; then
        log_error "Version parameter is required"
        exit 1
    fi
    
    log_info "Starting Docker image validation (version: $version)"
    
    # Docker image name
    local image_name="giv:$version"
    local test_container_name="giv-docker-test"
    
    # Run validation tests
    local exit_code=0
    
    # Test 1: Build Docker image
    test_docker_build "$image_name" "$version" || exit_code=1
    
    # Test 2: Test basic container functionality
    test_docker_run "$image_name" "$test_container_name" || exit_code=1
    
    # Test 3: Test giv functionality in container
    test_giv_in_container "$test_container_name" || exit_code=1
    
    # Test 4: Test container cleanup
    test_docker_cleanup "$test_container_name" || exit_code=1
    
    # Print test summary and exit
    if test_summary; then
        log_success "Docker image validation completed successfully"
        exit 0
    else
        log_error "Docker image validation failed"
        exit 1
    fi
}

test_docker_build() {
    local image_name="$1"
    local version="$2"
    
    test_start "Building Docker image $image_name"
    
    # Change to build directory
    cd "$BUILD_DIR"
    
    # Check if Dockerfile exists
    if [[ ! -f "build/docker/Dockerfile" ]]; then
        test_fail "Dockerfile not found at build/docker/Dockerfile"
        return 1
    fi
    
    # Build the Docker image
    if docker build -t "$image_name" -f build/docker/Dockerfile .; then
        test_pass "Docker image built successfully"
        
        # Verify image exists
        if docker images | grep -q "$image_name"; then
            test_pass "Docker image appears in image list"
            return 0
        else
            test_fail "Docker image not found in image list"
            return 1
        fi
    else
        test_fail "Failed to build Docker image"
        return 1
    fi
}

test_docker_run() {
    local image_name="$1"
    local container_name="$2"
    
    test_start "Testing Docker container execution"
    
    # Remove any existing container with the same name
    docker rm -f "$container_name" 2>/dev/null || true
    
    # Run container in detached mode
    if docker run -d --name "$container_name" "$image_name" sleep 300; then
        test_pass "Docker container started successfully"
        
        # Wait for container to be ready
        sleep 2
        
        # Verify container is running
        if docker ps | grep -q "$container_name"; then
            test_pass "Docker container is running"
            return 0
        else
            test_fail "Docker container is not running"
            return 1
        fi
    else
        test_fail "Failed to start Docker container"
        return 1
    fi
}

test_giv_in_container() {
    local container_name="$1"
    
    test_start "Testing giv functionality in Docker container"
    
    # Test that giv command is available
    if docker exec "$container_name" giv --version; then
        test_pass "giv --version works in container"
    else
        test_fail "giv --version failed in container"
        return 1
    fi
    
    # Test help command
    if docker exec "$container_name" giv --help; then
        test_pass "giv --help works in container"
    else
        test_fail "giv --help failed in container"
        return 1
    fi
    
    # Create a test git repository in the container
    docker exec "$container_name" bash -c "
        cd /tmp &&
        mkdir test-repo && cd test-repo &&
        git init -q &&
        git config user.name 'Test User' &&
        git config user.email 'test@example.com' &&
        echo 'Hello World' > README.md &&
        git add README.md &&
        git commit -q -m 'Initial commit'
    "
    
    # Test giv message command (dry run)
    if docker exec "$container_name" bash -c "cd /tmp/test-repo && giv message --dry-run"; then
        test_pass "giv message --dry-run works in container"
    else
        test_fail "giv message --dry-run failed in container"
        return 1
    fi
    
    # Test giv config command
    if docker exec "$container_name" bash -c "cd /tmp/test-repo && giv config --help"; then
        test_pass "giv config --help works in container"
    else
        test_fail "giv config --help failed in container"
        return 1
    fi
    
    # Test that templates and other resources are available
    if docker exec "$container_name" test -d /usr/share/giv/templates || docker exec "$container_name" test -d /opt/giv/templates; then
        test_pass "giv templates directory found in container"
    else
        test_fail "giv templates directory not found in container"
        return 1
    fi
    
    return 0
}

test_docker_cleanup() {
    local container_name="$1"
    
    test_start "Testing Docker container cleanup"
    
    # Stop and remove the container
    if docker rm -f "$container_name" 2>/dev/null; then
        test_pass "Docker container removed successfully"
        
        # Verify container is gone
        if ! docker ps -a | grep -q "$container_name"; then
            test_pass "Docker container cleanup verified"
            return 0
        else
            test_fail "Docker container still exists after cleanup"
            return 1
        fi
    else
        test_fail "Failed to remove Docker container"
        return 1
    fi
}

# Test Docker image security and best practices
test_docker_security() {
    local image_name="$1"
    
    test_start "Testing Docker image security"
    
    # Check if image runs as non-root user
    local user_id
    if user_id=$(docker run --rm "$image_name" id -u); then
        if [[ "$user_id" != "0" ]]; then
            test_pass "Docker image runs as non-root user (UID: $user_id)"
        else
            test_fail "Docker image runs as root user"
            return 1
        fi
    else
        test_fail "Failed to check user ID in Docker image"
        return 1
    fi
    
    # Check image size (should be reasonable)
    local image_size
    if image_size=$(docker images --format "table {{.Size}}" "$image_name" | tail -n 1); then
        log_info "Docker image size: $image_size"
        test_pass "Docker image size reported"
    else
        test_fail "Failed to get Docker image size"
        return 1
    fi
    
    return 0
}

# Run main function with provided arguments
main "$@"