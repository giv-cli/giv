#!/usr/bin/env bats
# tests/history.bats - Comprehensive tests for history functions

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'helpers/setup.sh'

# Test setup - create a test repo with actual commits and changes
setup() {
    # Create a test repository with real commits
    TEST_REPO="$BATS_TMPDIR/test-repo"
    rm -rf "$TEST_REPO"
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    
    # Initialize git repo
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "line 1" > file1.txt
    echo "function test() {" > script.js
    echo "  return 'hello';" >> script.js
    echo "}" >> script.js
    git add .
    git commit -m "feat: initial commit with file1.txt and script.js"
    INITIAL_COMMIT=$(git rev-parse HEAD)
    
    # Create second commit with changes
    echo "line 2" >> file1.txt
    echo "new file content" > file2.txt
    sed -i "s/return 'hello'/return 'world'/" script.js
    git add .
    git commit -m "feat: add file2.txt and modify script.js

- Added new file2.txt with content
- Modified script.js to return 'world' instead of 'hello'
- Appended line 2 to file1.txt"
    SECOND_COMMIT=$(git rev-parse HEAD)
    
    # Create working directory changes (for --current testing)
    echo "line 3" >> file1.txt
    echo "console.log('debug');" >> script.js
    echo "unstaged file" > file3.txt
    
    # Export commit hashes for tests
    export INITIAL_COMMIT SECOND_COMMIT TEST_REPO
    
    # Set up giv environment
    export GIV_HOME="$TEST_REPO/.giv"
    mkdir -p "$GIV_HOME/cache"
    export GIV_TEMPLATE_DIR="$BATS_TEST_DIRNAME/../templates"
    export GIV_SRC_DIR="$BATS_TEST_DIRNAME/../src"
    export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src/lib"
}

teardown() {
    cd "$BATS_TEST_DIRNAME"
    rm -rf "$TEST_REPO"
}

@test "get_diff extracts correct diff for --current" {
    cd "$TEST_REPO"
    
    # Source the history functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    
    diff_file="$BATS_TMPDIR/diff_output"
    get_diff "--current" "" "$diff_file"
    
    # Check that diff file contains the working directory changes
    assert [ -f "$diff_file" ]
    
    # Should contain changes to file1.txt (line 3 addition)
    run cat "$diff_file"
    assert_output --partial "file1.txt"
    assert_output --partial "+line 3"
    
    # Should contain changes to script.js (console.log addition)
    assert_output --partial "script.js"
    assert_output --partial "+console.log('debug');"
}

@test "get_diff extracts correct diff for specific commit" {
    cd "$TEST_REPO"
    
    # Source the history functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    
    diff_file="$BATS_TMPDIR/diff_output"
    get_diff "$SECOND_COMMIT" "" "$diff_file"
    
    # Check that diff file contains the commit changes
    assert [ -f "$diff_file" ]
    
    run cat "$diff_file"
    # Should contain changes from second commit
    assert_output --partial "file1.txt"
    assert_output --partial "+line 2"
    assert_output --partial "file2.txt"
    assert_output --partial "+new file content"
    assert_output --partial "script.js"
    assert_output --partial "-  return 'hello';"
    assert_output --partial "+  return 'world';"
}

@test "build_diff includes untracked files for --current" {
    cd "$TEST_REPO"
    
    # Source the history functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    
    diff_output=$(build_diff "--current" "")
    
    # Should include tracked file changes
    echo "$diff_output" | grep -q "file1.txt"
    echo "$diff_output" | grep -q "+line 3"
    
    # Should include untracked files
    echo "$diff_output" | grep -q "file3.txt"
    echo "$diff_output" | grep -q "+unstaged file"
}

@test "build_history generates complete history with diff content" {
    cd "$TEST_REPO"
    
    # Source the history functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    
    hist_file="$BATS_TMPDIR/history_output"
    build_history "$hist_file" "$SECOND_COMMIT"
    
    assert [ -f "$hist_file" ]
    
    run cat "$hist_file"
    
    # Should contain commit metadata
    assert_output --partial "### Commit ID $SECOND_COMMIT"
    assert_output --partial "**Date:**"
    assert_output --partial "**Message:**"
    
    # Should contain the actual diff in code blocks
    assert_output --partial "\`\`\`diff"
    assert_output --partial "file1.txt"
    assert_output --partial "+line 2"
    assert_output --partial "file2.txt" 
    assert_output --partial "+new file content"
    assert_output --partial "script.js"
    assert_output --partial "-  return 'hello';"
    assert_output --partial "+  return 'world';"
    assert_output --partial "\`\`\`"
}

@test "build_history for --current includes working directory changes" {
    cd "$TEST_REPO"
    
    # Source the history functions  
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    
    hist_file="$BATS_TMPDIR/history_current"
    build_history "$hist_file" "--current"
    
    assert [ -f "$hist_file" ]
    
    run cat "$hist_file"
    
    # Should contain current changes metadata
    assert_output --partial "### Commit ID --current"
    assert_output --partial "**Message:**"
    assert_output --partial "Current Changes"
    
    # Should contain working directory diffs
    assert_output --partial "\`\`\`diff"
    assert_output --partial "file1.txt"
    assert_output --partial "+line 3"
    assert_output --partial "script.js" 
    assert_output --partial "+console.log('debug');"
    
    # Should include untracked files
    assert_output --partial "file3.txt"
    assert_output --partial "+unstaged file"
}

@test "generate_commit_history creates history file with expected content" {
    cd "$TEST_REPO"
    
    # Source the history functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    
    hist_file="$BATS_TMPDIR/gen_history"
    generate_commit_history "$hist_file" "$SECOND_COMMIT" ""
    
    assert [ -f "$hist_file" ]
    
    # Verify the history file has the expected structure and content
    run cat "$hist_file"
    
    # Check for proper markdown structure
    assert_output --partial "### Commit ID"
    assert_output --partial "**Date:**"
    assert_output --partial "**Message:**"
    
    # Check that actual git diff content is present
    assert_output --partial "file1.txt"
    assert_output --partial "file2.txt"
    assert_output --partial "script.js"
    
    # Verify diff markers are present
    assert_output --partial "@@"
    assert_output --partial "+"
    assert_output --partial "-"
}

@test "build_commit_summary_prompt includes diff content from history" {
    cd "$TEST_REPO"
    
    # Source required functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    . "$GIV_LIB_DIR/markdown.sh"
    . "$GIV_LIB_DIR/llm.sh"
    
    # First generate history file
    hist_file="$BATS_TMPDIR/history_for_prompt"
    generate_commit_history "$hist_file" "$SECOND_COMMIT" ""
    
    # Build summary prompt
    prompt_content=$(build_commit_summary_prompt "1.0.0" "$hist_file")
    
    # Check that prompt contains the diff content from history
    echo "$prompt_content" | grep -q "file1.txt"
    echo "$prompt_content" | grep -q "file2.txt" 
    echo "$prompt_content" | grep -q "script.js"
    
    # Check that it contains actual diff lines
    echo "$prompt_content" | grep -q "+line 2"
    echo "$prompt_content" | grep -q "+new file content"
    echo "$prompt_content" | grep -q "return 'world'"
}

@test "summarize_commit end-to-end creates proper summary with diffs" {
    cd "$TEST_REPO"
    
    # Source all required functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    . "$GIV_LIB_DIR/markdown.sh" 
    . "$GIV_LIB_DIR/project_metadata.sh"
    . "$GIV_LIB_DIR/llm.sh"
    
    # Mock generate_response to return the prompt content instead of calling LLM
    generate_response() {
        prompt_file="$1"
        echo "=== PROMPT CONTENT ==="
        cat "$prompt_file"
        echo "=== END PROMPT ==="
    }
    export -f generate_response
    
    # Call summarize_commit
    summary_output=$(summarize_commit "$SECOND_COMMIT" "")
    
    # Check that the summary output contains diff content
    echo "$summary_output" | grep -q "file1.txt"
    echo "$summary_output" | grep -q "file2.txt"
    echo "$summary_output" | grep -q "script.js"
    
    # Check for actual diff lines in the prompt
    echo "$summary_output" | grep -q "+line 2"
    echo "$summary_output" | grep -q "+new file content"
    echo "$summary_output" | grep -q "return 'world'"
    
    # Verify the prompt structure is intact
    echo "$summary_output" | grep -q "Git Diff"
    echo "$summary_output" | grep -q "Instructions"
}

@test "summarize_commit for --current includes working directory changes in prompt" {
    cd "$TEST_REPO"
    
    # Source all required functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    . "$GIV_LIB_DIR/markdown.sh"
    . "$GIV_LIB_DIR/project_metadata.sh"
    . "$GIV_LIB_DIR/llm.sh"
    
    # Mock generate_response to return the prompt content
    generate_response() {
        prompt_file="$1"
        echo "=== CURRENT CHANGES PROMPT ==="
        cat "$prompt_file"
        echo "=== END PROMPT ==="
    }
    export -f generate_response
    
    # Call summarize_commit for current changes
    summary_output=$(summarize_commit "--current" "")
    
    # Check that working directory changes are included
    echo "$summary_output" | grep -q "file1.txt"
    echo "$summary_output" | grep -q "+line 3"
    echo "$summary_output" | grep -q "script.js"
    echo "$summary_output" | grep -q "+console.log('debug');"
    
    # Check that untracked files are included
    echo "$summary_output" | grep -q "file3.txt" 
    echo "$summary_output" | grep -q "+unstaged file"
    
    # Verify proper prompt structure
    echo "$summary_output" | grep -q "Current Changes"
    echo "$summary_output" | grep -q "Git Diff"
}

@test "diff content is properly escaped in markdown code blocks" {
    cd "$TEST_REPO" 
    
    # Create a file with special characters that might break markdown
    echo 'const text = "hello `world` **bold**";' > special.js
    git add special.js
    git commit -m "add file with markdown chars"
    SPECIAL_COMMIT=$(git rev-parse HEAD)
    
    # Source functions
    . "$GIV_LIB_DIR/system.sh"
    . "$GIV_LIB_DIR/history.sh"
    
    hist_file="$BATS_TMPDIR/special_history"
    build_history "$hist_file" "$SPECIAL_COMMIT"
    
    run cat "$hist_file"
    
    # Should contain the file with special characters in diff block
    assert_output --partial "special.js"
    assert_output --partial "\`\`\`diff"
    assert_output --partial 'const text = "hello `world` **bold**";' 
    assert_output --partial "\`\`\`"
    
    # The content should be properly contained within code blocks
    # Check that the diff markers are present
    assert_output --partial "@@"
    assert_output --partial "+"
}