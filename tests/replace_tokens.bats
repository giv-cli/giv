#!/usr/bin/env bats

mkdir -p "$BATS_TEST_DIRNAME/.logs"
export ERROR_LOG="$BATS_TEST_DIRNAME/.logs/error.log"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

SCRIPT="$BATS_TEST_DIRNAME/../src/helpers.sh"

load "$SCRIPT"
setup() {
    TMPDIR_REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
    cd "$TMPDIR_REPO"
    rm -f input.md
}

teardown() {
    rm -f input.md
    if [ -n "$TMPDIR_REPO" ]; then
        rm -rf "$TMPDIR_REPO"
    fi
}
write_file() {
    filepath="$1"
    shift
    printf "%s\n" "$@" >"$filepath"
}

@test "no arguments leaves text unchanged" {
    write_file input.md "Hello [FOO]"
    run replace_tokens <input.md
    assert_success
    assert_output "Hello [FOO]"
}

@test "single token replacement" {
    write_file input.md "Hello [FOO]!"
    run replace_tokens FOO=World <input.md
    assert_success
    assert_output "Hello World!"
}

@test "multiple tokens replacement" {
    write_file input.md "[A] plus [B] equals [C]"
    run replace_tokens A=1 B=2 C=3 <input.md
    assert_success
    assert_output "1 plus 2 equals 3"
}

@test "unknown tokens remain unchanged" {
    write_file input.md "[X] and [Y]"
    run replace_tokens X=foo <input.md
    assert_success
    assert_output "foo and [Y]"
}

@test "all occurrences replaced" {
    write_file input.md "[T] and again [T]!"
    run replace_tokens T=test <input.md
    assert_success
    assert_output "test and again test!"
}

@test "punctuation adjacent to tokens" {
    write_file input.md "Start[BAR], mid [BAR]? end"
    run replace_tokens BAR=baz <input.md
    assert_success
    assert_output "Startbaz, mid baz? end"
}

@test "multiline replacement value" {
    write_file input.md "[FOO]"
    # Bats uses bash, so $'…' works for embedded newline
    multiline=$'Line1\nLine2'
    run replace_tokens FOO="$multiline" <input.md
    assert_success
    assert_output <<EOF
Line1
Line2
EOF
}

@test "replacement value containing quotes" {
    write_file input.md "[FOO]"
    run replace_tokens FOO='He said "Hello"' <input.md
    assert_success
    assert_output 'He said "Hello"'
}

@test "empty input yields empty output" {
    write_file input.md ""
    run replace_tokens FOO=bar <input.md
    assert_success
    assert_output ""
}
