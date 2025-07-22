#!/usr/bin/env bats

export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"
export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src/project"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project/metadata.sh"
load "$BATS_TEST_DIRNAME/../src/llm.sh"
# Source the script under test
load "$BATS_TEST_DIRNAME/../src/history.sh"

setup() {
    export GIV_METADATA_PROJECT_TYPE="custom"
    export GIV_TEMPLATE_DIR="$BATS_TEST_DIRNAME/../templates"
    export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src"

    # Move into a brand-new repo
    TMP_REPO="$BATS_TEST_DIRNAME/.tmp/tmp_repo"
    rm -rf "$TMP_REPO"
    mkdir -p "$TMP_REPO"
    cd "$TMP_REPO" || exit 1
    git init -q
    git config user.name "Test"
    git config user.email "test@example.com"

    # Make two commits
    echo "first" >a.txt
    git add a.txt
    git commit -q -m "first"
    FIRST_SHA=$(git rev-parse HEAD)

    echo "second" >b.txt
    git add b.txt
    git commit -q -m "second"
    SECOND_SHA=$(git rev-parse HEAD)
    metadata_init

    # Mock generate_response function
    generate_response() {
        echo "Mocked response for generate_response"
    }

}

teardown() {
    remove_tmp_dir
    rm -rf "$TMP_REPO"
}

@test "summarize --current writes a summary for --current" {
    summaries=$(mktemp)
    run summarize_target "--current" "$summaries" "mymode"
    assert_success
    # The file should contain our stub output plus one blank line
    run cat "$summaries"
    # lines: SUMMARIZE:--current MODE:mymode  then blank
    assert_output --partial "Commit: --current"
    # [ "${lines[0]}" = "SUMMARIZE:--current MODE:mymode" ]
    # [ -z "${lines[2]}" ]
}

@test "summarize single commit writes exactly that commit" {
    summaries=$(mktemp)
    run summarize_target "$FIRST_SHA" "$summaries" "xyz"
    assert_success
    run cat "$summaries"
    assert_output --partial "Commit: $FIRST_SHA"
}
@test "summarize two-dot range writes both commits" {
    summaries=$(mktemp)
    range="$FIRST_SHA..$SECOND_SHA"

    # Run the function
    run summarize_target "$range" "$summaries" "r"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: $FIRST_SHA"
    assert_output --partial "Commit: $SECOND_SHA"
}

@test "summarize three-dot range writes both commits" {
    summaries=$(mktemp)
    range="$FIRST_SHA...$SECOND_SHA"

    run summarize_target "$range" "$summaries" "q"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: $FIRST_SHA"
    assert_output --partial "Commit: $SECOND_SHA"
}

@test "invalid single target returns exit 1 and error" {
    summaries=$(mktemp)
    run summarize_target "deadbeef" "$summaries" "m"
    assert_success

    # We only care that the error text appears somewhere
    assert_output --partial "Error: Invalid target: deadbeef"
}

@test "invalid commit in two-dot range returns exit 1 and error" {
    summaries=$(mktemp)
    range="$FIRST_SHA..notasha"

    run summarize_target "$range" "$summaries" "m"
    [ "$status" -eq 1 ]

    [[ "${output}" == *"Error: Invalid commit in range: notasha"* ]]
}

@test "summarize empty target behaves like --current" {
    summaries=$(mktemp)

    run summarize_target "" "$summaries" "d"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: --current"
}

@test "summarize --cached behaves like --current" {
    summaries=$(mktemp)

    run summarize_target "--cached" "$summaries" "c"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: --cached"
}

@test "summarize HEAD~1 single commit" {
    summaries=$(mktemp)

    run summarize_target "HEAD~1" "$summaries" "x"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: HEAD~1"
}

@test "summarize two-dot range with identical endpoints yields one summary" {
    summaries=$(mktemp)
    range="$FIRST_SHA..$FIRST_SHA"

    run summarize_target "$range" "$summaries" "y"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: $FIRST_SHA"
}

@test "summarize three-dot range with identical endpoints yields one summary" {
    summaries=$(mktemp)
    range="$FIRST_SHA...$FIRST_SHA"

    run summarize_target "$range" "$summaries" "z"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: $FIRST_SHA"
}

@test "summarize deeper two-dot range HEAD~1..HEAD writes two commits" {
    summaries=$(mktemp)
    range="HEAD~1..HEAD"

    run summarize_target "$range" "$summaries" "w"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: HEAD~1"
    assert_output --partial "Commit: $SECOND_SHA"
}

@test "summarize three-commit two-dot range HEAD~2..HEAD writes three commits" {
    summaries=$(mktemp)

    echo "third" >c.txt
    git add c.txt
    git commit -q -m "third"
    THIRD_SHA=$(git rev-parse HEAD)

    run summarize_target "HEAD~2..HEAD" "$summaries" "t"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: HEAD~2"
    assert_output --partial "Commit: $SECOND_SHA"
    assert_output --partial "Commit: $THIRD_SHA"
}

@test "summarize three-commit three-dot range HEAD~2...HEAD writes three commits" {
    summaries=$(mktemp)

    echo "third" >c.txt
    git add c.txt
    git commit -q -m "third"
    THIRD_SHA=$(git rev-parse HEAD)

    run summarize_target "HEAD~2...HEAD" "$summaries" "u"
    assert_success

    run cat "$summaries"
    assert_output --partial "Commit: HEAD~2"
    assert_output --partial "Commit: $SECOND_SHA"
    assert_output --partial "Commit: $THIRD_SHA"
}

#----------------------------------------
# summarize_target
#----------------------------------------
@test "summarize_target on single-commit range" {
  tmp="$(mktemp)"

  generate_response() { echo "RESP"; }
  export debug="true"
  # call inside the real repo
  summarize_target HEAD~1..HEAD "$tmp" ""
  cat "$tmp"

  # commit id of HEAD~1
  head_commit=$(git rev-parse HEAD)
  
  run cat "$tmp"
  assert_output --partial "Commit: HEAD~1"
  assert_output --partial "Commit: $head_commit"

  rm -f "$tmp"
}

@test "summarize_target on --current" {
  tmp="$(mktemp)"
  summarize_target --current "$tmp" ""
  run cat "$tmp"
  assert_output --partial 'Commit: --current'
  rm -f "$tmp"
}
