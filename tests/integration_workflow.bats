#!/usr/bin/env bats

# End-to-end workflow integration tests for giv
# Tests complete development workflows and real-world usage scenarios

#!/usr/bin/env bats
load './helpers/setup.sh'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export GIV_SCRIPT="$BATS_TEST_DIRNAME/../src/giv.sh"

setup() {
export GIV_DEBUG="true"
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
GIV_PROJECT_TITLE="Sample App"
GIV_PROJECT_DESCRIPTION="A sample application for workflow testing"
GIV_PROJECT_URL=https://github.com/test/sample-app
GIV_OUTPUT_MODE=auto
GIV_INITIALIZED="true"
EOF
    
    
}

teardown() {
    if [ -n "$TMPDIR_REPO" ] && [ -d "$TMPDIR_REPO" ]; then
        rm -rf "$TMPDIR_REPO"
    fi
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
    run "$GIV_SCRIPT" message --cached --dry-run
    assert_success
    assert_output --partial "feat: enhance project with new dependencies and documentation"
    
    # Commit the changes
    git commit -q -m "feat: add user authentication system with JWT tokens"
    
    # Step 3: Generate changelog
    run "$GIV_SCRIPT" changelog HEAD --dry-run
    assert_success
    assert_output --partial "[1.2.1]"
    assert_output --partial "Added"
    assert_output --partial "Express.js"
    
    # Step 4: Generate release notes
    run "$GIV_SCRIPT" release-notes HEAD --dry-run
    assert_success
    assert_output --partial "Release Notes v1.2.1"
    assert_output --partial "What's New"
    assert_output --partial "Server Framework"
    
    # Step 5: Generate development summary
    run "$GIV_SCRIPT" summary HEAD --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
    assert_output --partial "Express.js"
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
    run "$GIV_SCRIPT" summary HEAD~2..HEAD --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
    assert_output --partial "Express.js"
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
    
    run "$GIV_SCRIPT" message --cached --dry-run
    assert_success
    assert_output --partial "fix:"
    
    git commit -q -m "fix: resolve critical code injection vulnerability"
    
    run "$GIV_SCRIPT" changelog HEAD --output-version "0.1.1" --dry-run
    assert_success
    assert_output --partial "critical code injection vulnerability"
    assert_output --partial "Generate a comprehensive changelog in the Keep a Changelog format for  0.1.1"
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
    echo 'GIV_CUSTOM_SETTING="development"' > .env.giv
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
    run "$GIV_SCRIPT" summary HEAD "*.js" --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
    
    # Test documentation-only processing  
    run "$GIV_SCRIPT" summary HEAD "*.md" --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
    
    # Test exclusion patterns
    run "$GIV_SCRIPT" summary HEAD ":(exclude)*.sh" --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
}

# VERSION MANAGEMENT WORKFLOW
@test "workflow: version detection and management" {
    # Test automatic version detection
    run "$GIV_SCRIPT" summary HEAD --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
    
    # Update version and test detection
    sed -i 's/"version": "0\.1\.0"/"version": "1.0.0"/' package.json
    git add package.json
    git commit -q -m "bump: version to 1.0.0"
    
    run "$GIV_SCRIPT" summary HEAD --dry-run
    assert_success
    assert_output --partial "Summary of Changes"
}

# ERROR RECOVERY WORKFLOW
# @test "workflow: error handling and recovery" {
#     # Test recovery from various error conditions
    
#     # 1. Invalid git reference
#     run "$GIV_SCRIPT" message invalid-ref-12345
#     assert_failure
    
#     # 2. Missing configuration
#     mv "$GIV_HOME/config" "$GIV_HOME/config.bak"
#     run "$GIV_SCRIPT" config --list
#     assert_failure
#     mv "$GIV_HOME/config.bak" "$GIV_HOME/config"
    
#     # 3. Network/API failures (simulated)
#     export GIV_API_URL="https://invalid-api-endpoint.nowhere"
#     run timeout 5s "$GIV_SCRIPT" message HEAD --dry-run 2>/dev/null || true
#     # Should fail gracefully without hanging
    
#     # 4. Corrupted git repository
#     rm -rf .git/refs
#     run "$GIV_SCRIPT" message HEAD
#     assert_failure
    
#     # Recovery: reinitialize
#     git init -q
#     git config user.name "Developer"
#     git config user.email "dev@example.com"
# }

# CLEANUP AND MAINTENANCE WORKFLOW
@test "workflow: cleanup and maintenance operations" {
    # Generate some cached content
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