#!/usr/bin/env bats
# tests/commands/summary.bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'helpers/setup.sh'
load "${GIV_LIB_DIR}/system.sh"
load "${GIV_LIB_DIR}/history.sh"
load "${GIV_LIB_DIR}/llm.sh"
load "${GIV_LIB_DIR}/project_metadata.sh"

setup() {
    export GIV_METADATA_PROJECT_TYPE="custom"
    rm -rf "$GIV_HOME/cache"  # clean up any old cache
    rm -rf "$GIV_HOME/.tmp"   # clean up any old tmp
    mkdir -p "$GIV_HOME/cache"
    mkdir -p "$GIV_HOME/.tmp"
    
    # Create a simple test repo using the standard approach from other tests
    TEST_REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
    cd "$TEST_REPO" || exit
    git init -q
    git config user.name "Test"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "First line" > file.txt
    git add file.txt
    git commit -q -m "chore: initial commit"
    
    # Create second commit  
    echo "Second line" >> file.txt
    git add file.txt
    git commit -q -m "feat: add second line"
    
    export TEST_REPO
    
    # Set required environment variables
    export GIV_API_KEY="test-api-key"  
    export GIV_API_URL="https://api.example.com"
}

teardown() {
    rm -rf "$TEST_REPO"
}

@test "summary subcommand basic functionality using direct function calls" {
    cd "$TEST_REPO"
    
    # Test that summarize_commit works with proper commit
    export GIV_DEBUG="true"
    commit_hash=$(git rev-parse HEAD)
    
    # Mock generate_response for testing
    generate_response() {
        cat "$1"  # Just output the prompt file content
    }
    
    run summarize_commit "$commit_hash" ""
    assert_success
    
    # Check that commit metadata is included
    assert_output --partial "Commit: $commit_hash"
    assert_output --partial "Date:"
    assert_output --partial "Message:"
    assert_output --partial "feat: add second line"
}

@test "build_commit_summary_prompt generates correct prompt structure" {
    cd "$TEST_REPO"
    
    commit_hash=$(git rev-parse HEAD)
    hist_file=$(portable_mktemp "test_hist_XXXXXXX")
    
    # Generate history for the commit
    build_history "$hist_file" "$commit_hash" ""
    
    # Test build_commit_summary_prompt function
    run build_commit_summary_prompt "1.0.0" "$hist_file"
    assert_success
    
    # Check that the prompt structure is correct
    assert_output --partial "# Summary Request"
    assert_output --partial "## Git Diff"
    assert_output --partial "## Instructions"
    assert_output --partial "### Commit ID $commit_hash"
    assert_output --partial "feat: add second line"
    assert_output --partial '```diff'
    assert_output --partial "file.txt"
    assert_output --partial "+Second line"
    
    rm -f "$hist_file"
}

@test "summarize_commit properly formats commit information" {
    cd "$TEST_REPO"
    
    commit_hash=$(git rev-parse HEAD)
    
    # Mock generate_response for testing
    generate_response() {
        cat "$1"  # Just output the prompt file content
    }
    
    # Test summarize_commit function directly
    run summarize_commit "$commit_hash"
    assert_success
    
    # Check commit metadata format (from save_commit_metadata)
    assert_output --partial "Commit: $commit_hash"
    assert_output --partial "Date: "
    assert_output --partial "Message:"
    assert_output --partial "feat: add second line"
    
    # Check that the prompt content is also included (from build_commit_summary_prompt)
    assert_output --partial "### Commit ID $commit_hash"
    assert_output --partial "**Date:**"
    assert_output --partial "**Message:**"
    assert_output --partial '```diff'
    assert_output --partial "file.txt"
    assert_output --partial "+Second line"
}

@test "build_history generates proper git diff content for commits" {
    cd "$TEST_REPO"
    
    commit_hash=$(git rev-parse HEAD)
    hist_file=$(portable_mktemp "test_hist_XXXXXXX")
    
    run build_history "$hist_file" "$commit_hash" ""
    assert_success
    
    # Check the contents of the generated history file
    run cat "$hist_file"
    assert_success
    assert_output --partial "### Commit ID $commit_hash"
    assert_output --partial "**Date:**"
    assert_output --partial "**Message:**"
    assert_output --partial "feat: add second line"
    assert_output --partial '```diff'
    assert_output --partial "file.txt"
    assert_output --partial "+Second line"
    
    rm -f "$hist_file"
}
