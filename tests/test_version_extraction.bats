#!/usr/bin/env bats


load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/project.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'


export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"

setup() {
    TMPDIR_REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
    cd "$TMPDIR_REPO"
    git init
    git config user.name "Test"
    git config user.email "test@example.com"
    TMPFILE="$(mktemp -p "${TMPDIR_REPO}")"
    export TMPFILE
    GIV_TMPDIR_SAVE=
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

# @test "get_current_version_from_file detects Version v1.2.3" {
#     echo "# Version: v1.2.3" >"$TMPFILE"
#     run get_current_version_from_file "$TMPFILE"
#     assert_success
#     assert_equal "$output" "v1.2.3"
# }

# @test "get_current_version_from_file detects version = '1.2.3'" {
#     echo "version = '1.2.3'" >"$TMPFILE"
#     run get_current_version_from_file "$TMPFILE"
#     assert_success
#     assert_equal "$output" "1.2.3"
# }

# @test "get_current_version_from_file detects version: " {
#     echo 'version: "1.2.3"' >"$TMPFILE"
#     run get_current_version_from_file "$TMPFILE"
#     assert_success
#     assert_equal "$output" "1.2.3"
# }

# @test "get_current_version_from_file detects __version__ = " {
#     echo '__version__ = "1.2.3"' >"$TMPFILE"
#     run get_current_version_from_file "$TMPFILE"
#     assert_success
#     assert_equal "$output" "1.2.3"
# }

# @test "get_current_version_from_file detects JSON version field" {
#     echo '{"version": "1.2.3"}' >"$TMPFILE"
#     run get_current_version_from_file "$TMPFILE"
#     assert_success
#     assert_equal "$output" "1.2.3"
# }

# @test "get_current_version_from_file detects v-prefixed version in JSON" {
#     echo '{"version": "v1.2.3"}' >"$TMPFILE"
#     run get_current_version_from_file "$TMPFILE"
#     assert_success
#     assert_equal "$output" "v1.2.3"
# }

# @test "get_current_version_from_file detects fallback version string" {
#     echo "Release notes for v2.0.0" >"$TMPFILE"
#     run get_current_version_from_file "$TMPFILE"
#     assert_success
#     assert_equal "$output" "v2.0.0"
# }

# @test "get_current_version_from_file returns empty string if no version found" {
#     echo "No version here" >"$TMPFILE"
#     run get_current_version_from_file "$TMPFILE"
#     assert_success
#     assert_equal "$output" ""
# }

@test "get_version_info detects version from current file" {
    echo "version = '1.2.3'" >"version.txt"
    run get_version_info "--current" "version.txt"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version from cached file" {
    echo "version = '1.2.3'" >"version.txt"
    git add "version.txt"
    run get_version_info "--cached" "version.txt"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version from specific commit" {
    echo "version = '1.2.3'" >"version.txt"
    git add "version.txt"
    git commit -m "Add version file"
    commit_hash=$(git rev-parse HEAD)
    run get_version_info "$commit_hash" "version.txt"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version with v-prefix" {
    echo "version = 'v1.2.3'" >"$TMPFILE"
    run get_version_info "--current" "$TMPFILE"
    assert_success
    assert_equal "$output" "v1.2.3"
}

@test "get_version_info returns empty string if no version found" {
    echo "No version here" >"$TMPFILE"
    run get_version_info "--current" "$TMPFILE"
    assert_success
    assert_equal "$output" ""
}

@test "get_version_info handles missing file gracefully" {
    run get_version_info "--current" "nonexistent_file.txt"
    assert_success
    assert_equal "$output" ""
}

@test "get_version_info detects version from JSON file" {
    echo '{"version": "1.2.3"}' >"package.json"
    run get_version_info "--current" "package.json"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version from cached JSON file" {
    echo '{"version": "1.2.3"}' >"package.json"
    git add "package.json"
    run get_version_info "--cached" "package.json"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info detects version from specific commit JSON file" {
    echo '{"version": "1.2.3"}' >"package.json"
    git add "package.json"
    git commit -m "Add JSON version file"
    commit_hash=$(git rev-parse HEAD)
    run get_version_info "$commit_hash" "package.json"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info handles multiple version strings and picks the first one" {
    cat >"version.txt" <<EOF
version = '1.2.3'
version = '2.3.4'
EOF
    run get_version_info "--current" "version.txt"
    assert_success
    assert_equal "$output" "1.2.3"
}

@test "get_version_info handles invalid commit gracefully" {
    run get_version_info "invalid_commit_hash" "$TMPFILE"
    assert_success
    assert_equal "$output" ""
}

@test "get_version_info detects version from file in specific commit with multiple versions" {
    cat >"version.txt" <<EOF
version = '1.2.3'
version = '2.3.4'
EOF
    git add "version.txt"
    git commit -m "Add multiple versions"
    commit_hash=$(git rev-parse HEAD)
    run get_version_info "$commit_hash" "version.txt"
    assert_success
    assert_equal "$output" "1.2.3"
}
