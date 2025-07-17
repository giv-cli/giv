#!/bin/sh


# Extract TODO changes for history extraction
extract_todo_changes() {
    range="$1"
    pattern="${2:-$todo_pattern}"

    print_debug "Extracting TODO changes for range: ${range} and pattern ${pattern}"
    # Default to no pattern if not set
    set -- # Reset positional args to avoid confusion

    if [ "${range}" = "--cached" ]; then
        td=$(git --no-pager diff --cached --unified=0 -b -w --no-prefix --color=never -- "${pattern}" 2>/dev/null || true)
    elif [ "${range}" = "--current" ] || [ -z "${range}" ]; then
        td=$(git --no-pager diff --unified=0 -b -w --no-prefix --color=never -- "${pattern}" 2>/dev/null || true)
    else
        td=$(git --no-pager diff "${range}^!" --unified=0 -b -w --no-prefix --color=never -- "${pattern}" 2>/dev/null || true)
    fi
    printf '%s' "${td}"
}

# helper: writes message header based on commit type
get_message_header() {
    commit="$1"
    print_debug "Getting message header for commit $commit"
    case "$commit" in
    --cached) echo "Staged Changes" ;;
    --current | "") echo "Current Changes" ;;
    *) git log -1 --pretty=%B "$commit" ;;
    esac
}


# get_commit_date - Retrieves the date of a given commit, or the current date for special cases.
#
# Arguments:
#   $1 - The commit hash or identifier to retrieve the date from (e.g., SHA, --current, --cached).
#
# Description:
#   This function returns the date associated with a specific git commit. If the commit is
#   "--current" or "--cached", it returns the current date.
#
# Outputs:
#   Prints the date of the specified commit to stdout.
get_commit_date() {
    commit="$1"

    if [ "$commit" = "--current" ] || [ "$commit" = "--cached" ]; then
        # Return the current date for special cases
        date +"%Y-%m-%d"
    else
        # Get the date of the specified commit
        git show -s --format=%ci "$commit" | cut -d' ' -f1
    fi
}

print_commit_metadata() {
    commit="$1"
    commit_version="$(get_version_info "$commit" "$(find_version_file)")"
    printf '**Project Title:*** %s\n' "$(get_project_title)"
    printf '**Version:*** %s\n' "${commit_version}"
    printf '**Commit ID:*** %s\n' "$commit"
    printf '**Date:** %s\n' "$(get_commit_date "$commit")"
    printf '**Message:** %s\n' "$(get_message_header "$commit")"
}


# helper: builds main diff output (tracked + optional untracked)
build_diff() {
    commit="$1"
    diff_pattern="$2"

    # Build git diff command as a string (POSIX-compatible, no arrays)
    diff_cmd="git --no-pager diff"
    case "$commit" in
    --cached) diff_cmd="$diff_cmd --cached" ;;
    --current | "") ;;
    *) diff_cmd="$diff_cmd ${commit}^!" ;;
    esac
    print_debug "Building diff for commit $commit with pattern $diff_pattern"

    diff_cmd="$diff_cmd --minimal --no-prefix --unified=3 --no-color -b -w --compact-summary --color-moved=no"
    if [ -n "$diff_pattern" ]; then
        diff_cmd="$diff_cmd -- \"$diff_pattern\""
    fi

    print_debug "$diff_cmd"
    # shellcheck disable=SC2086
    diff_output=$(eval "$diff_cmd")

    # handle untracked files
    untracked=$(git ls-files --others --exclude-standard)
    OLD_IFS=$IFS
    IFS='
'
    for f in $untracked; do
        [ ! -f "$f" ] && continue
        if [ -n "$diff_pattern" ]; then
            # Only match if the pattern matches the filename (basic glob)
            # shellcheck disable=SC2254
            case "$f" in
            $diff_pattern) ;;
            *) continue ;;
            esac
        fi

        extra=$(git --no-pager diff --no-prefix --unified=0 --no-color -b -w \
            --minimal --compact-summary --color-moved=no \
            --no-index /dev/null "$f" 2>/dev/null || true)

        if [ -n "$diff_output" ] && [ -n "$extra" ]; then
            diff_output="${diff_output}
            ${extra}"
        elif [ -n "$extra" ]; then
            diff_output="$extra"
        fi
    done
    IFS=$OLD_IFS

    printf '%s\n' "$diff_output"
}

# top-level refactored build_history
build_history() {
    hist="$1"
    commit="$2"
    todo_pattern="${3:-${GIV_TODO_PATTERN:-TODO}}"
    diff_pattern="${4:-}"

    print_debug "Building history for commit $commit"
    : >"$hist"

    if [ -z "$commit" ]; then
        commit="--current"
    fi

    # Verify the commit is valid
    if [ "$commit" != "--cached" ] && [ "$commit" != "--current" ] && ! git rev-parse --verify "$commit" >/dev/null 2>&1; then
        printf 'Error: Could not build history for commit: %s\n' "$commit" >&2
        exit 1
    fi

    # header
    printf '### Commit ID %s\n' "$commit" >>"$hist"
    printf '**Date:** %s\n' "$(get_commit_date "$commit")" >>"$hist"
    # version
    vf=$(find_version_file)
    [ -n "$vf" ] && print_debug "Found version file: $vf"
    [ -n "$vf" ] && {
        ver=$(get_version_info "$commit" "$vf")
        [ -n "$ver" ] && printf '**Version:** %s\n' "$ver" >>"$hist"
    }
    msg=$(get_message_header "$commit")
    printf '**Message:** %s\n' "$msg" >>"$hist"

    # diff
    diff_out=$(build_diff "$commit" "$diff_pattern" "$debug")
    # shellcheck disable=SC2016
    printf '```diff\n%s\n```\n' "$diff_out" >>"$hist"

    # diff for todos
    td=$(extract_todo_changes "$commit" "$todo_pattern")
    print_debug "TODO changes: $td"
    # shellcheck disable=SC2016
    [ -n "$td" ] && printf '\n### TODO Changes\n```diff\n%s\n```\n' "$td" >>"$hist"

    return 0
}


# -------------------------------------------------------------------
# summarize_target: summarize a commit, or an inclusive two-/three-dot
# range, or the working tree/index.
#
#   $1 = target (SHA, range, --current, --cached, or "")
#   $2 = path to write summaries into
#   $3 = pathspec to limit changes
#   $4 = (optional) override for model_mode
# -------------------------------------------------------------------
summarize_target() {
    target="$1"
    summaries_file="$2"
    pathspec="$3"
    gen_mode="${4:-$model_mode}"

    # 1) Special "current" / "cached" / empty
    if [ -z "$target" ] || [ "$target" = "--current" ] || [ "$target" = "--cached" ]; then
        print_debug "Processing special target: ${target}"
        summarize_commit "$target" "$pathspec" "$gen_mode" >>"$summaries_file"
        printf '\n' >>"$summaries_file"
        return
    fi

    # 2) Two- or three-dot range?
    if printf '%s' "$target" | grep -qE '\.\.\.?'; then
        print_debug "Detected commit-range syntax: ${target}"
        # Figure out which sep
        if printf '%s' "$target" | grep -q '\.\.\.'; then
            sep='...'
        else
            sep='..'
        fi

        # Split endpoints
        left="${target%%"$sep"*}"
        right="${target#*"$sep"}"
        print_debug "Range endpoints: left='${left}' right='${right}'"

        # Validate both endpoints
        for c in "$left" "$right"; do
            if ! git rev-parse --verify "$c" >/dev/null 2>&1; then
                printf 'Error: Invalid commit in range: %s\n' "$c" >&2
                exit 1
            fi
        done

        # Summarize left endpoint first
        summarize_commit "$left" "$pathspec" "$gen_mode" >>"$summaries_file"
        printf '\n' >>"$summaries_file"

        # Now list & summarize everything in the range (excludes left)
        commits_file=$(portable_mktemp "commits_list_XXXXXX")
        git rev-list --reverse "$target" >"$commits_file"

        while IFS= read -r commit; do
            print_debug "Summarizing commit: $commit"
            summarize_commit "$commit" "$pathspec" "$gen_mode" >>"$summaries_file"
            printf '\n' >>"$summaries_file"
        done <"$commits_file"

        rm -f "$commits_file"
        return
    fi

    # 3) Single commit (tags, HEAD~N, SHA, etc.)
    if git rev-parse --verify "$target" >/dev/null 2>&1; then
        print_debug "Summarizing single commit: $target"
        summarize_commit "$target" "$pathspec" "$gen_mode" >>"$summaries_file"
        printf '\n========================\n\n'  >>"$summaries_file"
        return
    fi

    # 4) Nothing matched → fatal
    print_error "Error: Invalid target: $target"
    exit 1
}

# summarize_commit - Generates a summary for a given commit.
#
# Arguments:
#   $1 - The commit hash or identifier to summarize.
#   $2 - (Optional) The generation mode to use; defaults to the value of $model_mode.
#
# Description:
#   This function creates temporary files to store commit history, prompt, and summary results.
#   It builds the commit history, retrieves version information, and constructs a summary prompt.
#   The prompt is then used to generate a summary response, which is saved to a file and printed.
#
# Outputs:
#   Prints the generated summary to stdout.
#
# Dependencies:
#   - portable_mktemp
#   - print_debug
#   - build_history
#   - find_version_file
#   - get_version_info
#   - build_prompt
#   - generate_response
summarize_commit() {
    commit="$1"
    pathspec="$2"
    gen_mode="${3:-${model_mode}}"
    hist=$(portable_mktemp "hist.${commit}.XXXXXX.md")
    pr=$(portable_mktemp "prompt.${commit}.XXXXXX.md")
    res_file=$(portable_mktemp "summary.${commit}.XXXXXX.md")
    print_debug "summarize_commit ${commit} ${hist} ${pr}"
    build_history "${hist}" "${commit}" "${todo_pattern}" "$pathspec"
    sc_version_file=$(find_version_file)
    sc_version=$(get_version_info "${commit}" "${sc_version_file}")
    summary_template=$(build_prompt --version "${sc_version}" \
        --template "${TEMPLATE_DIR}/summary_prompt.md" --summary "${hist}")
    print_debug "Using summary prompt: ${summary_template}"
    printf '%s\n' "${summary_template}" >"${pr}"
    res=$(generate_response "${pr}" "${gen_mode}" "0.9" "32768")

    print_commit_metadata "$commit" >"$res_file"
    printf '\n\n' >>"$res_file"
    echo "${res}" >>"$res_file"

    cat "${res_file}"
}
