#!/usr/bin/env bats

mkdir -p "$BATS_TEST_DIRNAME/.logs"
export ERROR_LOG="$BATS_TEST_DIRNAME/.logs/error.log"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project/metadata.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"

SCRIPT="$BATS_TEST_DIRNAME/../src/history.sh"
load "$SCRIPT"

export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"
setup() {
    export GIV_METADATA_PROJECT_TYPE="custom"
    rm -rf "$GIV_HOME/cache"  # clean up any old cache
    rm -rf "$GIV_HOME/.tmp"  # clean up any old tmp
    mkdir -p "$GIV_HOME/cache"
    mkdir -p "$GIV_HOME/.tmp"

    # Create a temporary git repo
    REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
    cd "$REPO" || exit
    git init -q

    git config user.name "Test"
    git config user.email "test@example.com"
    touch giv.sh
    echo 'Version: 0.1.0' >package.json
    git add giv.sh package.json
    git commit -m "Initial commit"

    # Commit version 1.0.0
    printf '{ "version": "1.0.0" }\n' >package.json
    git add package.json
    git commit -q -m "Initial version 1.0.0"

    # Commit other file
    printf 'some other file\n' >file.txt
    git add file.txt
    git commit -q -m "Add some other file"

    # Commit version 1.1.0
    printf '{ "version": "1.1.0" }\n' >package.json
    git add package.json
    git commit -q -m "Bump to 1.1.0"

   
    extract_todo_changes() {
        # By default, no TODO changes
        return 0
    }



    # Set required environment variables
    export GIV_API_KEY="test-api-key"
    export GIV_API_URL="https://api.example.com"

}

teardown() {
    remove_tmp_dir
    rm -rf "$REPO"
}

@test "build_history for HEAD shows updated version and diff block" {
    hist="$(mktemp)"

    build_history "$hist" HEAD
    assert_success
    run cat "$hist"
    assert_output --partial "Bump to 1.1.0"
    assert_output --partial "-{ \"version\": \"1.0.0\" }"
    assert_output --partial "+{ \"version\": \"1.1.0\" }"
}

@test "build_history for HEAD~2 shows previous version" {
    hist="$(mktemp)"
    build_history "$hist" HEAD~2
    assert_success
    run cat "$hist"
    assert_output --partial "Initial version 1.0.0"
    assert_output --partial "1 file changed, 1 insertion(+), 1 deletion(-)"
}

@test "build_history with no version file emits only diff block" {
    # Remove the version file and commit that change
    rm package.json
    git add -u
    git commit -q -m "Remove version file"

    hist="$(mktemp)"
    build_history "$hist" HEAD

    # Should NOT contain any Version: header
    run grep -q "\*\*Version:\*\*" "$hist"
    assert_failure

    # Should still contain a diff block
    run grep -F '```diff' "$hist"
    [ "$status" -eq 0 ]
}

@test "build_history appends TODO section when extract_todo_changes returns data" {
    # Override extract_todo_changes to simulate TODOs
    extract_todo_changes() {
        echo "+ TODO: fix this"
    }

    hist="$(mktemp)"
    build_history "$hist" HEAD

    # Should include the TODO section header
    run grep -F "### TODO Changes" "$hist"
    [ "$status" -eq 0 ]

    # And the mock TODO line
    run grep -F "+ TODO: fix this" "$hist"
    [ "$status" -eq 0 ]
}

@test "build_history respects PATTERN environment variable" {
    # Only include package.json in diff
    export PATTERN="package.json"
    export debug="1"
    echo "$(git --no-pager diff HEAD^! --minimal --no-prefix --unified=0 --no-color -b -w --compact-summary --color-moved=no -- \"package.json\")"
    echo "end of diff"
    hist="$(mktemp)"
    build_history "$hist" HEAD "todo" "$PATTERN"
    cat "$hist"
    # The diff block should reference package.json
    run grep -F '```diff' "$hist"
    assert_success

    run grep -F 'package.json' "$hist"
    assert_success
}
@test "build_history respects no pattern" {

    printf '{ "version": "1.2.0" }\n' >package.json
    hist="$(mktemp)"
    build_history "$hist" "--current"
    assert_success
    cat "$hist"
    run grep -F '1.2.0' "$hist"
    assert_success

}

@test "build_history includes untracked files" {

    printf '{ "version": "1.2.0" }\n' >package.json
    printf 'untracked file content\n' >untracked.txt
    hist="$(mktemp)"
    build_history "$hist" "--current"
    assert_success
    cat "$hist"
    run grep -F '1.2.0' "$hist"
    assert_success
    run grep -F 'untracked.txt' "$hist"
    assert_success

}

@test "get_message_header with --cached returns 'Staged Changes'" {
    run get_message_header --cached
    assert_success
    assert_output --partial "Staged Changes"
}

@test "get_message_header with --current returns 'Current Changes'" {
    run get_message_header --current
    assert_success
    assert_output --partial "Current Changes"
}

@test "get_message_header with empty string returns 'Current Changes'" {
    run get_message_header ""
    assert_success
    assert_output --partial "Current Changes"
}

@test "get_message_header with commit hash returns commit message" {
    debug=""
    commit=$(git rev-parse HEAD)
    run get_message_header "$commit"
    assert_success
    assert_output --partial "Bump to 1.1.0"
}

# @test "find_version_file finds package.json" {
#     debug=""
#     run find_version_file
#     assert_success
#     assert_output "package.json"
# }


@test "build_diff outputs minimal diff with tracked change" {
    echo "new line" >>giv.sh
    git add giv.sh
    run build_diff --cached "" false
    assert_success
    assert_output --partial "giv.sh"
}

@test "build_diff includes untracked file content" {
    echo "untracked content" >newfile.txt
    run build_diff --current "" false
    assert_success
    assert_output --partial "newfile.txt"
    assert_output --partial "+untracked content"
}

@test "build_history creates expected output" {
    export GIV_DEBUG="true"
    get_project_version() { echo "1.2.3"; }
    run build_history history.txt --cached
    assert_success
    [ -f "history.txt" ]
    run cat history.txt
    assert_output --partial "**Message:**"
    assert_output --partial "Staged Changes"
    assert_output --partial "\`\`\`diff"
    assert_output --partial "**Version:**"

}
