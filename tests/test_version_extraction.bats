#!/usr/bin/env bats

export TMPDIR="/tmp"
export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src"
export GIV_DEBUG="true"
load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project_metadata.sh"

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'



setup() {
    TMPDIR_REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
    cd "$TMPDIR_REPO" || {
        echo "Failed to change directory to TMPDIR_REPO" >&2
        exit 1
    }
    git init
    git config user.name "Test"
    git config user.email "test@example.com"
    TMPFILE="$(mktemp -p "${TMPDIR_REPO}")"
    export TMPFILE

    # Create a version.txt file for custom project type
    echo "version = '1.0.0'" > version.txt
    export GIV_PROJECT_VERSION_FILE="version.txt"
    export GIV_PROJECT_TYPE="custom"
    
    # Ensure $GIV_HOME/config exists for all tests
    mkdir -p "$GIV_HOME"
    echo "GIV_API_KEY=XYZ" >"$GIV_HOME/config"
    echo "GIV_API_URL=TEST_URL" >>"$GIV_HOME/config"
    echo "GIV_API_MODEL=TEST_MODEL" >>"$GIV_HOME/config"

}

teardown() {
    remove_tmp_dir
    if [ -n "$TMPFILE" ]; then
        rm -f "$TMPFILE"
    fi
    if [ -n "$TMPDIR_REPO" ]; then
        rm -rf "$TMPDIR_REPO"
    fi
}

@test "get_version_info detects version from current file" {
    export GIV_PROJECT_TYPE="custom"
    export GIV_PROJECT_VERSION_FILE="version.txt"
    echo "version = '1.2.3'" >"version.txt"
    run get_metadata_value "version" "--current"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version from cached file" {
    export GIV_PROJECT_VERSION_FILE="version.txt"
    echo "version = '1.2.3'" >"version.txt"
    git add "version.txt"
    run get_metadata_value "version" "--cached"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version from specific commit" {
    echo "version = '1.2.3'" >"version.txt"
    git add "version.txt"
    git commit -m "Add version file"
    commit_hash=$(git rev-parse HEAD)
    export GIV_PROJECT_VERSION_FILE="version.txt"
    run get_metadata_value "version" "$commit_hash"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version with v-prefix" {
    export GIV_PROJECT_TYPE="custom"
    export GIV_PROJECT_VERSION_FILE="version.txt"
    echo "version = 'v1.2.3'" >"version.txt"
    run get_metadata_value "version" "--current"
    assert_success
    assert_equal "$output" "v1.2.3"
}

@test "get_version_info returns empty string if no version found" {
    export GIV_PROJECT_VERSION_FILE="version.txt"
    echo "No version here" >"$GIV_PROJECT_VERSION_FILE"
    run get_metadata_value "version" "--current"
    assert_success
    assert_equal "$output" ""
}

@test "get_version_info handles missing file gracefully" {
    export GIV_PROJECT_VERSION_FILE="nonexistent_file.txt"
    run get_metadata_value "version" "--current"
    assert_success
    assert_equal "$output" ""
}

@test "get_version_info detects version from JSON file" {
    export GIV_METADATA_PROJECT_TYPE="node"
    echo '{"version": "1.2.3"}' >"package.json"
    run get_metadata_value "version" "--current"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version from cached JSON file" {
    export GIV_METADATA_PROJECT_TYPE="node"
    echo '{"version": "1.2.3"}' >"package.json"
    git add "package.json"
    run get_metadata_value "version" "--cached"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version from specific commit JSON file" {
    export GIV_METADATA_PROJECT_TYPE="node"
    echo '{"version": "1.2.3"}' >"package.json"
    git add "package.json"
    git commit -m "Add JSON version file"
    commit_hash=$(git rev-parse HEAD)
    run get_metadata_value "version" "$commit_hash"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info handles multiple version strings and picks the first one" {
    export GIV_PROJECT_VERSION_FILE="version.txt"
    cat >"version.txt" <<EOF
version = '1.2.3'
version = '2.3.4'
EOF
    run get_metadata_value "version" "--current"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info handles invalid commit gracefully" {
    run get_metadata_value "version" "invalid_commit_hash"
    assert_success
    assert_equal "$output" ""
}

@test "get_version_info detects version from file in specific commit with multiple versions" {
    export GIV_PROJECT_VERSION_FILE="version.txt"
    export GIV_PROJECT_TYPE="custom"
    cat >"version.txt" <<EOF
version = '1.2.3'
version = '2.3.4'
EOF
    git add "version.txt"
    git commit -m "Add multiple versions"
    commit_hash=$(git rev-parse HEAD)
    run get_metadata_value "version" "$commit_hash"
    assert_success
    assert_equal "$output" "1.2.3"
}
