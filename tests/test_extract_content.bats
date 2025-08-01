#!/usr/bin/env bats
export TMPDIR="/tmp"
mkdir -p "$BATS_TEST_DIRNAME/.logs"
export ERROR_LOG="$BATS_TEST_DIRNAME/.logs/error.log"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

SCRIPT="$BATS_TEST_DIRNAME/../src/llm.sh"

export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"
setup() {
    # adjust the path as needed
    load "$SCRIPT"
}

@test "extracts simple single-line content" {
    json='{"message":{"content":"Hello World"}}'
    run extract_content_from_response "$json"
    [ "$status" -eq 0 ]
    [ "$output" = "Hello World" ]
}

@test "extracts multi-line content with \\n escapes" {
    json='{"message":{"content":"Line1\nLine2\nLine3"}}'
    run extract_content_from_response "$json"
    [ "$status" -eq 0 ]
    expected=$'Line1\nLine2\nLine3'
    [ "$output" = "$expected" ]
}

@test "extracts content containing escaped quotes" {
    json='{"message":{"content":"He said: \"Hi there\""}}'
    run extract_content_from_response "$json"
    assert_success
    assert_output 'He said: "Hi there"'
}

@test "extracts content with backslashes" {
    json='{"message":{"content":"Path C:\\Windows\\System32"}}'
    run extract_content_from_response "$json"
    assert_success
    assert_output 'Path C:\Windows\System32'
}

@test "returns empty string when content key is missing" {
    json='{"foo":"bar"}'
    run extract_content_from_response "$json"
    assert_success
    [ -z "$output" ]
}

@test "extracts content when other keys present" {
    json='{"choices":[{"foo":123,"message":{"content":"# Announcement\nUpdate complete."},"other":true}]}'
    run extract_content_from_response "$json"
    assert_success
    expected=$'# Announcement\nUpdate complete.'
    assert_output "$expected"
}

@test "extracts content from example_response.json file" {
    json=$(cat "$BATS_TEST_DIRNAME/assets/example_response.json")
    tmp_output=$(mktemp)
    response="$(extract_content_from_response "${json}")"
    echo $response >"$tmp_output"
    output=$(cat "$tmp_output")
    [ -n "$output" ]
    assert_output --partial '### Announcement: Version 0.2.0'
    assert_output --partial 'We are pleased to announce the release of **Version 0.2.0** of our project.'
}
