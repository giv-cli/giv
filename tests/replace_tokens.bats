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
    unset GIV_TOKEN_FOO GIV_TOKEN_A GIV_TOKEN_B GIV_TOKEN_C \
        GIV_TOKEN_X GIV_TOKEN_T
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

@test "no GIV_TOKEN_* set leaves text unchanged" {
  write_file input.md "Hello [FOO]"
  run replace_tokens < input.md
  assert_success
  assert_output "Hello [FOO]"
}

@test "single token replacement from env" {
  export GIV_TOKEN_FOO=World
  write_file input.md "Hello [FOO]!"
  run replace_tokens < input.md
  assert_success
  assert_output "Hello World!"
}

@test "multiple tokens replacement" {
  export GIV_TOKEN_A=1
  export GIV_TOKEN_B=2
  export GIV_TOKEN_C=3
  write_file input.md "[A] plus [B] equals [C]"
  run replace_tokens < input.md
  assert_success
  assert_output "1 plus 2 equals 3"
}

@test "unknown tokens remain unchanged" {
  export GIV_TOKEN_X=foo
  write_file input.md "[X] and [Y]"
  run replace_tokens < input.md
  assert_success
  assert_output "foo and [Y]"
}

@test "all occurrences of a token replaced" {
  export GIV_TOKEN_T=test
  write_file input.md "[T] and again [T]!"
  run replace_tokens < input.md
  assert_success
  assert_output "test and again test!"
}

@test "tokens next to punctuation" {
  export GIV_TOKEN_BAR=baz
  write_file input.md "Start[BAR], mid [BAR]? end"
  run replace_tokens < input.md
  assert_success
  assert_output "Startbaz, mid baz? end"
}

@test "multiline replacement value" {
  # Bats uses bash, so we can embed newlines with $'…'
  export GIV_TOKEN_FOO=$'Line1\nLine2'
  write_file input.md "[FOO]"
  run replace_tokens < input.md
  assert_success
  assert_output <<EOF
Line1
Line2
EOF
}

@test "replacement value containing quotes" {
  export GIV_TOKEN_FOO='He said "Hello"'
  write_file input.md "[FOO]"
  run replace_tokens < input.md
  assert_success
  assert_output 'He said "Hello"'
}

@test "empty input yields empty output" {
  write_file input.md ""
  export GIV_TOKEN_FOO=bar
  run replace_tokens < input.md
  assert_success
  assert_output ""
}