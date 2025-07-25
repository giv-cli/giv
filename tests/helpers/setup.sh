#!/usr/bin/env bash

# Called before each test. Sets up isolated GIV_HOME, temp project repo, and symlinks sources.
set -e pipefail


# Directory for the test project repo
export PROJECT_DIR="${BATS_TMPDIR:-/tmp}/project-repo"
# Create a fresh project repo for each test
rm -rf "$PROJECT_DIR"
if [ -n "$BATS_TEST_DIRNAME" ]; then
    # # When called from integration subdirectory, go up one more level
    # if [[ "$BATS_TEST_DIRNAME" == */integration ]]; then
    #     FIXTURES_DIR="$BATS_TEST_DIRNAME/../fixtures"
    # else
  FIXTURES_DIR="$BATS_TEST_DIRNAME/fixtures"
    # fi
else
    FIXTURES_DIR="$(cd "$(dirname "$0")/.." && pwd)/fixtures"
fi

# Directory for isolated GIV_HOME
export GIV_HOME="${FIXTURES_DIR}/giv-home/.giv"
mkdir -p "$GIV_HOME"
export GIV_CONFIG_FILE="${GIV_HOME}/config"


export TMPDIR="${BATS_TEST_DIRNAME}/.tmp"
export GIV_TMP_DIR="${BATS_TEST_DIRNAME}/.tmp"

export GIV_SRC_DIR="${BATS_TEST_DIRNAME}/../src"
# Export GIV_LIB_DIR for test scripts
export GIV_LIB_DIR="${BATS_TEST_DIRNAME}/../src/lib"
export GIV_TEMPLATE_DIR="${BATS_TEST_DIRNAME}/../templates"
export GIV_DOCS_DIR="${BATS_TEST_DIRNAME}/../docs"

export GIV_DEBUG="true"

# Always use the test mock for generate_response in all test runs
GIV_TEST_MOCKS_PATH="${BATS_TEST_DIRNAME}/helpers/mock_generate_response.sh"
export GIV_TEST_MOCKS
GIV_TEST_MOCKS="$GIV_TEST_MOCKS_PATH"

mkdir -p "$BATS_TEST_DIRNAME/.logs"
export ERROR_LOG="$BATS_TEST_DIRNAME/.logs/error.log"

reset_config(){
    mkdir -p "$GIV_HOME"
    rm -f "$GIV_HOME/config"
    cat > "$GIV_HOME/config" <<EOF
GIV_API_KEY=test-key-12345
GIV_API_URL=https://api.example.test
GIV_API_MODEL=gpt-4
GIV_PROJECT_TYPE=node
GIV_PROJECT_TITLE="Test Project"
GIV_PROJECT_DESCRIPTION="This is a test project for GIV CLI."
GIV_PROJECT_AUTHOR="Test Author"
GIV_PROJECT_VERSION=1.0.0
GIV_PROJECT_LICENSE=MIT
GIV_PROJECT_REPOSITORY=https://github.com/example/test-project.git
GIV_INITIALIZED=true
EOF
}

"$FIXTURES_DIR/project-repo.sh" "$PROJECT_DIR"


reset_config
