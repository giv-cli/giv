#!/usr/bin/env bats

# Path to the script under test; adjust as needed
SCRIPT="${BATS_TEST_DIRNAME}/../src/markdown.sh"
HELPERS="${BATS_TEST_DIRNAME}/../src/helpers.sh"

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$HELPERS"
load "$SCRIPT"

# Stub dependencies and source function
setup() {
    # Stub portable_mktemp and normalize_blank_lines
    portable_mktemp() { mktemp; }
    normalize_blank_lines() { cat "$1"; }

    #   # Source the script containing manage_section
    #   [ -f "$SCRIPT" ] || BATS_SKIP="Script under test not found: $SCRIPT"
    #   source "$SCRIPT"
}

teardown() {
    # Clean up any temporary files
    rm -f "$tmp_orig" "$tmp_new" "$tmpfile"
}

# Helper to extract managed output file path
get_tmpfile() {
    # $output from prior run: last line is tmpfile path
    echo "$output" | tail -n1
}

@test "append mode: appends new section to existing file" {
    tmp_orig=$(mktemp)
    cat <<EOF >"$tmp_orig"
Line1
Line2
EOF
    tmp_new=$(mktemp)
    echo "Appended content" >"$tmp_new"

    run manage_section "# Changelog" "$tmp_orig" "$tmp_new" append "NewSection"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run cat "$tmpfile"
    [ "$status" -eq 0 ]
    # original content preserved
    [[ "$output" == *"Line1"* ]]
    [[ "$output" == *"Line2"* ]]
    # new header and content at end
    [[ "$output" == *"## NewSection"* ]]
    [[ "$output" == *"Appended content"* ]]
}

@test "append mode: missing original file behaves like empty" {
    tmp_new=$(mktemp)
    echo "Only content" >"$tmp_new"

    run manage_section "# Changelog" "/nonexistent/file" "$tmp_new" append "OnlySection"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run cat "$tmpfile"
    [ "$status" -eq 0 ]
    # should only contain new section
    [[ "$output" == *"## OnlySection"* ]]
    [[ "$output" == *"Only content"* ]]
}

@test "prepend mode: empty original file inserts title and section" {
    tmp_new=$(mktemp)
    echo "NewLine1" >"$tmp_new"

    run manage_section "# Changelog" "/nonexistent" "$tmp_new" prepend "Intro"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run cat "$tmpfile"
    # should start with title
    [[ "$output" =~ "# Changelog" ]]
    # then new section header
    [[ "$output" =~ "## Intro" ]]
    # then content
    [[ "$output" =~ "NewLine1" ]]
}

@test "prepend mode: existing title, inserts before first same-level header" {
    tmp_orig=$(mktemp)
    cat <<EOF >"$tmp_orig"
# Changelog

## OldSec
Old content
EOF
    tmp_new=$(mktemp)
    echo "Fresh content" >"$tmp_new"

    run manage_section "# Changelog" "$tmp_orig" "$tmp_new" prepend "FreshSec"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run cat "$tmpfile"
    # # Changelog remains at top
    assert_output --regexp "^# Changelog"
    # FreshSec comes before OldSec
    assert_output --regexp "## FreshSec"
    assert_output --regexp "Fresh content"
    # OldSec still present after
    assert_output --regexp "## OldSec"
}

@test "update mode: replaces existing section content" {
    tmp_orig=$(mktemp)
    cat <<EOF >"$tmp_orig"
# Changelog

## SectionA
Old line1
Old line2

## SectionB
B content
EOF
    tmp_new=$(mktemp)
    echo "NewA1" >"$tmp_new"
    echo "NewA2" >>"$tmp_new"

    run manage_section "# Changelog" "$tmp_orig" "$tmp_new" update "SectionA"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run cat "$tmpfile"
    # SectionA content should be replaced
    [[ "$output" == *"## SectionA"* ]]
    [[ "$output" == *"NewA1"* ]]
    [[ "$output" == *"NewA2"* ]]
    # SectionB remains
    [[ "$output" == *"## SectionB"* ]]
    [[ "$output" == *"B content"* ]]
}

@test "update mode: fallback to prepend when section missing" {
    tmp_orig=$(mktemp)
    echo "# Changelog" >"$tmp_orig"
    tmp_new=$(mktemp)
    echo "Fallback content" >"$tmp_new"

    run manage_section "# Changelog" "$tmp_orig" "$tmp_new" update "MissingSec"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run cat "$tmpfile"
    # MissingSec should be prepended
    [[ "$output" =~ "## MissingSec" ]]
    [[ "$output" =~ "Fallback content" ]]
}

@test "invalid mode returns error" {
    tmp_orig=$(mktemp)
    tmp_new=$(mktemp)
    echo "X" >"$tmp_new"

    run manage_section "Title" "$tmp_orig" "$tmp_new" invalid "Sec"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Invalid mode provided" ]]
}

@test "custom header insertion" {
    tmp_orig=$(mktemp)
    echo "# Changelog" >"$tmp_orig"
    tmp_new=$(mktemp)
    echo "Custom content" >"$tmp_new"

    # Using single '#' header instead of default '##'
    run manage_section "# Changelog" "$tmp_orig" "$tmp_new" prepend "CustomHdr" "##"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run cat "$tmpfile"
    assert_output --regexp "^# Changelog"
    # Should use '# CustomHdr'
    assert_output --regexp "## CustomHdr"
    assert_output --partial "Custom content"
}

@test "long new content handled correctly" {
    tmp_orig=$(mktemp)
    echo "# Changelog" >"$tmp_orig"
    tmp_new=$(mktemp)
    # generate 1000 lines
    # shellcheck disable=SC2034
    for i in $(seq 1 1000); do printf "Line %s\n" "$i" >>"$tmp_new"; done

    run manage_section "# Changelog" "$tmp_orig" "$tmp_new" prepend "Bulk"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run wc -l <"$tmpfile"
    cat "$tmpfile" | head
    # Should be original lines + 1 title + blanks + 1 header + blank + 1000 content lines
    expected=$((1 + 1 + 1 + 1 + 1000))
   assert_output "$expected"
}

@test "unexpected formatting: missing blank lines around headers" {
    tmp_orig=$(mktemp)
    # Title and section without blank lines
    cat <<EOF >"$tmp_orig"
# Changelog
## OldSec
Old
EOF
    tmp_new=$(mktemp)
    echo "NewFmt" >"$tmp_new"

    run manage_section "# Changelog" "$tmp_orig" "$tmp_new" prepend "FmtTest"
    [ "$status" -eq 0 ]
    tmpfile=$(get_tmpfile)

    run sed -n '1,5p' "$tmpfile"
    # Check that new section inserted with blank lines
    [[ "$output" =~ "# Changelog" ]]
    [[ "$output" =~ "## FmtTest" ]]
    [[ "$output" =~ "NewFmt" ]]
}
