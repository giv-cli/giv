# Allow test harness to inject mock functions (for bats)
if [ -n "$GIV_TEST_MOCKS" ] && [ -f "$GIV_TEST_MOCKS" ]; then
  . "$GIV_TEST_MOCKS"
fi
#!/bin/sh
# changelog.sh: Generate or update a changelog

# Source initialization script
. "$GIV_LIB_DIR/init.sh"

# Source shared argument parsing for document-related subcommands
. "$GIV_LIB_DIR/document_args.sh"

# Parse arguments specific to changelog
parse_document_args "$@"

revision="$1"
pathspec="$2"
output_file="${output_file:-$changelog_file}"
print_debug "Changelog file: $output_file"

output_version="$GIV_OUTPUT_VERSION"
output_mode="$GIV_OUTPUT_MODE"

# Summarize Git history
summaries_file=$(portable_mktemp "summaries.XXXXXXX") || {
    printf 'Error: cannot create temp file for summaries\n' >&2
    exit 1
}
if ! summarize_target "$revision" "$summaries_file" "$pathspec"; then
    printf 'Error: summarize_target failed\n' >&2
    rm -f "$summaries_file"
    exit 1
fi

# Require non-empty summaries
if [ ! -s "$summaries_file" ]; then
    printf 'Error: No summaries generated for changelog.\n' >&2
    rm -f "$summaries_file"
    exit 1
fi

# Build the AI prompt
prompt_template="${GIV_TEMPLATE_DIR}/changelog_prompt.md"
print_debug "Building prompt from template: $prompt_template"
tmp_prompt_file=$(portable_mktemp "changelog_prompt.XXXXXXX") || {
    printf 'Error: cannot create temp file for prompt\n' >&2
    rm -f "$summaries_file"
    exit 1
}
if ! build_prompt --template "$prompt_template" --summary "$summaries_file" >"$tmp_prompt_file"; then
    printf 'Error: build_prompt failed\n' >&2
    rm -f "$summaries_file" "$tmp_prompt_file"
    exit 1
fi

# Generate AI response
response_file=$(portable_mktemp "changelog_response.XXXXXXX") || {
    printf 'Error: cannot create temp file for AI response\n' >&2
    rm -f "$summaries_file" "$tmp_prompt_file"
    exit 1
}
if ! generate_from_prompt "$tmp_prompt_file" "$response_file" "0.7"; then
    printf 'Error: generate_from_prompt failed\n' >&2
    rm -f "$summaries_file" "$tmp_prompt_file" "$response_file"
    exit 1
fi

# Prepare a working copy of the changelog
tmp_out=$(portable_mktemp "changelog_output.XXXXXXX") || {
    printf 'Error: cannot create temp file for changelog update\n' >&2
    exit 1
}
[ -f "$output_file" ] || : >"$output_file"
cp "$output_file" "$tmp_out"

print_debug "Updating changelog (version=$output_version, mode=$output_mode)"

# Map "auto" → "update" for manage_section
mode_arg=$output_mode
[ "$mode_arg" = auto ] && mode_arg=update

updated=$(manage_section \
    "# Changelog" \
    "$tmp_out" \
    "$response_file" \
    "$mode_arg" \
    "$output_version" \
    "##") || {
    printf 'Error: manage_section failed\n' >&2
    exit 1
}
cat "$updated" >"$tmp_out"
append_link "$tmp_out" "Managed by giv" "https://github.com/giv-cli/giv"

if [ "$GIV_DRY_RUN" = "true" ]; then
    print_debug "Dry run: updated changelog content:"
    cat "$tmp_out"
    return 0
fi

if cat "$tmp_out" >"$output_file"; then
    printf 'Changelog written to %s\n' "$output_file"
else
    printf 'Error: Failed to write %s\n' "$output_file" >&2
    exit 1
fi

print_debug "Changelog generated successfully."
