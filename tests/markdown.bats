#!/usr/bin/env bats

# Path to the script under test; adjust as needed
SCRIPT="${BATS_TEST_DIRNAME}/../src/markdown.sh"

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

load "$BATS_TEST_DIRNAME/../src/configuration.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$SCRIPT"

# Create a temp file and print its path
portable_mktemp_file() {
    if command -v mktemp >/dev/null 2>&1; then
        # try both common mktemp syntaxes
        mktemp 2>/dev/null || mktemp -t tmpfile
    else
        t="/tmp/${0##*/}.$$.$(date +%s)"
        : >"$t" && printf '%s\n' "$t" || return 1
    fi
}
setup() {
    # Create a clean temp dir for test artifacts
    TESTDIR="$(mktemp -d)"
    cd "$TESTDIR"
    #   # Copy the script under test into the temp dir
    #   cp "$OLDPWD/${SCRIPT#./}" .
    #   chmod +x md_section.sh
}

teardown() {
    rm -rf "$TESTDIR"
}


# Helper to write a file with given content
write_file() {
    filepath="$1"
    shift
    printf "%s\n" "$@" >"$filepath"
}

@test "portable_mktemp_file creates a file that exists" {
    run portable_mktemp_file
    [ "$status" -eq 0 ]
    # Path should be output
    tmpfile="$output"
    [ -n "$tmpfile" ]
    # File should exist (mktemp or fallback created it)
    [ -e "$tmpfile" ]
    # Cleanup
    rm -f "$tmpfile"
}

@test "normalize_blank_lines collapses duplicates and ensures one blank at EOF" {
    write_file f.md "Line1" "" "" "Line2" "" """Line3"
    normalize_blank_lines f.md
    expected=$(printf "Line1\n\nLine2\n\nLine3\n")
    result="$(cat f.md)"
    [ "$result" = "$expected" ]
}

@test "append mode adds new section at end" {
    write_file orig.md "# Title" "Content line"
    write_file new.md "New A" "New B"

    run manage_section "# Title" orig.md new.md append v1.0.0 '##'
    [ "$status" -eq 0 ]
    tmp="$output"
    content="$(cat "$tmp")"

    # Should end with header + new content
    [[ "$content" == *"## v1.0.0"* ]]
    [[ "$content" == *"New A"* ]]
    [[ "$content" == *"New B"* ]]
}

@test "prepend mode inserts after title even without other headers" {
    write_file orig.md "# Release Notes" "Intro line"
    write_file new.md "Alpha" "Beta"

    run manage_section "# Release Notes" orig.md new.md prepend v2.0 '##'
    assert_success
    tmp="$output"
    content="$(cat "$tmp")"

    # Content order: title, blank, new section, then original intro
    # shellcheck disable=SC3030
    expected_order=("# Release Notes" "" "## v2.0" "" "Alpha")
    # shellcheck disable=SC2068
    # shellcheck disable=SC3054
    for line in ${expected_order[@]}; do
        # shellcheck disable=SC3010
        [[ "$content" =~ $line ]]
    done
}
@test "prepend mode on empty file emits title and section" {
    rm -f orig.md
    write_file new.md "X" "Y"

    run manage_section "# Changelog" orig.md new.md prepend v0.1 '##'
    [ "$status" -eq 0 ]

    tmp="$output"
    run cat "$tmp"
    [ "$status" -eq 0 ]

    assert_output <<EOF
# Changelog

## v0.1

X
Y
EOF
}

@test "update mode replaces existing section content" {
    write_file orig.md \
        "# C" \
        "## v1.0.0" \
        "Old line" \
        "Next line" \
        "## v2.0.0" \
        "Later"
    write_file new.md "New1" "New2"

    run manage_section "# C" orig.md new.md update v1.0.0 '##'
    [ "$status" -eq 0 ]
    tmp="$output"
    content="$(cat "$tmp")"

    # Ensure old block removed and new inserted
    [[ "$content" != *"Old line"* ]]
    [[ "$content" == *"New1"* ]]
    [[ "$content" == *"## v2.0.0"* ]]
}

@test "update falls back to prepend when section missing" {
    write_file orig.md "# T" "## v9.9.9" "Z"
    write_file new.md "AA"

    run manage_section "# T" orig.md new.md update v1.2.3 '##'
    [ "$status" -eq 0 ]

    tmp="$output"
    # <-- read the generated file, not the filename
    content="$(cat "$tmp")"
    # print it for debugging
    printf '%s\n' "$content" >&2

    # Now these will actually test the file contents:
    [[ "$content" =~ "## v1.2.3" ]]
    [[ "$content" =~ "## v9.9.9" ]]
}

@test "update with deeper header level stops at higher-level headings" {
    write_file orig.md \
        "# Top" \
        "## Section" \
        "### Subsection" \
        "Old detail" \
        "## Other"
    write_file new.md "New detail"

    run manage_section "# Top" orig.md new.md update Subsection '###'
    [ "$status" -eq 0 ]
    tmp="$output"
    content="$(cat "$tmp")"

    # Should replace Old detail, keep ## Other
    [[ "$content" == *"### Subsection"* ]]
    [[ "$content" == *"New detail"* ]]
    [[ "$content" == *"## Other"* ]]
    [[ "$content" != *"Old detail"* ]]
}

@test "invalid mode returns non-zero and error message" {
    write_file orig.md "# A"
    write_file new.md "B"

    run manage_section "# A" orig.md new.md badmode v1 '##'
    assert_failure
    assert_output "Invalid mode provided: badmode"
}

@test "exit cleanly when URL is empty" {
    write_file test.md "Line1"
    run append_link test.md "Test" ""
    [ "$status" -eq 0 ]
    # look in $output, not $stderr
    [[ "$output" =~ "URL is empty" ]]
    # file untouched:
    run cat test.md
    assert_output "Line1"
}

@test "append link to non-existent file" {
    rm -f test.md
    run append_link test.md "T" "http://u"
    [ "$status" -eq 0 ]
    # debug now lives in $output
    [[ "$output" =~ "creating" ]]
    run cat test.md
    assert_output <<EOF
[T](http://u)

EOF
}

@test "append link to empty existing file" {
    write_file test.md ""
    run append_link test.md "T" "http://u"
    [ "$status" -eq 0 ]
    run cat test.md
    assert_output <<EOF
[T](http://u)

EOF
}

@test "append link to non-empty file" {
    write_file test.md "A" "B"
    run append_link test.md "T" "http://u"
    [ "$status" -eq 0 ]
    run cat test.md
    assert_output <<EOF
A
B

[T](http://u)

EOF
}

@test "trim multiple blanks before appending" {
    printf "A\n\n\n" >test.md
    run append_link test.md "T" "http://u"
    [ "$status" -eq 0 ]
    run cat test.md
    assert_output <<EOF
A

[T](http://u)

EOF
}

@test "do not duplicate existing link" {
    write_file test.md "X" "[T](http://u)" "Y"
    run append_link test.md "T" "http://u"
    [ "$status" -eq 0 ]
    # again, check $output
    [[ "$output" =~ "Link already exists" ]]
    run cat test.md
    assert_output <<EOF
X
[T](http://u)
Y
EOF
}

@test "non-existent file returns nothing" {
    rm -f file.md
    run extract_section "v1.0.0" file.md
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "section not found returns nothing" {
    write_file file.md \
        "# Title" \
        "" \
        "## v1.0.0" \
        "Content"
    run extract_section "v2.0.0" file.md
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "extract second-level section including header" {
    write_file file.md \
        "# Title" \
        "" \
        "## v1.0.0" \
        "Line1" \
        "Line2" \
        "" \
        "## v0.9.0" \
        "Other"
    run extract_section "v1.0.0" file.md
    [ "$status" -eq 0 ]
    assert_output <<EOF
## v1.0.0
Line1
Line2
EOF
}

@test "extract bracketed section name" {
    write_file file.md \
        "# Title" \
        "" \
        "## [v1.0.0]" \
        "Alpha" \
        "Beta" \
        "" \
        "## v0.9.0" \
        "XYZ"
    run extract_section "v1.0.0" file.md
    [ "$status" -eq 0 ]
    assert_output <<EOF
## [v1.0.0]
Alpha
Beta
EOF
}

@test "extract third-level section stops at next higher" {
    cat >file.md <<'EOF'
# Title

### Subsection
A
B

### Another
C

## Top
D
EOF

    run extract_section "Subsection" file.md "###"
    [ "$status" -eq 0 ]
    assert_output <<EOF
### Subsection
A
B
EOF
}

@test "extract last section at EOF" {
    write_file file.md \
        "# Title" \
        "" \
        "## Final" \
        "Last"
    run extract_section "Final" file.md
    [ "$status" -eq 0 ]
    assert_output <<EOF
## Final
Last
EOF
}

# Test strip_markdown function
@test "strip_markdown removes Markdown formatting" {
    input="This is a **bold** text and this is an *italic* text."
    expected="This is a bold text and this is an italic text."

    result=$(echo "$input" | strip_markdown)

    [ "$result" = "$expected" ]
}

@test "strip_markdown handles empty input" {
    input=""
    expected=""

    result=$(echo "$input" | strip_markdown)

    [ "$result" = "$expected" ]
}

@test "strip_markdown handles complex Markdown" {
    input="# Heading\n\nThis is a **bold** text and this is an *italic* text.\n\n- List item 1\n- List item 2"
    expected="# Heading\n\nThis is a bold text and this is an italic text.\n\n- List item 1\n- List item 2"

    result=$(echo "$input" | strip_markdown)
    output="$result"
    assert_output "$expected"
}

