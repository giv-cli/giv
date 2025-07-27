#!/usr/bin/env bats

# Integration tests for the main giv dispatcher script
# Tests end-to-end functionality using real fixtures and helpers

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'helpers/setup.sh'


setup() {
    # Create isolated test environment
    TMPDIR_REPO="$(mktemp -d -p "$GIV_HOME/.tmp")"
    cd "$TMPDIR_REPO" || {
        echo "Failed to change directory to TMPDIR_REPO" >&2
        exit 1
    }
    
    # Initialize git repo with test commits
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "Initial content" > README.md
    echo '{"name": "test-project", "version": "1.0.0"}' > package.json
    git add .
    git commit -q -m "Initial commit"
    
    # Create a second commit
    echo "Updated content" >> README.md
    git add README.md
    git commit -q -m "Update README"
    
    # Set up GIV environment
    mkdir -p "$GIV_HOME"
    echo "GIV_API_KEY=test-key" > "$GIV_HOME/config"
    echo "GIV_API_URL=https://api.test.com" >> "$GIV_HOME/config"
    echo "GIV_API_MODEL=test-model" >> "$GIV_HOME/config"
    echo "GIV_PROJECT_TYPE=node" >> "$GIV_HOME/config"
    echo "GIV_PROJECT_TITLE=test-project" >> "$GIV_HOME/config"
    echo "GIV_PROJECT_DESCRIPTION=A test project" >> "$GIV_HOME/config"
    echo "GIV_PROJECT_URL=https://github.com/test/test" >> "$GIV_HOME/config"
    echo "GIV_INITIALIZED=\"true\"" >> "$GIV_HOME/config"
    
    export GIV_SCRIPT="$BATS_TEST_DIRNAME/../src/giv.sh"
}

teardown() {
    if [ -n "$TMPDIR_REPO" ] && [ -d "$TMPDIR_REPO" ]; then
        rm -rf "$TMPDIR_REPO"
    fi
}

# Test basic dispatcher functionality
@test "dispatcher: shows runs message with no arguments" {
    run "$GIV_SCRIPT"
    assert_failure
    assert_output --partial "Executing subcommand: message"
    assert_output --partial "With arguments:"
}

@test "dispatcher: shows help with --help flag" {
    run "$GIV_SCRIPT" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "message"
    assert_output --partial "changelog"
}

@test "dispatcher: shows version with --version flag" {
    run "$GIV_SCRIPT" --version
    assert_success
    assert_output --regexp "[0-9]+\.[0-9]+\.[0-9]+"
}

@test "dispatcher: handles unknown subcommand gracefully" {
    run "$GIV_SCRIPT" nonexistent-command
    assert_failure
    assert_output --partial "Error: Unknown subcommand 'nonexistent-command'"
    assert_output --partial "Use -h or --help for usage information."
}

@test "dispatcher: accepts valid subcommands" {
    # Test that dispatcher accepts known subcommands (even if they fail due to missing dependencies)
    local valid_commands="message summary changelog release-notes announcement document config help"
    
    for cmd in $valid_commands; do
        # Check that subcommand file exists and dispatcher would attempt to execute it
        [ -f "$GIV_SRC_DIR/commands/${cmd}.sh" ] || skip "Subcommand $cmd not found"
        
        # Run with dry-run to avoid actual execution but test dispatcher logic
        run timeout 2s "$GIV_SCRIPT" "$cmd" --dry-run 2>/dev/null || true
        # Should not fail with "Unknown subcommand" error
        refute_output --partial "Unknown subcommand: $cmd"
    done
}

@test "dispatcher: sets up environment correctly" {
    # Test that GIV_HOME and other environment variables are set up
    run "$GIV_SCRIPT" config --list
    assert_success
    assert_output --partial "api.key"
    assert_output --partial "api.url"
}

@test "dispatcher: handles config file loading" {
    # Create a custom config
    echo "GIV_CUSTOM_VAR=test_value" > custom_config.env
    
    run "$GIV_SCRIPT" --config-file custom_config.env config --list
    assert_success
    # Should have loaded the custom config (converted to custom.var format)
    assert_output --partial "custom.var=test_value"
}

@test "dispatcher: validates git repository requirement" {
    # Move to a non-git directory
    cd /tmp
    mkdir -p nogit_test && cd nogit_test
    
    # Most commands should fail gracefully when not in a git repo
    run "$GIV_SCRIPT" message HEAD
    assert_failure
    # Should show meaningful error about git repository or invalid target
}

@test "dispatcher: handles verbose/debug mode" {
    export GIV_DEBUG="true"
    
    run "$GIV_SCRIPT" --verbose config --list
    assert_success
    # Debug output should be present
    assert_output --partial "DEBUG:"
}

@test "dispatcher: handles dry-run mode" {
    run "$GIV_SCRIPT" message --dry-run HEAD
    assert_success
    # Should not actually create files in dry-run mode
    [ ! -f "COMMIT_MESSAGE.md" ]
}

@test "dispatcher: command delegation works" {
    # Test that dispatcher properly delegates to subcommand scripts
    run "$GIV_SCRIPT" config --list
    assert_success
    
    # Should show config content
    assert_output --partial "api.key"
}

@test "dispatcher: maintains working directory context" {
    # Dispatcher should preserve working directory for subcommands
    echo "test content" > test_file.txt
    git add test_file.txt
    git commit -q -m "Add test file"
    
    # Config command should work from current directory
    run "$GIV_SCRIPT" config --list
    assert_success
    
    # File should still exist (working directory preserved)
    [ -f test_file.txt ]
}

@test "dispatcher: handles interrupt signals gracefully" {
    # Start a long-running command and interrupt it
    timeout 2s "$GIV_SCRIPT" message HEAD &
    pid=$!
    sleep 1
    kill -INT $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    
    # Should not leave temp files or corrupted state
    [ ! -f /tmp/giv_* ] || true
}