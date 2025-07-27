#!/usr/bin/env bats

load './helpers/setup.sh'
load "${GIV_LIB_DIR}/system.sh"
load "${GIV_LIB_DIR}/project_metadata.sh"
load "${GIV_LIB_DIR}/llm.sh"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'


setup() {
    export GIV_DEBUG="true"
    mkdir -p "$GIV_TMP_DIR"
    TMPDIR_REPO="$(mktemp -d -p "$GIV_TMP_DIR")"
    cd "$TMPDIR_REPO" || exit 1
    rm -f input.md

    rm -f template.md diff.txt
    unset GIV_TOKEN_FOO GIV_TOKEN_A GIV_TOKEN_B GIV_TOKEN_C \
        GIV_TOKEN_X GIV_TOKEN_T
}

teardown() {
    rm -f input.md

    rm -f template.md diff.txt
    if [ -n "$TMPDIR_REPO" ]; then
        rm -rf "$TMPDIR_REPO"
    fi
}
write_file() {
    filepath="$1"
    shift
    printf "%s\n" "$@" >"$filepath"
}

@test "no GIV_TOKEN_* set leaves text unchanged" {
    write_file input.md "Hello [FOO]"
    run replace_tokens <input.md
    assert_success
    assert_output "Hello [FOO]"
}

@test "single token replacement from env" {
    export GIV_TOKEN_FOO=World
    write_file input.md "Hello [FOO]!"
    run replace_tokens <input.md
    assert_success
    assert_output "Hello World!"
}

@test "multiple tokens replacement" {
    export GIV_TOKEN_A=1
    export GIV_TOKEN_B=2
    export GIV_TOKEN_C=3
    write_file input.md "[A] plus [B] equals [C]"
    run replace_tokens <input.md
    assert_success
    assert_output "1 plus 2 equals 3"
}

@test "unknown tokens remain unchanged" {
    export GIV_TOKEN_X=foo
    write_file input.md "[X] and [Y]"
    run replace_tokens <input.md
    assert_success
    assert_output "foo and [Y]"
}

@test "all occurrences of a token replaced" {
    export GIV_TOKEN_T=test
    write_file input.md "[T] and again [T]!"
    run replace_tokens <input.md
    assert_success
    assert_output "test and again test!"
}

@test "tokens next to punctuation" {
    export GIV_TOKEN_BAR=baz
    write_file input.md "Start[BAR], mid [BAR]? end"
    run replace_tokens <input.md
    assert_success
    assert_output "Startbaz, mid baz? end"
}

@test "multiline replacement value" {
    # Bats uses bash, so we can embed newlines with $'…'
    export GIV_TOKEN_FOO=$'Line1\nLine2'
    write_file input.md "[FOO]"
    run replace_tokens <input.md
    assert_success
    assert_output <<EOF
Line1
Line2
EOF
}

@test "replacement value containing quotes" {
    export GIV_TOKEN_FOO='He said "Hello"'
    write_file input.md "[FOO]"
    run replace_tokens <input.md
    assert_success
    assert_output 'He said "Hello"'
}

@test "empty input yields empty output" {
    write_file input.md ""
    export GIV_TOKEN_FOO=bar
    run replace_tokens <input.md
    assert_success
    assert_output ""
}

@test "build_prompt fails if template missing" {
    export GIV_DEBUG="false"
    run build_prompt --template missing.md --summary diff.txt
    [ "$status" -ne 0 ]
    assert_output "template file not found: missing.md"
}

@test "build_prompt fails if diff missing" {
    write_file template.md "Hello"
    export GIV_DEBUG="false"
    run build_prompt --template template.md --summary missing.txt
    [ "$status" -ne 0 ]
    assert_output "diff file not found: missing.txt"
}

@test "build_prompt injects summary into prompt" {
    write_file template.md \
        "Summary:" \
        "[SUMMARY]" \
        "Done."
    write_file diff.txt \
        "Line A" \
        "Line B"

    export GIV_DEBUG="false"
    run build_prompt --template template.md --summary diff.txt
    assert_success
    assert_output <<EOF
Summary:
Line A
Line B

Done.

Output just the final content—no extra commentary or code fencing. Use only information contained in this prompt and the summaries provided above.
EOF
}

@test "build_prompt replaces all optional tokens" {
    write_file template.md \
        "Project: [PROJECT_TITLE]" \
        "Version: [VERSION]" \
        "" \
        "Summary->" \
        "[SUMMARY]" \
        "" \
        "Example: [EXAMPLE]" \
        "" \
        "Rules:" \
        "[RULES]" \
        ""
    write_file diff.txt "the diff here"

    example="echo Hello"
    rules=$'1. First rule\n2. Second rule'
    export GIV_DEBUG="false"
    run build_prompt \
        --project-title "MyApp" \
        --version "2.3.4" \
        --example "$example" \
        --rules "$rules" \
        --template template.md \
        --summary diff.txt

    assert_success
    assert_output <<EOF
Project: MyApp
Version: 2.3.4

Summary->
the diff here


Example: echo Hello

Rules:
1. First rule
2. Second rule


Output just the final content—no extra commentary or code fencing. Use only information contained in this prompt and the summaries provided above.
EOF
}
