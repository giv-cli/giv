#!/bin/bash
# Main package validation orchestrator

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
BUILD_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PROJECT_DIR="$(dirname "$BUILD_DIR")"

# Source common functions
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

# Configuration
SUPPORTED_PLATFORMS=(ubuntu debian fedora alpine)
SUPPORTED_PACKAGES=(npm pypi deb rpm docker)
DEFAULT_PLATFORMS=(ubuntu fedora)
DEFAULT_PACKAGES=(npm pypi deb rpm)

# Parse command line arguments
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate GIV CLI packages across multiple platforms using Docker containers.

Options:
    -p, --platforms PLATFORMS    Comma-separated list of platforms to test
                                 Available: ${SUPPORTED_PLATFORMS[*]}
                                 Default: ${DEFAULT_PLATFORMS[*]}
    
    -k, --packages PACKAGES      Comma-separated list of packages to test
                                 Available: ${SUPPORTED_PACKAGES[*]}
                                 Default: ${DEFAULT_PACKAGES[*]}
    
    -v, --version VERSION        Version to test (default: auto-detect)
    -r, --report FILE           Generate JSON report to file
    -c, --clean                 Clean up containers after testing
    -b, --build                 Build packages before testing
    -h, --help                  Show this help message

Examples:
    $0                          # Test default packages on default platforms
    $0 -p ubuntu,fedora -k npm,deb  # Test specific packages on specific platforms
    $0 -b -c                    # Build packages, test, and clean up
    $0 -r validation-report.json     # Generate JSON report

EOF
}

# Default values
PLATFORMS_TO_TEST=(${DEFAULT_PLATFORMS[@]})
PACKAGES_TO_TEST=(${DEFAULT_PACKAGES[@]})
VERSION=""
REPORT_FILE=""
CLEAN_UP=false
BUILD_PACKAGES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platforms)
            IFS=',' read -ra PLATFORMS_TO_TEST <<< "$2"
            shift 2
            ;;
        -k|--packages)
            IFS=',' read -ra PACKAGES_TO_TEST <<< "$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -r|--report)
            REPORT_FILE="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_UP=true
            shift
            ;;
        -b|--build)
            BUILD_PACKAGES=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Auto-detect version if not provided
if [[ -z "$VERSION" ]]; then
    if [[ -f "$PROJECT_DIR/build/config.sh" ]]; then
        # shellcheck source=../../config.sh
        . "$PROJECT_DIR/build/config.sh"
        VERSION=$(get_version)
    else
        log_error "Could not auto-detect version. Please specify with -v"
        exit 1
    fi
fi

log_info "Starting package validation for version $VERSION"
log_info "Platforms: ${PLATFORMS_TO_TEST[*]}"
log_info "Packages: ${PACKAGES_TO_TEST[*]}"

# Change to project directory
cd "$PROJECT_DIR"

# Build packages if requested
if [[ "$BUILD_PACKAGES" == true ]]; then
    log_info "Building packages..."
    if ! ./build/build-packages.sh; then
        log_error "Package build failed"
        exit 1
    fi
fi

# Initialize report
if [[ -n "$REPORT_FILE" ]]; then
    echo "[]" > "$REPORT_FILE"
    log_info "Will generate report to: $REPORT_FILE"
fi

# Track overall results
TOTAL_TESTS=0
TOTAL_FAILURES=0

# Test each package on each platform
for platform in "${PLATFORMS_TO_TEST[@]}"; do
    for package in "${PACKAGES_TO_TEST[@]}"; do
        log_info "Testing $package on $platform"
        
        # Validate platform is supported
        if [[ ! " ${SUPPORTED_PLATFORMS[*]} " =~ " $platform " ]]; then
            log_warning "Unsupported platform: $platform, skipping"
            continue
        fi
        
        # Validate package is supported
        if [[ ! " ${SUPPORTED_PACKAGES[*]} " =~ " $package " ]]; then
            log_warning "Unsupported package: $package, skipping"
            continue
        fi
        
        # Check if validator exists
        validator_script="$SCRIPT_DIR/${package}-validator.sh"
        if [[ ! -f "$validator_script" ]]; then
            log_warning "Validator not found: $validator_script, skipping"
            continue
        fi
        
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        
        # Run the validator
        if bash "$validator_script" "$platform" "$VERSION"; then
            log_success "$package validation passed on $platform"
            status="passed"
        else
            log_error "$package validation failed on $platform"
            TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
            status="failed"
        fi
        
        # Add to report if requested
        if [[ -n "$REPORT_FILE" ]]; then
            # Read existing report
            temp_report=$(mktemp)
            jq --arg pkg "$package" --arg plat "$platform" --arg stat "$status" --arg ver "$VERSION" \
                '. += [{
                    "package": $pkg,
                    "platform": $plat,
                    "version": $ver,
                    "status": $stat,
                    "timestamp": now | strftime("%Y-%m-%dT%H:%M:%SZ")
                }]' "$REPORT_FILE" > "$temp_report"
            mv "$temp_report" "$REPORT_FILE"
        fi
        
        echo "" # Add spacing between tests
    done
done

# Clean up containers if requested
if [[ "$CLEAN_UP" == true ]]; then
    log_info "Cleaning up containers..."
    for platform in "${PLATFORMS_TO_TEST[@]}"; do
        stop_container "giv-test-$platform" || true
    done
fi

# Final summary
echo ""
echo "========================================="
echo "VALIDATION SUMMARY"
echo "========================================="
echo "Total tests: $TOTAL_TESTS"
echo "Failures: $TOTAL_FAILURES"
echo "Success rate: $(( (TOTAL_TESTS - TOTAL_FAILURES) * 100 / TOTAL_TESTS ))%" 

if [[ -n "$REPORT_FILE" ]]; then
    echo "Report saved to: $REPORT_FILE"
fi

if [[ $TOTAL_FAILURES -eq 0 ]]; then
    log_success "All validations passed!"
    exit 0
else
    log_error "$TOTAL_FAILURES validation(s) failed!"
    exit 1
fi