#!/usr/bin/env bats
export TMPDIR="/tmp"
# Path to the script under test; adjust as needed
SCRIPT="${BATS_TEST_DIRNAME}/../src/markdown.sh"

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$SCRIPT"
export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"



# # Create a temp file and print its path
# portable_mktemp_file() {
#     if command -v mktemp >/dev/null 2>&1; then
#         # try both common mktemp syntaxes
#         mktemp 2>/dev/null || mktemp -t tmpfile
#     else
#         t="/tmp/${0##*/}.$$.$(date +%s)"
#         : >"$t" && printf '%s\n' "$t" || return 1
#     fi
# }
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
    assert_success
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
    assert_success

    tmp="$output"
    run cat "$tmp"
    assert_success

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
    assert_success
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
    assert_success

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
    assert_success
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
    assert_success
    # look in $output, not $stderr
    [[ "$output" =~ "URL is empty" ]]
    # file untouched:
    run cat test.md
    assert_output "Line1"
}

@test "append link to non-existent file" {
    rm -f test.md
    run append_link test.md "T" "http://u"
    assert_success
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
    assert_success
    run cat test.md
    assert_output <<EOF
[T](http://u)

EOF
}

@test "append link to non-empty file" {
    write_file test.md "A" "B"
    run append_link test.md "T" "http://u"
    assert_success
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
    assert_success
    run cat test.md
    assert_output <<EOF
A

[T](http://u)

EOF
}

@test "do not duplicate existing link" {
    write_file test.md "X" "[T](http://u)" "Y"
    run append_link test.md "T" "http://u"
    assert_success
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
    assert_success
    [ -z "$output" ]
}

@test "section not found returns nothing" {
    write_file file.md \
        "# Title" \
        "" \
        "## v1.0.0" \
        "Content"
    run extract_section "v2.0.0" file.md
    assert_success
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
    assert_success
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
    assert_success
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
    assert_success
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
    assert_success
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
    expected="Heading\n\nThis is a bold text and this is an italic text.\n\n- List item 1\n- List item 2"

    result=$(echo "$input" | strip_markdown)
    output="$result"
    assert_output "$expected"
}

# Test remove_top_level_header
@test "remove_top_level_header removes top-level header" {
    write_file test.md "# Header
Content"
    run remove_top_level_header test.md
    assert_success
    run cat test.md
    assert_output "Content"
}

@test "remove_top_level_header does nothing if no header" {
    write_file test.md "Content"
    run remove_top_level_header test.md
    assert_success
    result=$(cat test.md)
    [ "$result" = "Content" ]
}

# Test strip_code_fences
@test "strip_code_fences removes code fences" {
    write_file test.md "\`\`\`Code\`\`\`"
    run strip_code_fences test.md
    assert_success
    run cat test.md
    assert_output "Code"
}

@test "strip_code_fences does nothing if no code fences" {
    write_file test.md "Code"
    run strip_code_fences test.md
    assert_success
    result=$(cat test.md)
    [ "$result" = "Code" ]
}

# Test enforce_final_newline
@test "enforce_final_newline adds missing newline" {
    write_file test.md "Content"
    run enforce_final_newline test.md
    assert_success

    # Check if the last line is a newline
    [ -z "$(tail -n 1 test.md)" ]

    # result=$(tail -n 10 test.md)
    # printf "%s" "$result"   
    # printf 'newline\n' 
    # # Check if the last line is a newline
    # [ "$result" = "Content\n" ] 
}

@test "enforce_final_newline does nothing if newline exists" {
    write_file test.md "Content
    "
    run enforce_final_newline test.md
    assert_success
    
    run tail -n 3 test.md
    assert_output "Content
    "
}



# # Test post_process_document
# @test "post_process_document applies all steps" {
#     write_file test.md "# Header

# ```
# Code
# ```
# Content"
#     run post_process_document test.md
#     assert_success
#     result=$(cat test.md)
#     [ "$result" = "Content\n" ]
# }

# # Test is_glow_installed
# @test "is_glow_installed returns true if glow is installed" {
#     mock_command glow
#     is_glow_installed
#     assert_success
# }

# @test "is_glow_installed returns false if glow is not installed" {
#     unmock_command glow
#     is_glow_installed
#     assert_failure
# }

# # Test install_pkg
# @test "install_pkg tries package managers" {
#     mock_command brew
#     mock_command pacman
#     mock_command snap
#     install_pkg
#     assert_success
# }

# # Test install_from_github
# @test "install_from_github succeeds with valid inputs" {
#     mock_command curl
#     mock_command tar
#     install_from_github
#     assert_success
# }

# # Test ensure_glow
# @test "ensure_glow installs glow if not installed" {
#     unmock_command glow
#     ensure_glow
#     assert_success
# }

# # Test print_md_file
# @test "print_md_file prints existing file" {
#     write_file test.md "Content"
#     print_md_file test.md
#     assert_output <<EOF
# Content
# EOF
# }

# @test "print_md_file fails for non-existent file" {
#     rm -f test.md
#     print_md_file test.md
#     assert_failure
# }

# # Test print_md
# @test "print_md uses glow if installed" {
#     mock_command glow
#     print_md
#     assert_success
# }

# @test "print_md falls back to strip_markdown if glow not installed" {
#     unmock_command glow
#     print_md
#     assert_success
# }

