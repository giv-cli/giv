#!/bin/sh

# Load initialization and shared functions
. "$GIV_LIB_DIR/init.sh"


# All arguments are already parsed by the unified parser
# Use environment variables set by the parser

cmd_message() {
    # Use environment variables set by unified parser
    commit_id="${GIV_REVISION:---current}"
    pathspec="${GIV_PATHSPEC:-}"
    todo_pattern="${GIV_TODO_PATTERN:-}"

    if [ -z "${commit_id}" ]; then
        commit_id="--current"
    fi

    print_debug "Generating commit message for ${commit_id}"

    # Handle both --current and --cached (see argument parsing section for details).
    if [ "${commit_id}" = "--current" ] || [ "${commit_id}" = "--cached" ]; then
        hist=$(portable_mktemp "commit_history_XXXXXX")
        build_history "${hist}" "${commit_id}" "${todo_pattern}" "${pathspec}"
        print_debug "Generated history file ${hist}"
        pr=$(portable_mktemp "commit_message_prompt_XXXXXX")
        build_prompt --template "${GIV_TEMPLATE_DIR}/message_prompt.md" \
            --summary "${hist}" >"${pr}"
        print_debug "Generated prompt file ${pr}"
        
        # Handle dry-run mode before API call
        if [ "${GIV_DRY_RUN:-}" = "true" ]; then
            if [ -n "${GIV_TEST_MOCKS:-}" ] && [ -f "${GIV_TEST_MOCKS:-}" ]; then
                res=$(generate_response "${pr}" "0.9" "32768")
                printf '%s\n' "${res}"
            else
                printf '%s\n' "[DRY RUN] Would generate commit message from prompt: ${pr}"
            fi
            return 0
        fi
        res=$(generate_response "${pr}" "0.9" "32768")        
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
            git --no-pager log --pretty=%B --left-right "${commit_id}" | sed -e '/^$/d'
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

# Execute the command
cmd_message