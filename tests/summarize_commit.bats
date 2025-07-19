#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$BATS_TEST_DIRNAME/../src/config.sh"
. "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project.sh"

setup() {
    export GIV_TEMPLATE_DIR="$BATS_TEST_DIRNAME/../templates"

    TMP_REPO="$BATS_TEST_DIRNAME/.tmp/tmp_repo"
    rm -rf "$TMP_REPO"
    mkdir -p "$TMP_REPO"
    cd "$TMP_REPO" || exit 1
    git init -q
    git config user.name "Test"
    git config user.email "test@example.com"

    echo "first" >a.txt
    git add a.txt
    git commit -q -m "first"
    FIRST_SHA=$(git rev-parse HEAD)

    echo "second" >b.txt
    git add b.txt
    git commit -q -m "second"

    . "$BATS_TEST_DIRNAME/../src/history.sh"
}

teardown() {
    rm -rf "$TMP_REPO"
}

@test "summarize_commit caches and returns summary" {
    summary_cache="$GIV_HOME/cache/${FIRST_SHA}-summary.md"
    rm -f "$summary_cache"

    run summarize_commit "$FIRST_SHA"
    [ "$status" -eq 0 ]

    [ -f "$summary_cache" ]
    run cat "$summary_cache"
    [ "$status" -eq 0 ]
}

@test "summarize_commit handles missing templates" {
    export GIV_TEMPLATE_DIR="/nonexistent"
    export GIV_DEBUG="true"
    run summarize_commit "$FIRST_SHA"
    assert_failure
    assert_output "Error: Template not found"
}
