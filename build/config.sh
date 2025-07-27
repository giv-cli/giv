#!/bin/bash
# Central configuration for build system

# Package metadata
export GIV_PACKAGE_NAME="giv"
export GIV_DESCRIPTION="Git history AI assistant CLI tool"
export GIV_MAINTAINER="itlackey <noreply@github.com>"
export GIV_LICENSE="CC-BY"
export GIV_REPOSITORY="https://github.com/giv-cli/giv"

# Docker configuration
export GIV_DOCKER_IMAGE="itlackey/giv"

# Build directories
export GIV_BUILD_ROOT="./build"
export GIV_DIST_ROOT="./dist"
export GIV_TEMP_ROOT="./.tmp"

# File paths
export GIV_VERSION_FILE="src/lib/system.sh"
export GIV_MAIN_SCRIPT="src/giv.sh"

# Validation
validate_config() {
    local required_vars=(
        GIV_PACKAGE_NAME GIV_DESCRIPTION GIV_MAINTAINER 
        GIV_LICENSE GIV_REPOSITORY GIV_DOCKER_IMAGE
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "ERROR: Required configuration variable $var is not set" >&2
            exit 1
        fi
    done
}

# Extract version from source file
get_version() {
    if [[ ! -f "$GIV_VERSION_FILE" ]]; then
        echo "ERROR: Version file not found: $GIV_VERSION_FILE" >&2
        exit 1
    fi
    
    local version
    version=$(sed -n 's/^export __VERSION="\([^"]*\)"/\1/p' "$GIV_VERSION_FILE")
    
    if [[ -z "$version" ]]; then
        echo "ERROR: Could not extract version from $GIV_VERSION_FILE" >&2
        exit 1
    fi
    
    echo "$version"
}

# Get project root directory
get_project_root() {
    # Try to find project root by looking for key files
    local current_dir="$PWD"
    
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/src/giv.sh" && -d "$current_dir/build" ]]; then
            echo "$current_dir"
            return
        fi
        current_dir=$(dirname "$current_dir")
    done
    
    echo "ERROR: Could not find project root directory" >&2
    exit 1
}

# Ensure build directories exist
ensure_build_dirs() {
    local dirs=(
        "$GIV_TEMP_ROOT"
        "$GIV_DIST_ROOT"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if ! mkdir -p "$dir"; then
                echo "ERROR: Failed to create directory: $dir" >&2
                exit 1
            fi
        fi
    done
}

# Common error handling function
error_exit() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# Dependency checking
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error_exit "Missing required dependencies: ${missing[*]}"
    fi
}

# Initialize configuration when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    echo "Build system configuration:"
    echo "=========================="
    echo "Package: $GIV_PACKAGE_NAME"
    echo "Description: $GIV_DESCRIPTION"
    echo "Maintainer: $GIV_MAINTAINER"
    echo "License: $GIV_LICENSE"
    echo "Repository: $GIV_REPOSITORY"
    echo "Docker Image: $GIV_DOCKER_IMAGE"
    echo "Version File: $GIV_VERSION_FILE"
    
    if version=$(get_version); then
        echo "Current Version: $version"
    fi
    
    validate_config
    echo "Configuration is valid."
else
    # Script is being sourced
    validate_config
    ensure_build_dirs
fi