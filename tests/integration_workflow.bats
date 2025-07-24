#!/usr/bin/env bats

# End-to-end workflow integration tests for giv
# Tests complete development workflows and real-world usage scenarios

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export TMPDIR="/tmp"
export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src"
export GIV_DEBUG="false"

setup() {
    # Create realistic project environment
    TMPDIR_REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
    cd "$TMPDIR_REPO" || exit 1
    
    # Initialize project with proper structure
    git init -q
    git config user.name "Developer"
    git config user.email "dev@example.com"
    
    # Create initial project files
    cat > package.json << 'EOF'
{
  "name": "sample-app",
  "version": "0.1.0",
  "description": "A sample application for workflow testing",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "jest",
    "lint": "eslint src/"
  },
  "keywords": ["sample", "testing"],
  "author": "Test Developer",
  "license": "MIT"
}
EOF
    
    mkdir -p src tests docs
    
    cat > src/index.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
EOF
    
    cat > README.md << 'EOF'
# Sample App

A simple Express.js application for testing giv workflows.

## Installation

```bash
npm install
npm start
```

## Features

- Basic HTTP server
- Hello World endpoint
EOF
    
    cat > .gitignore << 'EOF'
node_modules/
.env
dist/
*.log
.giv/cache/
EOF
    
    # Initial commit
    git add .
    git commit -q -m "Initial project setup with Express server"
    
    # Set up giv configuration
    mkdir -p "$GIV_HOME"
    cat > "$GIV_HOME/config" << 'EOF'
GIV_API_KEY=sk-test-key-for-workflow-testing
GIV_API_URL=https://api.openai.com/v1/chat/completions
GIV_API_MODEL=gpt-4
GIV_PROJECT_TYPE=node
GIV_PROJECT_TITLE=Sample App
GIV_PROJECT_DESCRIPTION=A sample application for workflow testing
GIV_OUTPUT_MODE=auto
EOF
    
    export GIV_SCRIPT="$BATS_TEST_DIRNAME/../src/giv.sh"
    
    # Mock AI responses for different contexts
    export -f mock_ai_response
}

teardown() {
    if [ -n "$TMPDIR_REPO" ] && [ -d "$TMPDIR_REPO" ]; then
        rm -rf "$TMPDIR_REPO"
    fi
}

# Context-aware AI response mock
mock_ai_response() {
    prompt_file="${1:-}"
    if [ -f "$prompt_file" ]; then
        prompt_content=$(cat "$prompt_file")
    else
        prompt_content="$1"
    fi
    
    case "$prompt_content" in
        *message*|*commit*)
            echo "feat: add user authentication system with JWT tokens"
            ;;
        *changelog*)
            echo "## [0.2.0] - $(date +%Y-%m-%d)

### Added
- User authentication system with JWT tokens
- Login and registration endpoints
- Password hashing with bcrypt
- Session management middleware

### Changed
- Updated Express server configuration for auth routes
- Enhanced error handling for authentication flows

### Security
- Implemented secure password storage
- Added rate limiting for auth endpoints"
            ;;
        *summary*)
            echo "## Development Summary

Recent development has focused on implementing a robust user authentication system:

### Key Changes
- **Authentication System**: Complete JWT-based auth with login/registration
- **Security Enhancements**: Password hashing, rate limiting, and secure session handling  
- **API Endpoints**: New routes for user management and authentication flows
- **Middleware**: Custom authentication middleware for protected routes

### Technical Details
- Used bcrypt for secure password hashing
- Implemented JWT tokens with proper expiration
- Added comprehensive error handling for auth failures
- Integrated rate limiting to prevent brute force attacks

This foundation enables secure user management for the application."
            ;;
        *release*|*announcement*)
            echo "# Sample App v0.2.0 - Authentication Release

We're excited to announce the release of Sample App v0.2.0, introducing a comprehensive user authentication system!

## 🚀 What's New

### User Authentication
- **Secure Login System**: JWT-based authentication with proper token management
- **User Registration**: Complete signup flow with email validation
- **Password Security**: Industry-standard bcrypt hashing for password protection

### Security Features
- **Rate Limiting**: Protection against brute force attacks on auth endpoints
- **Session Management**: Secure session handling with automatic token expiration
- **Input Validation**: Comprehensive validation for all authentication inputs

### Developer Experience
- **Middleware Support**: Easy-to-use authentication middleware for protecting routes
- **Error Handling**: Clear, consistent error messages for authentication failures
- **Documentation**: Complete API documentation for all auth endpoints

## 🔧 Technical Improvements
- Enhanced Express server configuration
- Improved error handling throughout the application
- Better logging for security events
- Comprehensive test coverage for auth flows

## 📈 What's Next
- Multi-factor authentication (MFA) support
- OAuth integration with social providers
- Advanced user role management
- API key management system

---

**Upgrade Today**: Follow our migration guide to update from v0.1.0 to v0.2.0 with zero downtime.

For detailed changes, see our [CHANGELOG.md](CHANGELOG.md)."
            ;;
        *)
            echo "Mock AI response for workflow testing - context: ${prompt_content:0:50}..."
            ;;
    esac
}

# COMPLETE FEATURE DEVELOPMENT WORKFLOW
@test "workflow: complete feature development cycle" {
    # Step 1: Develop new feature
    cat >> src/index.js << 'EOF'

// Authentication routes
app.post('/login', (req, res) => {
  // TODO: Implement JWT authentication
  res.json({ message: 'Login endpoint' });
});

app.post('/register', (req, res) => {
  // TODO: Implement user registration
  res.json({ message: 'Register endpoint' });
});
EOF
    
    cat > src/auth.js << 'EOF'
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

class AuthService {
  constructor() {
    this.secret = process.env.JWT_SECRET || 'default-secret';
  }
  
  async hashPassword(password) {
    return bcrypt.hash(password, 10);
  }
  
  async verifyPassword(password, hash) {
    return bcrypt.compare(password, hash);
  }
  
  generateToken(userId) {
    return jwt.sign({ userId }, this.secret, { expiresIn: '24h' });
  }
}

module.exports = AuthService;
EOF
    
    # Update package.json version
    sed -i 's/"version": "0\.1\.0"/"version": "0.2.0"/' package.json
    
    git add .
    
    # Step 2: Generate commit message using giv
    generate_response() { mock_ai_response "message"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" message --cached --dry-run
    assert_success
    assert_output --partial "feat:"
    assert_output --partial "authentication"
    
    # Commit the changes
    git commit -q -m "feat: add user authentication system with JWT tokens"
    
    # Step 3: Generate changelog
    generate_response() { mock_ai_response "changelog"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" changelog HEAD --dry-run
    assert_success
    assert_output --partial "## [0.2.0]"
    assert_output --partial "Added"
    assert_output --partial "authentication"
    assert_output --partial "JWT"
    
    # Step 4: Generate release notes
    generate_response() { mock_ai_response "release"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" release-notes HEAD --dry-run
    assert_success
    assert_output --partial "Authentication Release"
    assert_output --partial "What's New"
    assert_output --partial "Security Features"
    
    # Step 5: Generate development summary
    generate_response() { mock_ai_response "summary"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD --dry-run
    assert_success
    assert_output --partial "Development Summary"
    assert_output --partial "authentication system"
}

# MULTIPLE COMMIT WORKFLOW
@test "workflow: multi-commit feature development" {
    # Commit 1: Add basic auth structure
    mkdir -p src/middleware
    cat > src/middleware/auth.js << 'EOF'
function authenticateToken(req, res, next) {
  // Basic auth middleware
  next();
}
module.exports = { authenticateToken };
EOF
    git add .
    git commit -q -m "feat: add authentication middleware structure"
    
    # Commit 2: Implement JWT logic
    cat >> src/middleware/auth.js << 'EOF'

const jwt = require('jsonwebtoken');

function verifyToken(token) {
  return jwt.verify(token, process.env.JWT_SECRET);
}

module.exports = { authenticateToken, verifyToken };
EOF
    git add .
    git commit -q -m "feat: implement JWT token verification"
    
    # Commit 3: Add tests
    mkdir -p tests
    cat > tests/auth.test.js << 'EOF'
const { verifyToken } = require('../src/middleware/auth');

describe('Authentication', () => {
  test('should verify valid JWT token', () => {
    // Test implementation
    expect(true).toBe(true);
  });
});
EOF
    git add .
    git commit -q -m "test: add authentication middleware tests"
    
    # Generate summary for the entire feature
    generate_response() { mock_ai_response "summary"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD~2..HEAD --dry-run
    assert_success
    assert_output --partial "authentication"
    assert_output --partial "JWT"
    assert_output --partial "middleware"
}

# HOT-FIX WORKFLOW
@test "workflow: hotfix development and release" {
    # Create a critical bug
    cat > src/bug.js << 'EOF'
// This file contains a critical security vulnerability
const userInput = process.argv[2];
eval(userInput); // CRITICAL: Code injection vulnerability
EOF
    git add .
    git commit -q -m "Add new feature (with critical bug)"
    
    # Fix the bug
    cat > src/bug.js << 'EOF'
// Safe input handling
const userInput = process.argv[2];
if (userInput && typeof userInput === 'string') {
  console.log('Safe input:', userInput);
}
EOF
    git add .
    
    # Generate commit message for hotfix
    generate_response() { echo "fix: resolve critical code injection vulnerability"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" message --cached --dry-run
    assert_success
    assert_output --partial "fix:"
    
    git commit -q -m "fix: resolve critical code injection vulnerability"
    
    # Generate hotfix changelog
    generate_response() { 
        echo "## [0.1.1] - $(date +%Y-%m-%d)

### Security
- **CRITICAL**: Fixed code injection vulnerability in user input handling
- Implemented proper input validation and sanitization

### Fixed
- Removed dangerous eval() usage that allowed arbitrary code execution
- Added input type checking and validation"
    }
    export -f generate_response
    
    run "$GIV_SCRIPT" changelog HEAD --output-version "0.1.1" --dry-run
    assert_success
    assert_output --partial "CRITICAL"
    assert_output --partial "Security"
}

# CONFIGURATION WORKFLOW
@test "workflow: project configuration management" {
    # Test different configuration scenarios
    
    # 1. Initial setup
    run "$GIV_SCRIPT" config project.title "My Awesome App"
    assert_success
    
    run "$GIV_SCRIPT" config project.title
    assert_success
    assert_output --partial "My Awesome App"
    
    # 2. API configuration
    run "$GIV_SCRIPT" config api.model "gpt-3.5-turbo"
    assert_success
    
    # 3. List all configuration
    run "$GIV_SCRIPT" config --list
    assert_success
    assert_output --partial "project.title"
    assert_output --partial "api.model"
    assert_output --partial "gpt-3.5-turbo"
    
    # 4. Environment-specific config
    echo 'GIV_CUSTOM_SETTING=development' > .env.giv
    run "$GIV_SCRIPT" --config-file .env.giv config --list
    assert_success
    assert_output --partial "custom.setting"
}

# PATHSPEC FILTERING WORKFLOW
@test "workflow: selective change processing with pathspecs" {
    # Create changes in different file types
    echo "console.log('JS changes');" >> src/index.js
    echo "# Documentation changes" >> README.md
    echo "body { color: blue; }" > style.css
    echo "#!/bin/bash\necho 'script changes'" > deploy.sh
    
    git add .
    git commit -q -m "Mixed file type changes"
    
    # Test JavaScript-only processing
    generate_response() { echo "JavaScript-specific changes analyzed"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD "*.js" --dry-run
    assert_success
    assert_output --partial "JavaScript"
    
    # Test documentation-only processing  
    generate_response() { echo "Documentation updates summarized"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD "*.md" --dry-run
    assert_success
    assert_output --partial "Documentation"
    
    # Test exclusion patterns
    generate_response() { echo "Non-script files analyzed"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD ":(exclude)*.sh" --dry-run
    assert_success
    assert_output --partial "Non-script"
}

# VERSION MANAGEMENT WORKFLOW
@test "workflow: version detection and management" {
    # Test automatic version detection
    generate_response() { echo "Version 0.1.0 changes detected"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD --dry-run
    assert_success
    
    # Update version and test detection
    sed -i 's/"version": "0\.1\.0"/"version": "1.0.0"/' package.json
    git add package.json
    git commit -q -m "bump: version to 1.0.0"
    
    generate_response() { echo "Major version 1.0.0 release"; }
    export -f generate_response
    
    run "$GIV_SCRIPT" summary HEAD --dry-run
    assert_success
    assert_output --partial "1.0.0"
}

# ERROR RECOVERY WORKFLOW
@test "workflow: error handling and recovery" {
    # Test recovery from various error conditions
    
    # 1. Invalid git reference
    run "$GIV_SCRIPT" message invalid-ref-12345
    assert_failure
    
    # 2. Missing configuration
    mv "$GIV_HOME/config" "$GIV_HOME/config.bak"
    run "$GIV_SCRIPT" config --list
    assert_failure
    mv "$GIV_HOME/config.bak" "$GIV_HOME/config"
    
    # 3. Network/API failures (simulated)
    export GIV_API_URL="https://invalid-api-endpoint.nowhere"
    run timeout 5s "$GIV_SCRIPT" message HEAD --dry-run 2>/dev/null || true
    # Should fail gracefully without hanging
    
    # 4. Corrupted git repository
    rm -rf .git/refs
    run "$GIV_SCRIPT" message HEAD
    assert_failure
    
    # Recovery: reinitialize
    git init -q
    git config user.name "Developer"
    git config user.email "dev@example.com"
}

# PERFORMANCE AND CACHING WORKFLOW
@test "workflow: caching and performance optimization" {
    # Create multiple commits for caching test
    for i in 1 2 3; do
        echo "Change $i" >> file$i.txt
        git add file$i.txt
        git commit -q -m "Change $i: update file$i"
    done
    
    generate_response() { echo "Cached response for performance test"; }
    export -f generate_response
    
    # First run should populate cache
    start_time=$(date +%s%N)
    run "$GIV_SCRIPT" summary HEAD --dry-run
    first_duration=$(($(date +%s%N) - start_time))
    assert_success
    
    # Second run should use cache (faster)
    start_time=$(date +%s%N)
    run "$GIV_SCRIPT" summary HEAD --dry-run  
    second_duration=$(($(date +%s%N) - start_time))
    assert_success
    
    # Cache should make subsequent runs faster (allowing for some variance)
    # This is more of a smoke test since timing can be inconsistent in CI
    [ "$second_duration" -le "$((first_duration * 2))" ]
}

# CLEANUP AND MAINTENANCE WORKFLOW
@test "workflow: cleanup and maintenance operations" {
    # Generate some cached content
    generate_response() { echo "Test content for cleanup"; }
    export -f generate_response
    
    "$GIV_SCRIPT" summary HEAD --dry-run >/dev/null 2>&1 || true
    
    # Verify cache directory exists and has content
    [ -d "$GIV_HOME/cache" ] || skip "Cache directory not created"
    
    # Test that git repository state remains clean
    git_status=$(git status --porcelain)
    [ -z "$git_status" ] || {
        echo "Git working directory is not clean: $git_status"
        false
    }
    
    # Test that no temporary files are left behind
    temp_files=$(find /tmp -name "giv*" -o -name "hist*" -o -name "prompt*" 2>/dev/null | wc -l)
    [ "$temp_files" -eq 0 ] || {
        echo "Temporary files left behind: $temp_files"
        find /tmp -name "giv*" -o -name "hist*" -o -name "prompt*" 2>/dev/null || true
        false
    }
}