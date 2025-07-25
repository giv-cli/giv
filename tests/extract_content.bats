#!/usr/bin/env bats
load './helpers/setup.sh'
load "${GIV_LIB_DIR}/system.sh"
load "${GIV_LIB_DIR}/llm.sh"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'


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
