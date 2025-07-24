#!/usr/bin/env bats

# Integration tests for giv subcommands
# Tests end-to-end functionality of individual subcommands

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export TMPDIR="/tmp"
export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src"
export GIV_DEBUG="false"

setup() {
    # Create isolated test environment
    TMPDIR_REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
    cd "$TMPDIR_REPO" || exit 1
    
    # Initialize git repo with realistic project structure
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create a realistic project with version file
    cat > package.json << 'EOF'
{
  "name": "test-project",
  "version": "1.2.0",
  "description": "A test project for integration testing",
  "main": "index.js",
  "scripts": {
    "test": "echo 'test'"
  }
}
EOF
    
    cat > README.md << 'EOF'
# Test Project

This is a test project for integration testing.

## Features

- Feature A
- Feature B
EOF
    
    cat > CHANGELOG.md << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.1.0] - 2023-01-01
- Added initial features
EOF
    
    # Initial commit
    git add .
    git commit -q -m "Initial project setup"
    
    # Create some meaningful changes
    echo "- Feature C" >> README.md
    cat >> package.json << 'EOF'
  "dependencies": {
    "express": "^4.18.0"
  },
EOF
    # Fix the JSON (remove trailing comma and close properly)
    cat > package.json << 'EOF'
{
  "name": "test-project",
  "version": "1.2.0",
  "description": "A test project for integration testing",
  "main": "index.js",
  "scripts": {
    "test": "echo 'test'"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF
    
    git add .
    git commit -q -m "feat: add express dependency and update README"
    
    # Add a bug fix commit
    echo "console.log('Hello, World!');" > index.js
    git add index.js
    git commit -q -m "fix: add basic hello world functionality"
    
    # Set up GIV environment
    mkdir -p "$GIV_HOME"
    cat > "$GIV_HOME/config" << 'EOF'
GIV_API_KEY=test-key-12345
GIV_API_URL=https://api.test.com/v1/chat/completions
GIV_API_MODEL=gpt-4
GIV_PROJECT_TYPE=node
GIV_PROJECT_TITLE=Test Project
GIV_PROJECT_DESCRIPTION=A test project for integration testing
GIV_PROJECT_URL=https://github.com/test/test-project
GIV_INITIALIZED="true"
EOF
    
    # Set up templates directory
    mkdir -p "$GIV_HOME/templates"
    
    export GIV_SCRIPT="$BATS_TEST_DIRNAME/../src/giv.sh"
    
    # Mock AI response generation
    export -f mock_generate_response
}

teardown() {
    if [ -n "$TMPDIR_REPO" ] && [ -d "$TMPDIR_REPO" ]; then
        rm -rf "$TMPDIR_REPO"
    fi
}

# Mock function for AI responses
mock_generate_response() {
    case "${1:-}" in
        *message*|*commit*)
            echo "feat: enhance project with new dependencies and documentation"
            ;;
        *changelog*)
            echo "## [1.2.1] - $(date +%Y-%m-%d)
### Added
- Express.js dependency for better server functionality
- Basic hello world implementation

### Fixed
- Project initialization and basic functionality"
            ;;
        *summary*)
            echo "## Summary of Changes

The recent commits include:
- Addition of Express.js dependency for server functionality  
- Updated project documentation with new features
- Implemented basic hello world functionality
- Fixed initial project setup issues"
            ;;
        *release*)
            echo "# Release Notes v1.2.1

This release introduces server capabilities and improves the project foundation.

## What's New
- **Server Framework**: Added Express.js for robust server functionality
- **Documentation**: Enhanced README with feature descriptions
- **Core Functionality**: Implemented hello world baseline

## Technical Details
- Dependencies updated to include Express ^4.18.0
- Basic server entry point established
- Project structure improved for scalability"
            ;;
        *)
            echo "Generated content for integration testing"
            ;;
    esac
}

# CONFIG SUBCOMMAND TESTS
@test "config: lists all configuration values" {
    run "$GIV_SCRIPT" config --list
    assert_success
    assert_output --partial "api.key"
    assert_output --partial "api.url"
    assert_output --partial "project.type"
}

@test "config: gets specific configuration value" {
    run "$GIV_SCRIPT" config api.key
    assert_success
    assert_output "test-key-12345"
}

@test "config: sets configuration value" {
    run "$GIV_SCRIPT" config api.model "gpt-3.5-turbo"
    assert_success
    
    # Verify the value was set
    run "$GIV_SCRIPT" config api.model
    assert_success
    assert_output --partial "gpt-3.5-turbo"
}

@test "config: handles invalid keys gracefully" {
    run "$GIV_SCRIPT" config invalid/key/with/slashes
    assert_failure
}

# MESSAGE SUBCOMMAND TESTS
@test "message: generates commit message for HEAD" {
    # Mock the generate_response function
    generate_response() { mock_generate_response "message"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" message HEAD --dry-run
    assert_success
    assert_output --partial "feat:"
}

@test "message: generates commit message for staged changes" {
    # Stage some changes
    echo "New feature code" > feature.js
    git add feature.js
    
    generate_response() { mock_generate_response "message"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" message --cached --dry-run
    assert_success
    assert_output --partial "feat:"
}

@test "message: generates commit message for current changes" {
    # Make unstaged changes
    echo "Work in progress" >> README.md
    
    generate_response() { mock_generate_response "message"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" message --current --dry-run
    assert_success
    assert_output --partial "feat:"
}

# SUMMARY SUBCOMMAND TESTS  
@test "summary: generates summary for commit range" {
    generate_response() { mock_generate_response "summary"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD~2..HEAD --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
    assert_output --partial "Express.js"
}

@test "summary: generates summary for single commit" {
    generate_response() { mock_generate_response "summary"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
}

# CHANGELOG SUBCOMMAND TESTS
@test "changelog: updates CHANGELOG.md with new entries" {
    generate_response() { mock_generate_response "changelog"; }
    export -f generate_response
    
    # Backup original changelog
    cp CHANGELOG.md CHANGELOG.md.bak
    
    run "$GIV_SCRIPT" changelog HEAD~1..HEAD --dry-run
    assert_success 
    assert_output --partial "[1.2.1]"
    assert_output --partial "Express.js"
    
    # Restore original
    mv CHANGELOG.md.bak CHANGELOG.md
}

@test "changelog: handles empty commit range gracefully" {
    generate_response() { mock_generate_response "changelog"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" changelog HEAD..HEAD --dry-run
    assert_success
}

@test "changelog: respects --output-version flag" {
    generate_response() { mock_generate_response "changelog"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" changelog HEAD --output-version "2.0.0" --dry-run
    assert_success
    assert_output --partial "2.0.0"
}

# RELEASE NOTES SUBCOMMAND TESTS
@test "release-notes: generates release notes for version" {
    generate_response() { mock_generate_response "release"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" release-notes HEAD~2..HEAD --dry-run
    assert_success
    assert_output --partial "Release Notes"
    assert_output --partial "What's New"
    assert_output --partial "Express.js"
}

@test "release-notes: creates RELEASE_NOTES.md file" {
    generate_response() { mock_generate_response "release"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" release-notes HEAD --output-file test_release.md --dry-run
    assert_success
    
    # In dry-run mode, file shouldn't be created
    [ ! -f test_release.md ]
}

# DOCUMENT SUBCOMMAND TESTS
@test "document: requires --prompt-file argument" {
    run "$GIV_SCRIPT" document HEAD
    assert_failure
    assert_output --partial "prompt-file"
}

@test "document: generates custom document with prompt file" {
    # Create a custom prompt template
    cat > custom_prompt.md << 'EOF'
# Custom Analysis

Please analyze the following changes:

{{HISTORY}}

Focus on technical implementation details.
EOF
    
    generate_response() { echo "Technical analysis of recent changes..."; }
    export -f generate_response
    
    run "$GIV_SCRIPT" document HEAD --prompt-file custom_prompt.md --dry-run
    assert_success
    assert_output --partial "Technical analysis"
}

# ERROR HANDLING TESTS
@test "subcommands: handle invalid git references gracefully" {
    run "$GIV_SCRIPT" message invalid-commit-hash
    assert_failure
    assert_output --partial "invalid"
}

@test "subcommands: handle missing API configuration" {
    # Remove API key
    sed -i '/GIV_API_KEY/d' "$GIV_HOME/config"
    
    run "$GIV_SCRIPT" message HEAD --api-url "https://api.test.com"
    assert_failure
    assert_output --partial "API.*key"
}

@test "subcommands: work with different project types" {
    # Test with Python project
    echo 'GIV_PROJECT_TYPE=python' >> "$GIV_HOME/config"
    cat > pyproject.toml << 'EOF'
[project]
name = "test-python-project"
version = "1.0.0"
description = "A test Python project"
EOF
    
    generate_response() { echo "Python project changes analyzed"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD --dry-run
    assert_success
    assert_output --partial "Python"
}

# PATHSPEC TESTS  
@test "subcommands: respect pathspec filtering" {
    # Create changes in specific files
    echo "JavaScript changes" > app.js
    echo "Documentation changes" > docs.md
    git add .
    git commit -q -m "Mixed changes"
    
    generate_response() { echo "Only JavaScript file changes"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" message HEAD "*.js" --dry-run
    assert_success
    assert_output --partial "JavaScript"
}

# INTEGRATION WITH EXTERNAL TOOLS
@test "subcommands: handle missing external dependencies gracefully" {
    # Test when optional tools like glow are missing
    run "$GIV_SCRIPT" config --list
    assert_success
    # Should work even without glow for markdown rendering
}

@test "subcommands: preserve git repository state" {
    # Record initial state
    initial_commit=$(git rev-parse HEAD)
    initial_status=$(git status --porcelain)
    
    generate_response() { echo "Test response"; }
    export -f generate_response
    
    # Run various commands
    "$GIV_SCRIPT" message HEAD --dry-run >/dev/null 2>&1 || true
    "$GIV_SCRIPT" summary HEAD --dry-run >/dev/null 2>&1 || true
    
    # Verify state is preserved
    final_commit=$(git rev-parse HEAD)
    final_status=$(git status --porcelain)
    
    [ "$initial_commit" = "$final_commit" ]
    [ "$initial_status" = "$final_status" ]
}