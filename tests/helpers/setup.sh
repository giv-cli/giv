#!/usr/bin/env bash

# Called before each test. Sets up isolated GIV_HOME, temp project repo, and symlinks sources.
set -e pipefail


# Directory for the test project repo
export PROJECT_DIR="${BATS_TMPDIR:-/tmp}/project-repo"

# Directory for isolated GIV_HOME
export GIV_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fixtures/giv-home" && pwd)"

reset_config(){
    {
        printf "GIV_API_URL=https://api.example.test\n"
        printf "GIV_API_MODEL=gpt-4\n"
        printf "GIV_PROJECT_TITLE=Test Project\n"
        printf "GIV_PROJECT_DESCRIPTION=This is a test project for GIV CLI.\n"
        printf "GIV_PROJECT_AUTHOR=Test Author\n"
        printf "GIV_PROJECT_VERSION=1.0.0\n"
        printf "GIV_PROJECT_LICENSE=MIT\n"
        printf "GIV_PROJECT_REPOSITORY=https://github.com/example/test-project.git\n"
    } > "$GIV_HOME/.giv/config"
}


export GIV_CONFIG_FILE="$GIV_HOME/.giv/config"
# Export GIV_LIB_DIR for test scripts
export GIV_LIB_DIR="./src"
export GIV_DEBUG="true"

# # Symlink real src into fixture GIV_HOME/lib
# if [ ! -L "$GIV_HOME/lib" ]; then
#   ln -sf "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../src" && pwd)" "$GIV_HOME/lib"
# fi

# Create a fresh project repo for each test
rm -rf "$PROJECT_DIR"
"$(cd "$(dirname "${BASH_SOURCE[0]}")/../fixtures" && pwd)/project-repo.sh" "$PROJECT_DIR"
reset_config
