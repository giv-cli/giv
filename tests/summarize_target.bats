#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"

export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
setup() {
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

    # Source the script under test
    # Adjust this path if your script lives elsewhere
    source "${BATS_TEST_DIRNAME}/../src/history.sh"

    # Stub out summarize_commit to record its inputs
    summarize_commit() {
        # print a predictable line for each commit
        printf 'SUMMARIZE:%s MODE:%s\n' "$1" "$2"
    }

    # Stub portable_mktemp to use mktemp in the repo
    portable_mktemp() {
        mktemp
    }

    # Enable debug so we can see logging if a test fails
    debug=1
    GIV_TMPDIR_SAVE=
}

teardown() {
    remove_tmp_dir
    rm -rf "$TMP_REPO"
}

@test "summarize --current writes a summary for --current" {
    summaries=$(mktemp)
    run summarize_target "--current" "$summaries" "mymode"
    [ "$status" -eq 0 ]
    # The file should contain our stub output plus one blank line
    run cat "$summaries"
    # lines: SUMMARIZE:--current MODE:mymode  then blank
    [ "${lines[0]}" = "SUMMARIZE:--current MODE:mymode" ]
    [ -z "${lines[2]}" ]
}

@test "summarize single commit writes exactly that commit" {
    summaries=$(mktemp)
    run summarize_target "$FIRST_SHA" "$summaries" "xyz"
    [ "$status" -eq 0 ]
    run cat "$summaries"
    [ "${lines[0]}" = "SUMMARIZE:$FIRST_SHA MODE:xyz" ]
    [ -z "${lines[2]}" ]
}
@test "summarize two-dot range writes both commits" {
    summaries=$(mktemp)
    range="$FIRST_SHA..$SECOND_SHA"

    # Run the function
    run summarize_target "$range" "$summaries" "r"
    [ "$status" -eq 0 ]

    # Capture only non-blank lines
    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]

    # Bats populates `lines[]` from stdout of the last run,
    # so now lines[0] is first summary, lines[1] is second summary
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "SUMMARIZE:$FIRST_SHA MODE:r" ]
    [ "${lines[1]}" = "SUMMARIZE:$SECOND_SHA MODE:r" ]
}

@test "summarize three-dot range writes both commits" {
    summaries=$(mktemp)
    range="$FIRST_SHA...$SECOND_SHA"

    run summarize_target "$range" "$summaries" "q"
    [ "$status" -eq 0 ]

    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]

    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "SUMMARIZE:$FIRST_SHA MODE:q" ]
    [ "${lines[1]}" = "SUMMARIZE:$SECOND_SHA MODE:q" ]
}

@test "invalid single target returns exit 1 and error" {
    summaries=$(mktemp)

    run summarize_target "deadbeef" "$summaries" "m"
    [ "$status" -eq 1 ]

    # We only care that the error text appears somewhere
    [[ "${output}" == *"Error: Invalid target: deadbeef"* ]]
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
    [ "$status" -eq 0 ]

    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "${lines[0]}" = "SUMMARIZE: MODE:d" ]
}

@test "summarize --cached behaves like --current" {
    summaries=$(mktemp)

    run summarize_target "--cached" "$summaries" "c"
    [ "$status" -eq 0 ]

    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "${lines[0]}" = "SUMMARIZE:--cached MODE:c" ]
}

@test "summarize HEAD~1 single commit" {
    summaries=$(mktemp)

    # HEAD~1 should point to FIRST_SHA
    run summarize_target "HEAD~1" "$summaries" "x"
    [ "$status" -eq 0 ]

    run grep -v '^$' "$summaries"
    printf '%s\n' "$output"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "SUMMARIZE:HEAD~1 MODE:x" ]
}

@test "summarize two-dot range with identical endpoints yields one summary" {
    summaries=$(mktemp)
    range="$FIRST_SHA..$FIRST_SHA"

    run summarize_target "$range" "$summaries" "y"
    [ "$status" -eq 0 ]

    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]
    # Only one summary, since range A..A only yields A
    [ "${#lines[@]}" -eq 1 ]
    [ "${lines[0]}" = "SUMMARIZE:$FIRST_SHA MODE:y" ]
}

@test "summarize three-dot range with identical endpoints yields one summary" {
    summaries=$(mktemp)
    range="$FIRST_SHA...$FIRST_SHA"

    run summarize_target "$range" "$summaries" "z"
    [ "$status" -eq 0 ]

    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "${lines[0]}" = "SUMMARIZE:$FIRST_SHA MODE:z" ]
}

@test "summarize deeper two-dot range HEAD~1..HEAD writes two commits" {
    summaries=$(mktemp)
    range="HEAD~1..HEAD"

    run summarize_target "$range" "$summaries" "w"
    [ "$status" -eq 0 ]

    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]
    # Expect first commit (FIRST_SHA) then HEAD (SECOND_SHA)
    [ "${#lines[@]}" -eq 2 ]
    [ "${lines[0]}" = "SUMMARIZE:HEAD~1 MODE:w" ]

    HEAD_ID=$(git rev-parse HEAD)
    [ "${lines[1]}" = "SUMMARIZE:$HEAD_ID MODE:w" ]
}

@test "summarize three-commit two-dot range HEAD~2..HEAD writes three commits" {
    summaries=$(mktemp)

    # Create a third commit
    echo "third" >c.txt
    git add c.txt
    git commit -q -m "third"
    THIRD_SHA=$(git rev-parse HEAD)

    # Range from HEAD~2 (which is FIRST_SHA) through HEAD (THIRD_SHA)
    run summarize_target "HEAD~2..HEAD" "$summaries" "t"
    [ "$status" -eq 0 ]

    # Filter out blank lines
    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]

    SECOND_SHA=$(git rev-parse HEAD~1)
    # Expect summaries for FIRST_SHA, SECOND_SHA, THIRD_SHA in that order
    [ "${#lines[@]}" -eq 3 ]
    [ "${lines[0]}" = "SUMMARIZE:HEAD~2 MODE:t" ]
    [ "${lines[1]}" = "SUMMARIZE:$SECOND_SHA MODE:t" ]
    [ "${lines[2]}" = "SUMMARIZE:$THIRD_SHA MODE:t" ]
}

@test "summarize three-commit three-dot range HEAD~2...HEAD writes three commits" {
    summaries=$(mktemp)

    # Create a third commit
    echo "third" >c.txt
    git add c.txt
    git commit -q -m "third"
    THIRD_SHA=$(git rev-parse HEAD)

    # Symmetric-diff range from HEAD~2 through HEAD
    run summarize_target "HEAD~2...HEAD" "$summaries" "u"
    [ "$status" -eq 0 ]

    run grep -v '^$' "$summaries"
    [ "$status" -eq 0 ]

    # We prepend the left endpoint (FIRST_SHA) then the symmetric-diff commits (SECOND_SHA, THIRD_SHA)
    [ "${#lines[@]}" -eq 3 ]
    [ "${lines[0]}" = "SUMMARIZE:HEAD~2 MODE:u" ]
    [ "${lines[1]}" = "SUMMARIZE:$SECOND_SHA MODE:u" ]
    [ "${lines[2]}" = "SUMMARIZE:$THIRD_SHA MODE:u" ]
}
