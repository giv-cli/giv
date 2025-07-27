#!/bin/sh

# Load initialization and shared functions
. "$GIV_LIB_DIR/init.sh"

# Allow test harness to inject mock functions (for bats)
if [ -n "${GIV_TEST_MOCKS:-}" ] && [ -f "${GIV_TEST_MOCKS:-}" ]; then
  . "$GIV_TEST_MOCKS"
fi

# Set defaults for revision and pathspec if not provided
GIV_REVISION="${GIV_REVISION:---current}"
GIV_PATHSPEC="${GIV_PATHSPEC:-}"
export GIV_REVISION
export GIV_PATHSPEC

# Parse arguments for the message subcommand
parse_message_arguments() {
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
            --todo-pattern)
                shift
                export GIV_TODO_PATTERN="$1"
                ;;
            *)
                # First non-option argument is the revision
                if [ -z "${GIV_REVISION_SET:-}" ]; then
                    export GIV_REVISION="$1"
                    export GIV_REVISION_SET="true"
                else
                    echo "Error: Unknown option '$1' for message subcommand." >&2
                    return 1
                fi
                ;;
        esac
        shift
    done

    # Set defaults if not provided
    export GIV_REVISION="${GIV_REVISION:---current}"
    export GIV_PATHSPEC="${GIV_PATHSPEC:-}"  # Default to empty pathspec

    return 0
}

# Parse arguments from the global parser
if [ -n "${GIV_REMAINING_ARGS:-}" ]; then
    eval "parse_message_arguments $GIV_REMAINING_ARGS"
else
    parse_message_arguments
fi

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
        
        # Check if there are actual changes to process
        if [ ! -s "${hist}" ]; then
            printf 'Error: No changes to generate commit message for.\n' >&2
            exit 1
        fi
        
        # Check if history contains actual diff content (not just headers)
        if ! grep -q '```diff' "${hist}"; then
            printf 'Error: No changes found in working directory.\n' >&2
            exit 1
        fi
        
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