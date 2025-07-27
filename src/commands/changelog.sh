#!/bin/sh
# changelog.sh: Generate or update a changelog

# Load initialization and shared functions
. "$GIV_LIB_DIR/init.sh"

# Allow test harness to inject mock functions (for bats)
if [ -n "${GIV_TEST_MOCKS:-}" ] && [ -f "${GIV_TEST_MOCKS:-}" ]; then
  . "$GIV_TEST_MOCKS"
fi

# Arguments are already parsed by the unified parser
# All environment variables are set by parse_arguments in giv.sh

revision="$GIV_REVISION"
pathspec="$GIV_PATHSPEC"
output_file="${output_file:-$changelog_file}"
print_debug "Changelog file: $output_file"

output_version="$GIV_OUTPUT_VERSION"
output_mode="$GIV_OUTPUT_MODE"

# Use current version as default if not specified
if [ -z "$output_version" ]; then
    output_version=$(get_metadata_value "version" "HEAD" 2>/dev/null || echo "Unreleased")
fi

# Set defaults for revision and pathspec if not provided
GIV_REVISION="${GIV_REVISION:---current}"
GIV_PATHSPEC="${GIV_PATHSPEC:-}"
export GIV_REVISION
export GIV_PATHSPEC

# Parse arguments for the changelog subcommand
parse_changelog_arguments() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --revision)
                shift
                export GIV_REVISION="$1"
                ;;
            --pathspec)
                shift
                export GIV_PATHSPEC="$1"
                ;;
            --output-file)
                shift
                export GIV_OUTPUT_FILE="$1"
                ;;
            --output-version)
                shift
                export GIV_OUTPUT_VERSION="$1"
                ;;
            --*)
                echo "Error: Unknown option '$1' for changelog subcommand." >&2
                return 1
                ;;
            *)
                # First non-option argument is the revision
                if [ -z "${GIV_REVISION_SET:-}" ]; then
                    export GIV_REVISION="$1"
                    export GIV_REVISION_SET="true"
                else
                    echo "Error: Unknown positional argument '$1' for changelog subcommand." >&2
                    return 1
                fi
                ;;
        esac
        shift
    done

    return 0
}

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
