# -------------------------------------------------------------------
# Dependencies:
#
# This script relies on several external commands and utilities. 
# Ensure they are installed and available in your PATH.
#
# - portable_mktemp: Create temporary files securely
# - append_link: Custom script to append a link to the output file
# - manage_section: Custom script to manage sections in the changelog
# - summarize_target: Custom script to summarize Git history for a given revision
# - build_prompt: Custom script to build AI prompts from templates and summaries
# - generate_from_prompt: Custom script to generate content from AI prompts
# - get_project_title: Custom script to extract project title from summaries
# - find_version_file: Custom script to locate the version file in the repository
# - get_version_info: Custom script to retrieve version information from the version file
#
# -------------------------------------------------------------------

# # -------------------------------------------------------------------
# # Subcommand Implementations
# # -------------------------------------------------------------------

show_version() {
    printf '%s\n' "${__VERSION}"
}
# Show all available release tags
get_available_releases() {
    curl -s https://api.github.com/repos/giv-cli/giv/releases | awk -F'"' '/"tag_name":/ {print $4}'
    exit 0
}
# Update the script to a specific release version (or latest if not specified)
run_update() {
    version="${1:-latest}"
    if [ "${version}" = "latest" ]; then
        latest_version=$(get_available_releases | head -n 1)
        printf 'Updating giv to version %s...\n' "${latest_version}"
        curl -fsSL https://raw.githubusercontent.com/giv-cli/giv/main/install.sh | sh -- --version "${latest_version}"
    else
        printf 'Updating giv to version %s...\n' "${version}"
        curl -fsSL "https://raw.githubusercontent.com/giv-cli/giv/main/install.sh" | sh -- --version "${version}"
    fi
    printf 'Update complete.\n'
    exit 0
}

cmd_message() {
    commit_id="${1:-}"
    pathspec="${2:-$GIV_PATHSPEC}" # New argument for PATHSPEC
    todo_pattern="${3:-$GIV_TODO_PATTERN}" # New argument for todo_pattern
    model_mode="${4:-}" # New argument for model_mode

    if [ -z "${commit_id}" ]; then
        commit_id="--current"
    fi

    print_debug "Generating commit message for ${commit_id}"

    # Handle both --current and --cached (see argument parsing section for details).
    if [ "${commit_id}" = "--current" ] || [ "${commit_id}" = "--cached" ]; then
        hist=$(portable_mktemp "commit_history_XXXXXX.md")
        build_history "${hist}" "${commit_id}" "${todo_pattern}" "${pathspec}"
        print_debug "Generated history file ${hist}"
        pr=$(portable_mktemp "commit_message_prompt_XXXXXX.md")
        build_prompt --template "${GIV_TEMPLATE_DIR}/message_prompt.md" \
            --summary "${hist}" >"${pr}"
        print_debug "Generated prompt file ${pr}"
        res=$(generate_response "${pr}" "${model_mode}" "0.9" "32768")        
        if [ $? -ne 0 ]; then
            printf 'Error: Failed to generate AI response.\n' >&2
            exit 1
        fi
        printf '%s\n' "${res}"
        return
    fi

    # Detect exactly two- or three-dot ranges (A..B or A...B)
    if echo "${commit_id}" | grep -qE '\.\.\.?'; then
        print_debug "Detected commit range syntax: ${commit_id}"

        # Confirm Git accepts it as a valid range
        if ! git rev-list "${commit_id}" >/dev/null 2>&1; then
            print_error "Invalid commit range: ${commit_id}"
            exit 1
        fi

        # Use symmetric-difference for three-dot, exclusion for two-dot
        case "${commit_id}" in
        *...*)
            print_debug "Processing three-dot range: ${commit_id}"
            git --no-pager log --pretty=%B --left-right "${commit_id}" | sed '${/^$/d;}'
            ;;
        *..*)
            print_debug "Processing two-dot range: ${commit_id}"
            git --no-pager log --reverse --pretty=%B "${commit_id}" | sed '${/^$/d;}'
            ;;
        *) ;;
        esac
        return
    fi

    print_debug "Processing single commit: ${commit_id}"
    if ! git rev-parse --verify "${commit_id}" >/dev/null 2>&1; then
        printf 'Error: Invalid commit ID: %s\n' "${commit_id}" >&2
        exit 1
    fi
    git --no-pager log -1 --pretty=%B "${commit_id}" | sed '${/^$/d;}'
    return
}


# -------------------------------------------------------------------
# cmd_changelog: generate or update CHANGELOG.md from Git history
# -------------------------------------------------------------------
cmd_changelog() {
    revision="$1"
    pathspec="$2"
    output_file="${output_file:-$changelog_file}"
    print_debug "Changelog file: $output_file"

    output_version="$GIV_OUTPUT_VERSION"
    output_mode="$GIV_OUTPUT_MODE"

    # 2) Summarize Git history
    summaries_file=$(portable_mktemp "summaries.XXXXXXX.md") || {
        printf 'Error: cannot create temp file for summaries\n' >&2
        exit 1
    }
    if ! summarize_target "$revision" "$summaries_file" "$pathspec" "$GIV_MODEL_MODE"; then
        printf 'Error: summarize_target failed\n' >&2
        rm -f "$summaries_file"
        exit 1
    fi

    # 3) Require non-empty summaries
    if [ ! -s "$summaries_file" ]; then
        printf 'Error: No summaries generated for changelog.\n' >&2
        rm -f "$summaries_file"
        exit 1
    fi

    # 4) Build the AI prompt
    prompt_template="${GIV_TEMPLATE_DIR}/changelog_prompt.md"
    print_debug "Building prompt from template: $prompt_template"
    tmp_prompt_file=$(portable_mktemp "changelog_prompt.XXXXXXX.md") || {
        printf 'Error: cannot create temp file for prompt\n' >&2
        rm -f "$summaries_file"
        exit 1
    }
    if ! build_prompt --template "$prompt_template" --summary "$summaries_file" >"$tmp_prompt_file"; then
        printf 'Error: build_prompt failed\n' >&2
        rm -f "$summaries_file" "$tmp_prompt_file"
        exit 1
    fi

    # 5) Generate AI response
    response_file=$(portable_mktemp "changelog_response.XXXXXXX.md") || {
        printf 'Error: cannot create temp file for AI response\n' >&2
        rm -f "$summaries_file" "$tmp_prompt_file"
        exit 1
    }
    if ! generate_from_prompt "$tmp_prompt_file" "$response_file" \
            "$GIV_MODEL_MODE" "0.7"; then
        printf 'Error: generate_from_prompt failed\n' >&2
        rm -f "$summaries_file" "$tmp_prompt_file" "$response_file"
        exit 1
    fi

    # 6) Prepare a working copy of the changelog
    tmp_out=$(portable_mktemp "changelog_output.XXXXXXX.md") || {
        printf 'Error: cannot create temp file for changelog update\n' >&2
        exit 1
    }
    # ensure the file exists so cp won't fail
    [ -f "$output_file" ] || : >"$output_file"
    cp "$output_file" "$tmp_out"

    print_debug "Updating changelog (version=$output_version, mode=$output_mode)"

    # 7) Map "auto" → "update" for manage_section
    mode_arg=$output_mode
    [ "$mode_arg" = auto ] && mode_arg=update

    # call our helper; it returns the path to the new file
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

    # 8) Dry‐run?
    if [ "$GIV_DRY_RUN" = "true" ]; then
        print_debug "Dry run: updated changelog content:"
        cat "$tmp_out"
        return 0
    fi

    # 9) Write back to real changelog
    if cat "$tmp_out" >"$output_file"; then
        printf 'Changelog written to %s\n' "$output_file"
    else
        printf 'Error: Failed to write %s\n' "$output_file" >&2
        exit 1
    fi

    print_debug "Changelog generated successfully."
}



# -------------------------------------------------------------------
# cmd_document: generic driver for any prompt template
#
# Arguments:
#   $1 = full path to prompt template file
#   $2 = revision specifier     (e.g. "--current")
#   $3 = GIV_PATHSPEC               (e.g. "src/*" or "README.md")
#   $4 = output file path
#   $5 = model mode             (e.g. "auto", "your-model")
#   $6 = temperature            (e.g. "0.7", "0.6")
#   $7 = context window size    (optional; e.g. "65536")
#   $8… = extra flags for build_prompt (e.g. --example, --rules)
#
# Side-effects:
#   - Summaries are written to a temp file
#   - A prompt is built and written to another temp file
#   - generate_from_prompt is invoked to create the final output
#
cmd_document() {
    prompt_tpl="$1"
    revision="${2:---current}"
    pathspec="${3:-}" # New GIV_PATHSPEC argument
    out="${4:-}"
    mode="${5:-auto}"
    temp="${6:-0.9}"
    ctx="${7:-32768}"
    shift 7

    # validate template exists
    if [ ! -f "${prompt_tpl}" ]; then
        printf 'template file not found: %s\n' "${prompt_tpl}" >&2
        exit 1
    fi

    # derive base name for temp file prefixes
    doc_base=$(basename "${prompt_tpl%.*}")

    # 1) Summarize
    summaries=$(portable_mktemp "${doc_base}_summaries_XXXXXX.md")
    print_debug "Generating summaries to: ${summaries}"
    summarize_target "${revision}" "${summaries}" "${pathspec}" "${mode}"

    # bail if no summaries
    if [ ! -f "${summaries}" ]; then
        printf 'Error: No summaries generated for %s.\n' "${revision}" >&2
        exit 1
    fi

    # 2) Build prompt
    prompt_tmp=$(portable_mktemp "${doc_base}_prompt_XXXXXX.md")
    title=$(get_project_title "${summaries}")
    current_version="$(get_version_info --current "$(find_version_file)")"

    print_debug "Building prompt from ${prompt_tpl} using ${summaries}"
    build_prompt \
        --project-title "${title}" \
        --version "${current_version}" \
        --template "${prompt_tpl}" \
        --summary "${summaries}" \
        "$@" >"${prompt_tmp}"

    print_debug "Built prompt file: ${prompt_tmp}"

    # 3) Generate final document
    if [ -n "${ctx}" ]; then
        generate_from_prompt "${prompt_tmp}" "${out}" "${mode}" "${temp}" "${ctx}"
    else
        generate_from_prompt "${prompt_tmp}" "${out}" "${mode}" "${temp}"
    fi
}
