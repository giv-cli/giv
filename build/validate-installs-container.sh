#!/usr/bin/env bash
set -euo pipefail

# Container-internal validation script
# This script runs inside the giv-packages container and performs actual validation

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "ERROR: Version not provided" >&2
    exit 1
fi

# Parse environment variables
TEST_PACKAGES="${TEST_PACKAGES:-deb,pypi,npm,homebrew}"
REPORT_FILE="${REPORT_FILE:-}"

echo "Validating GIV CLI version $VERSION inside container..."
echo "Testing packages: $TEST_PACKAGES"

report() { printf "\n== %s ==\n" "$*"; }

# Helper: check PATH for giv
expect_giv_in_path() {
    if ! command -v giv >/dev/null 2>&1; then
        echo "FAIL: giv not found in PATH after install."
        exit 1
    fi
    echo "PASS: giv found in PATH."
}

expect_giv_not_in_path() {
    if command -v giv >/dev/null 2>&1; then
        echo "FAIL: giv still found in PATH after uninstall."
        exit 1
    fi
    echo "PASS: giv not in PATH after uninstall."
}

# File checkers for each package manager
deb_rpm_check() {
    expect_file_exists /usr/local/bin/giv
    expect_file_exists /usr/local/lib/giv/helpers.sh
    expect_file_exists /usr/local/share/giv/templates/summary_prompt.md
}

pip_check() {
    # 1) Find venv base
    VENV_BIN="$(dirname "$(command -v giv)")"
    VENV_BASE="$(dirname "$VENV_BIN")"

    # 2) The CLI entrypoint
    expect_file_exists "$VENV_BIN/giv"

    # 3) Our two .sh helpers
    expect_file_exists "$VENV_BASE/src/markdown.sh"
    expect_file_exists "$VENV_BASE/src/helpers.sh"

    # 4) At least one template under <venv>/templates
    if [ ! -d "$VENV_BASE/templates" ]; then
        echo "FAIL: template directory not found: $VENV_BASE/templates"
        exit 1
    fi
    found=0
    for f in "$VENV_BASE/templates"/*.md; do
        [ -e "$f" ] && {
            found=1
            break
        }
    done
    if [ "$found" -ne 1 ]; then
        echo "FAIL: no .md files in $VENV_BASE/templates"
        exit 1
    fi

    # 5) At least one doc under <venv>/docs (allow nested)
    if [ ! -d "$VENV_BASE/docs" ]; then
        echo "FAIL: docs directory not found: $VENV_BASE/docs"
        exit 1
    fi
    found=0
    # top-level and one level deep
    for f in "$VENV_BASE/docs"/*.md "$VENV_BASE/docs"/*/*.md; do
        [ -e "$f" ] && {
            found=1
            break
        }
    done
    if [ "$found" -ne 1 ]; then
        echo "FAIL: no .md files in $VENV_BASE/docs or its subdirectories"
        exit 1
    fi

    echo "PASS: PyPI files found."
}

npm_check() {
    # ─── detect package manager and derive paths ─────────────────────────────────
    if command -v npm >/dev/null 2>&1; then
        # npm exists: use its config
        NPM_PREFIX=$(npm config get prefix)
        NPM_BIN="$NPM_PREFIX/bin"
        NPM_ROOT="$NPM_PREFIX/lib/node_modules"
    elif command -v yarn >/dev/null 2>&1; then
        # Yarn (classic) has its own globals
        NPM_BIN=$(yarn global bin)
        # `yarn global dir` gives the root of the yarn global installation
        NPM_ROOT="$(yarn global dir)/node_modules"
    else
        echo "ERROR: neither npm nor yarn found on PATH" >&2
        exit 1
    fi

    # ─── sanity-check that the dirs actually exist ─────────────────────────────────
    if [ ! -d "$NPM_BIN" ]; then
        echo "WARN: expected bin dir not found: $NPM_BIN" >&2
    fi
    if [ ! -d "$NPM_ROOT" ]; then
        echo "WARN: expected root dir not found: $NPM_ROOT" >&2
    fi
    expect_file_exists "$NPM_BIN/giv"
    expect_file_exists "$NPM_ROOT/giv/src/helpers.sh"
    expect_file_exists "$NPM_ROOT/giv/templates/summary_prompt.md"
}

snap_check() {
    expect_file_exists /snap/bin/giv
    # Try to resolve $SNAP for the test context
    SNAPDIR="$(readlink -f /snap/giv/current)"
    expect_file_exists "$SNAPDIR/lib/giv/helpers.sh"
    expect_file_exists "$SNAPDIR/share/giv/templates/summary_prompt.md"
}

expect_file_exists() {
    for file in "$@"; do
        if [ ! -e "$file" ]; then
            echo "FAIL: Expected file $file not found after install."
            exit 1
        fi
    done
    echo "PASS: All expected files found."
}

# Initialize validation report
VALIDATION_RESULTS=()
TOTAL_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo "Running test: $test_name"
    if $test_function; then
        echo "✓ $test_name PASSED"
        VALIDATION_RESULTS+=("$test_name:PASS")
    else
        echo "✗ $test_name FAILED"
        VALIDATION_RESULTS+=("$test_name:FAIL")
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Convert TEST_PACKAGES to array
IFS=',' read -ra PACKAGES_ARRAY <<< "$TEST_PACKAGES"

# Set up test workspace
mkdir -p .tmp/validate-installs
cd .tmp/validate-installs

# Run tests for each requested package type
for package_type in "${PACKAGES_ARRAY[@]}"; do
    case "$package_type" in
        deb)
            if [[ " ${PACKAGES_ARRAY[*]} " =~ " deb " ]]; then
                report "Testing deb install (APT)"
                run_test "DEB_INSTALL" "
                    sudo apt-get update && 
                    sudo apt-get install -y ../../dist/*/deb/*.deb &&
                    expect_giv_in_path &&
                    deb_rpm_check &&
                    sudo apt-get remove -y giv &&
                    expect_giv_not_in_path
                "
            fi
            ;;
            
        rpm)
            # Note: RPM testing would need a different container base (Fedora/CentOS)
            # For now, skip RPM testing in Ubuntu container
            echo "SKIP: RPM testing requires Fedora/CentOS container"
            ;;
            
        pypi)
            if [[ " ${PACKAGES_ARRAY[*]} " =~ " pypi " ]]; then
                report "Testing PyPI install (pip)"
                run_test "PYPI_INSTALL" "
                    python3 -m venv pipenv &&
                    . pipenv/bin/activate &&
                    pip install ../../dist/*/pypi/ &&
                    expect_giv_in_path &&
                    pip_check &&
                    pip uninstall -y giv &&
                    expect_giv_not_in_path &&
                    deactivate &&
                    rm -rf ../../dist/*/pypi/build &&
                    rm -rf ../../dist/*/pypi/src/giv.*
                "
            fi
            ;;
            
        npm)
            if [[ " ${PACKAGES_ARRAY[*]} " =~ " npm " ]]; then
                report "Testing npm install (npm)"
                run_test "NPM_INSTALL" "
                    npm install -g ../../dist/*/npm/ &&
                    expect_giv_in_path &&
                    npm_check &&
                    npm uninstall -g giv &&
                    expect_giv_not_in_path
                "
            fi
            ;;
            
        homebrew)
            if [[ " ${PACKAGES_ARRAY[*]} " =~ " homebrew " ]]; then
                report "Testing brew install (Homebrew)"
                run_test "HOMEBREW_INSTALL" "
                    # Locate the local formula
                    mv \"../../dist/${VERSION}/homebrew/giv.rb\" \"../../dist/${VERSION}/homebrew/giv.rb.bak\" &&
                    mv \"../../dist/${VERSION}/homebrew/giv.local.rb\" \"../../dist/${VERSION}/homebrew/giv.rb\" &&
                    FORMULA=\"../../dist/${VERSION}/homebrew/giv.rb\" &&
                    [ -f \"\$FORMULA\" ] &&
                    
                    # Install as linuxbrew user
                    su - linuxbrew -c \"
                        export HOMEBREW_NO_INSTALL_CLEANUP=1
                        export HOMEBREW_NO_ENV_HINTS=1
                        export HOMEBREW_NO_AUTO_UPDATE=1
                        /home/linuxbrew/.linuxbrew/bin/brew install --build-from-source '\$FORMULA'
                    \" &&
                    expect_giv_in_path &&
                    
                    # Uninstall and confirm removal
                    su - linuxbrew -c '/home/linuxbrew/.linuxbrew/bin/brew uninstall --force giv' &&
                    expect_giv_not_in_path &&
                    mv \"../../dist/${VERSION}/homebrew/giv.rb\" \"../../dist/${VERSION}/homebrew/giv.local.rb\" &&
                    mv \"../../dist/${VERSION}/homebrew/giv.rb.bak\" \"../../dist/${VERSION}/homebrew/giv.rb\"
                "
            fi
            ;;
            
        snap)
            # Note: Snap testing in containers is complex due to systemd/snapd requirements
            echo "SKIP: Snap testing requires systemd/snapd support"
            ;;
            
        *)
            echo "WARN: Unknown package type: $package_type"
            ;;
    esac
done

cd ../../
rm -rf .tmp/validate-installs

# Generate report
echo
echo "========================================"
echo "VALIDATION SUMMARY"
echo "========================================"
echo "Total tests: $TOTAL_TESTS"
echo "Failures: $FAILED_TESTS"
echo "Success rate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%"

if [[ -n "$REPORT_FILE" ]]; then
    # Generate JSON report
    cat > "$REPORT_FILE" << EOF
{
  "version": "$VERSION",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_tests": $TOTAL_TESTS,
  "failed_tests": $FAILED_TESTS,
  "success_rate": $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS )),
  "results": [
EOF

    for i in "${!VALIDATION_RESULTS[@]}"; do
        result="${VALIDATION_RESULTS[$i]}"
        test_name="${result%:*}"
        test_status="${result#*:}"
        
        if [[ $i -gt 0 ]]; then
            echo "    ," >> "$REPORT_FILE"
        fi
        
        echo "    {\"test\": \"$test_name\", \"status\": \"$test_status\"}" >> "$REPORT_FILE"
    done
    
    echo "  ]" >> "$REPORT_FILE"
    echo "}" >> "$REPORT_FILE"
    
    echo "Report saved to: $REPORT_FILE"
fi

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo
    echo "All validations passed!"
    exit 0
else
    echo
    echo "Some validations failed!"
    exit 1
fi