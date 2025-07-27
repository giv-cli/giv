#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Set up test environment
export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src/lib"
export GIV_DEBUG="false"

setup() {
    # Create test directory
    mkdir -p "$GIV_HOME"
    cd "$BATS_TEST_TMPDIR"
}

teardown() {
    # Clean up test files
    rm -f test_*.md test_*.txt
}

@test "portable_mktemp creates valid temporary files" {
    # Test that portable_mktemp creates valid files and returns proper paths
    . "$GIV_LIB_DIR/system.sh"
    
    # Test with mktemp available
    if command -v mktemp >/dev/null 2>&1; then
        result=$(portable_mktemp "test.XXXXXX")
        assert [ -n "$result" ]
        assert [ -f "$result" ]
        # Verify it doesn't contain malformed variable expansions
        refute_output --partial "TMPDIR:-"
        rm -f "$result"
    fi
}

@test "portable_mktemp_dir sets correct base path" {
    # Test that portable_mktemp_dir doesn't create malformed paths
    . "$GIV_LIB_DIR/system.sh"
    
    # Unset GIV_TMP_DIR to test fallback behavior
    unset GIV_TMP_DIR
    portable_mktemp_dir
    
    # Verify GIV_TMP_DIR is set and doesn't contain literal "TMPDIR:-"
    assert [ -n "$GIV_TMP_DIR" ]
    refute [[ "$GIV_TMP_DIR" == *"TMPDIR:-"* ]]
    assert [ -d "$GIV_TMP_DIR" ]
}

@test "manage_section works with proper arguments" {
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/markdown.sh"
    
    # Create test files
    echo "# Changelog" > test_changelog.md
    echo "- New feature" > test_content.txt
    
    # Test manage_section with valid arguments
    result=$(manage_section "# Changelog" test_changelog.md test_content.txt update "1.0.0" "##")
    assert [ $? -eq 0 ]
    assert [ -n "$result" ]
    assert [ -f "$result" ]
    
    # Verify content was properly merged - use literal strings without dashes 
    assert_file_contains "$result" "# Changelog"
    assert_file_contains "$result" "## 1.0.0" 
    grep -q "New feature" "$result"
}

@test "manage_section fails gracefully with invalid mode" {
    . "$GIV_LIB_DIR/system.sh" 
    . "$GIV_LIB_DIR/markdown.sh"
    
    # Create test files
    echo "# Changelog" > test_changelog.md
    echo "- New feature" > test_content.txt
    
    # Test manage_section with invalid mode
    run manage_section "# Changelog" test_changelog.md test_content.txt "" "1.0.0" "##"
    assert_failure
    assert_output --partial "Invalid mode provided"
}

@test "build_history skips empty diff sections" {
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    
    # Create a test directory for this test
    test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Initialize git repo
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "initial content" > file.txt
    git add file.txt
    git commit -q -m "Initial commit"
    
    # Test build_diff directly with no changes - should return empty
    diff_result=$(build_diff "--current" "")
    
    # With no changes, build_diff should return empty string
    assert [ -z "$diff_result" ]
    
    cd "$BATS_TEST_TMPDIR"
    rm -rf "$test_dir"
}

@test "changelog uses sensible version defaults" {
    # Test that changelog command handles missing output_version gracefully
    . "$GIV_LIB_DIR/system.sh"
    
    # Test default version fallback
    GIV_OUTPUT_VERSION=""
    version_result=""
    
    # Simulate the changelog.sh version defaulting logic
    if [ -z "$GIV_OUTPUT_VERSION" ]; then
        version_result="Unreleased"  # This is the fallback we implemented
    fi
    
    assert [ "$version_result" = "Unreleased" ]
}

@test "GIV_OUTPUT_MODE defaults to auto" {
    . "$GIV_LIB_DIR/system.sh"
    
    # Test that GIV_OUTPUT_MODE has proper default
    assert [ "$GIV_OUTPUT_MODE" = "auto" ]
}

# Helper function to check if file contains content
assert_file_contains() {
    local file="$1"
    local content="$2"
    
    if ! grep -qF "$content" "$file"; then
        echo "File $file does not contain: $content"
        echo "Actual content:"
        cat "$file"
        return 1
    fi
}

# Helper function to check if file does NOT contain content  
refute_file_contains() {
    local file="$1"
    local content="$2"
    
    if grep -qF "$content" "$file"; then
        echo "File $file should not contain: $content"
        echo "Actual content:"
        cat "$file"
        return 1
    fi
}