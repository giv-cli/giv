#!/bin/sh
# giv - A POSIX-compliant script to generate commit messages, summaries,
# changelogs, release notes, and announcements from Git history using AI
__VERSION="0.2.0"

set -eu
IFS='
'


# -------------------------------------------------------------------
# Paths & Defaults
# -------------------------------------------------------------------
# Resolve script directory robustly, whether sourced or executed
# Works in POSIX sh, bash, zsh, dash
get_script_dir() {
    # $1: path to script (may be $0 or ${BASH_SOURCE[0]})
    script="$1"
    case "$script" in
        /*) dir=$(dirname "$script") ;;
        *) dir=$(cd "$(dirname "$script")" 2>/dev/null && pwd) ;;
    esac
    printf '%s\n' "$dir"
}

# Detect if sourced (works in bash, zsh, dash, sh)
_is_sourced=0
# shellcheck disable=SC2292
if [ "${BASH_SOURCE:-}" != "" ] && [ "${BASH_SOURCE:-}" != "$0" ]; then
    _is_sourced=1
elif [ -n "${ZSH_EVAL_CONTEXT:-}" ] && [ "${ZSH_EVAL_CONTEXT#*:}" = "file" ]; then
    _is_sourced=1
fi
# Use BASH_SOURCE if available, else $0
if [ -n "${BASH_SOURCE:-}" ]; then
    _SCRIPT_PATH="${BASH_SOURCE}"
else
    _SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$(get_script_dir "$_SCRIPT_PATH")"
PROMPT_DIR="${SCRIPT_DIR}/../prompts"

# shellcheck source=helpers.sh
. "${SCRIPT_DIR}/helpers.sh"


REVISION=""
PATHSPEC=""

config_file=""
is_config_loaded=false
debug=""
dry_run=""
template_dir="$PROMPT_DIR"
output_file=''
todo_pattern=''
todo_files="*todo*"


# Subcommand & templates
subcmd=''
output_mode='auto'
output_version='auto'
version_file=''
version_pattern=''
prompt_file=''

# Model settings
model=${GIV_MODEL:-'qwen2.5-coder'}
model_mode=${GIV_MODEL_MODE:-'auto'}
api_model=${GIV_API_MODEL:-}
api_url=${GIV_API_URL:-}
api_key=${GIV_API_KEY:-}

# Changelog & release defaults
changelog_file='CHANGELOG.md'
release_notes_file='RELEASE_NOTES.md'
announce_file='ANNOUNCEMENT.md'

# Parse global flags and detect subcommand/target/pattern
parse_args() {

    # Restore original arguments for main parsing
    # 1. Subcommand or help/version must be first
    if [ $# -eq 0 ]; then
        printf 'No arguments provided.\n'
        exit 1
    fi
    case "$1" in
    -h | --help | help)
        show_help
        exit 0
        ;;
    -v | --version)
        show_version
        exit 0
        ;;
    message | summary | changelog | release-notes | announcement | available-releases | update)
        subcmd=$1
        shift
        ;;
    *)
        echo "First argument must be a subcommand or -h/--help/-v/--version"
        show_help
        exit 1
        ;;
    esac

    # Preserve original arguments for later parsing
    set -- "$@"

    # Early config file parsing (handle both --config-file and --config-file=)
    config_file="${PWD}/.env"
    i=1
    while [ $i -le $# ]; do
        eval "arg=\${$i}"
        case "$arg" in
        --config-file)
            next=$((i + 1))
            if [ $next -le $# ]; then
                eval "config_file=\${$next}"
                [ -n "${debug}" ] && printf 'Debug: Found config file argument: --config-file %s\n' "${config_file}"
                break
            else
                printf 'Error: --config-file requires a file path argument.\n'
                exit 1
            fi
            ;;
        --config-file=*)
            config_file="${arg#--config-file=}"
            [ -n "${debug}" ] && printf 'Debug: Found config file argument: --config-file=%s\n' "${config_file}"
            break
            ;;
        *)
            # Not a config file argument, continue parsing
            ;;
        esac
        i=$((i + 1))
    done

    # -------------------------------------------------------------------
    # Config file handling (early parse)
    # -------------------------------------------------------------------
    [ -n "$debug" ] && printf 'Loading config file: %s\n' "$config_file"

    # Always attempt to source config file if it exists; empty config_file is a valid state.
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        # shellcheck disable=SC1090
        . "$config_file"
        is_config_loaded=true
        [ -n "$debug" ] && printf '\nLoaded config file: %s\n' "$config_file"
        # Override defaults with config file values
        model=${GIV_MODEL:-$model}
        model_mode=${GIV_MODEL_MODE:-$model_mode}
        api_model=${GIV_API_MODEL:-$api_model}
        api_url=${GIV_API_URL:-$api_url}
        api_key=${GIV_API_KEY:-$api_key}
    elif [ -n "$config_file" ]; then
        printf 'Warning: config file "%s" not found.\n' "$config_file"
    fi

    # 2. Next arg: target (if present and not option)
    if [ $# -gt 0 ]; then
        case "$1" in
        --current | --staged | --cached)
            if [ "$1" = "--staged" ]; then
                REVISION="--cached"
            else
                REVISION="$1"
            fi
            shift
            ;;
        -*)
            : # skip, no target
            ;;
        *)
            [ -n "${debug}" ] && printf 'Debug: Parsing target: %s\n' "$1"
            # Check if $1 is a valid commit range or commit id
            if echo "$1" | grep -q '\.\.'; then
                if git rev-list "$1" >/dev/null 2>&1; then
                    REVISION="$1"
                    # If it's a valid commit ID, shift it
                    [ -n "$debug" ] &&  printf 'Debug: Valid commit range: %s\n' "$1"
                    shift
                else
                    printf 'Error: Invalid commit range: %s\n' "$1" >&2
                    exit 1
                fi
            elif git rev-parse --verify "$1" >/dev/null 2>&1; then
                REVISION="$1"
                # If it's a valid commit ID, shift it
                [ -n "$debug" ] &&  printf 'Debug: Valid commit ID: %s\n' "$1"
                shift
            else
                printf 'Error: Invalid target: %s\n' "$1" >&2
                exit 1
            fi
            # else: do not shift, let it fall through to pattern parsing
            ;;
        esac
    fi

    if [ -z "$REVISION" ]; then
        # If no target specified, default to current working tree
        [ -n "$debug" ] &&  printf 'Debug: No target specified, defaulting to current working tree.\n'
        REVISION="--current"
    fi
    # 3. Collect all non-option args as pattern (until first option or end)
    PATHSPEC=""
    while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do
        # If the first argument is a pattern, collect it
        [ -n "$debug" ] && printf 'Debug: Collecting pattern: %s\n' "$1"
        if [ -z "${PATHSPEC}" ]; then
            PATHSPEC="$1"
        else
            PATHSPEC="${PATHSPEC} $1"
        fi
        shift
    done

    [ -n "$debug" ] && printf 'Target and pattern parsed: %s, %s\n' "$REVISION" "$PATHSPEC"

    # 4. Remaining args: global options
    while [ $# -gt 0 ]; do
        case "$1" in
        --verbose)
            debug=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --config-file)
            config_file=$2
            shift 2
            ;;
        --todo-files)
            todo_files=$2
            shift 2
            ;;
        --todo-pattern)
            todo_pattern=$2
            shift 2
            ;;
        --prompt-file)
            prompt_file=$2
            shift 2
            ;;
        --model-mode)
            model_mode=$2
            shift 2
            ;;
        --model)
            model=$2
            shift 2
            ;;
        --api-model)
            api_model=$2
            shift 2
            ;;
        --api-url)
            api_url=$2
            shift 2
            ;;
        --version-file)
            version_file=$2
            shift 2
            ;;
        --version-pattern)
            version_pattern=$2
            shift 2
            ;;
        --output-version)
            output_version=$2
            shift 2
            ;;
        --output-mode)
            output_mode=$2
            shift 2
            ;;
        --output-file)
            output_file=$2
            shift 2
            ;;
        --)
            echo "Unknown option or argument: $1" >&2
            show_help
            exit 1
            ;;
        --*)
            echo "Unknown option or argument: $1" >&2
            show_help
            exit 1
            ;;
        *)
            echo "Unknown argument: $1" >&2
            show_help
            exit 1
            ;;
        esac
    done

    # Determine ollama/remote mode once before parsing args
    if [ "${model_mode}" = "auto" ] || [ "${model_mode}" = "local" ]; then
        if ! command -v ollama >/dev/null 2>&1; then
            [ -n "${debug}" ] && printf 'Debug: ollama not found, forcing remote mode (local model unavailable).\n'
            model_mode="remote"
            if [ -z "${api_key}" ]; then
                [ -n "${debug}" ] && printf 'Warning: ollama not found, so remote mode is required, but GIV_API_KEY is not set.\n' >&2
                model_mode="none"
                dry_run=true
            fi
            if [ -z "${api_url}" ]; then
                [ -n "${debug}" ] && printf 'Warning: ollama not found, so remote mode is required, but no API URL provided (use --api-url or GIV_API_URL).\n' >&2
                model_mode="none"
                dry_run=true
            fi
        fi
    elif [ "${model_mode}" = "remote" ]; then
        if [ -z "${api_key}" ]; then
            printf 'Error: Remote mode is enabled, but no API key provided (use --api-key or GIV_API_KEY).\n' >&2
            exit 1
        fi
        if [ -z "${api_url}" ]; then
            printf 'Error: Remote mode is enabled, but no API URL provided (use --api-url or GIV_API_URL).\n' >&2
            exit 1
        fi
    fi

    [ "${model_mode}" = "none" ] && printf 'Warning: Model provider set to "none", no model will be used.\n' >&2

    if [ -n "$debug" ]; then
        echo "Parsed options:"
        echo "  Debug: $debug"
        echo "  Dry Run: $dry_run"
        echo "  Subcommand: $subcmd"
        echo "  Revision: $REVISION"
        echo "  Pathspec: $PATHSPEC"
        echo "  Template Directory: $template_dir"
        echo "  Config File: $config_file"
        echo "  Config Loaded: $is_config_loaded"
        echo "  Output File: $output_file"
        echo "  TODO Files: $todo_files"
        echo "  TODO Pattern: $todo_pattern"
        echo "  Version File: $version_file"
        echo "  Version Pattern: $version_pattern"
        echo "  Model: $model"
        echo "  Model Mode: $model_mode"
        echo "  API Model: $api_model"
        echo "  API URL: $api_url"
        echo "  Output Mode: $output_mode"
        echo "  Output Version: $output_version"
        echo "  Prompt File: $prompt_file"
    fi       
}
# -------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------
show_version() {
    printf '%s\n' "${__VERSION}"
}
# Show all available release tags
get_available_releases() {
    curl -s https://api.github.com/repos/itlackey/giv/releases | awk -F'"' '/"tag_name":/ {print $4}'
    exit 0
}
# Update the script to a specific release version (or latest if not specified)
run_update() {
    version="${1:-latest}"
    if [ "$version" = "latest" ]; then
        latest_version=$(get_available_releases | head -n 1)
        printf 'Updating giv to version %s...\n' "${latest_version}"
        curl -fsSL https://raw.githubusercontent.com/itlackey/giv/main/install.sh | sh -- --version "${latest_version}"
    else
        printf 'Updating giv to version %s...\n' "${version}"
        curl -fsSL "https://raw.githubusercontent.com/itlackey/giv/main/install.sh" | sh -- --version "${version}"
    fi
    printf 'Update complete.\n'
    exit 0
}

show_help() {
    cat <<EOF
Usage: giv <subcommand> [revision] [pathspec] [OPTIONS]

Argument        Meaning
--------------- ------------------------------------------------------------------------------
revision        Any Git revision or revision-range (HEAD, v1.2.3, abc123, HEAD~2..HEAD, origin/main...HEAD, --cached, --current)
pathspec        Standard Git pathspec to narrow scope—supports magic prefixes, negation (! or :(exclude)), and case-insensitive :(icase)

Option Groups

General
  -h, --help            Show help and exit
  -v, --version         Show giv version
  --verbose             Debug / trace output
  --dry-run             Preview only; write nothing
  --config-file PATH    Shell config sourced before run

Revision & Path Selection (what to read)
  (positional) revision   Git revision or range
  (positional) pathspec   Git pathspec filter

Diff & Content Filters (what to keep)
  --todo-files PATHSPEC   Pathspec that marks files to scan for TODOs
  --todo-pattern REGEX    Regex evaluated inside files matched by --todo-files
  --version-file PATHSPEC Pathspec of file(s) to inspect for version bumps
  --version-pattern REGEX Custom regex that identifies version strings

AI / Model (how to think)
  --model MODEL          Local Ollama model name
  --model-mode MODE      auto (default), local, remote, none
  --api-model MODEL      Remote model when --model-mode remote
  --api-url URL          Remote API endpoint

Output Behaviour (where to write)
  --output-mode MODE     auto, prepend, append, update, none
  --output-version NAME  Overrides section header / tag
  --output-file PATH     Destination file (default depends on subcommand)
  --prompt-file PATH     Markdown prompt template to use

Maintenance Subcommands
  available-releases     List script versions
  update                 Self-update giv

Environment Variables
  GIV_API_KEY            API key for remote model
  GIV_API_URL            Endpoint default if --api-url is omitted
  GIV_MODEL              Default local model
  GIV_MODEL_MODE         auto, local, remote, none (overrides flag)

Subcommands
  message                Draft an AI commit message (default)
  summary                Human-readable summary of changes
  changelog              Create or update CHANGELOG.md
  release-notes          Longer notes for a tagged release
  announcement           Marketing-style release announcement
  available-releases     List script versions
  update                 Self-update giv

Examples:
  giv message HEAD~3..HEAD src/
  giv changelog --todo-files '*.ts' --todo-pattern 'TODO\\(\\w+\\):'
  giv release-notes v1.2.0..HEAD --model-mode remote --api-model gpt-4o --api-url https://api.example.com/v1/chat/completions
EOF
}

# # -------------------------------------------------------------------
# # Subcommand Implementations
# # -------------------------------------------------------------------

cmd_message() {
    commit_id="${1:-"--current"}"
    [ -n "$debug" ] && printf 'Generating commit message for %s...\n' "${commit_id}"

    # If the target is not the working tree or staged changes, return the message for the commit
    if [ -z "${commit_id}" ]; then
        printf 'Error: No commit ID or range specified for message generation.\n' >&2
        exit 1
    elif [ "$commit_id" != "--current" ] && [ "$commit_id" != "--cached" ]; then
        # Handle commit ranges (e.g., HEAD~3..HEAD)

        if echo "$commit_id" | grep -q '\.\.'; then
            [ -n "$debug" ] && printf 'Processing commit range: %s\n' "$commit_id"
            if ! git rev-list "$commit_id" >/dev/null 2>&1; then
                printf 'Error: Invalid commit range: %s\n' "$commit_id" >&2
                exit 1
            fi
            git log --reverse --pretty=%B "$commit_id"
            exit 0
        else
        [ -n "$debug" ] && printf 'Processing single commit: %s\n' "$commit_id"
            if ! git rev-parse --verify "$commit_id" >/dev/null 2>&1; then
                printf 'Error: Invalid commit ID: %s\n' "$commit_id" >&2
                exit 1
            fi
            git log -1 --pretty=%B "$commit_id" | sed '${/^$/d;}'
            exit 0
        fi
    fi
    hist=$(portable_mktemp)
    build_history "$hist" "$commit_id" "$todo_pattern" "$PATHSPEC"
    [ -n "$debug" ] && printf 'Debug: Generated history file %s\n' "$hist"
    pr=$(portable_mktemp)
    printf '%s' "$(build_prompt "${PROMPT_DIR}/commit_message_prompt.md" "$hist")" >"$pr"
    [ -n "$debug" ] && printf 'Debug: Generated prompt file %s\n' "$pr"
    res=$(generate_response "$pr")
    rm -f "$hist" "$pr"
   
    printf '%s\n' "$res";
}

cmd_summary() {
    summaries_file=$(portable_mktemp)
    summarize_target "${REVISION}" "${summaries_file}"
    if [ -n "${output_file}" ]; then
        if [ "${dry_run}" != "true" ]; then
            cp "${summaries_file}" "${output_file}"
            printf 'Summary written to %s\n' "${output_file}"
        else
            cat "${summaries_file}"
        fi
    else
        cat "${summaries_file}"
    fi
    rm -f "${summaries_file}"
}

cmd_release_notes() {
    summaries_file=$(portable_mktemp)
    summarize_target "${REVISION}" "${summaries_file}"
    prompt_file_name="${PROMPT_DIR}/release_notes_prompt.md"
    tmp_prompt_file=$(portable_mktemp)
    build_prompt "${prompt_file_name}" "${summaries_file}" > "${tmp_prompt_file}"
    generate_from_prompt "${tmp_prompt_file}" "${output_file:-${release_notes_file}}"
    rm -f "${summaries_file}"
    rm -f "${tmp_prompt_file}"
}

cmd_announcement() {
    summaries_file=$(portable_mktemp)
    summarize_target "${REVISION}" "${summaries_file}"
    cat "${summaries_file}"
    prompt_file_name="${PROMPT_DIR}/announcement_prompt.md"
    tmp_prompt_file=$(portable_mktemp)
    build_prompt "${prompt_file_name}" "${summaries_file}" > "${tmp_prompt_file}"
    generate_from_prompt "${tmp_prompt_file}" "${output_file:-${announce_file}}"
    rm -f "${summaries_file}"
    rm -f "${tmp_prompt_file}"
}

cmd_changelog() {
    # prompt="Write a changelog for version $version based on these summaries:"
    summaries_file=$(portable_mktemp)
    summarize_target "$REVISION" "${summaries_file}"

    #if summaries_file is empty, exit early
    if [ ! -s "${summaries_file}" ]; then
        printf 'Error: No summaries generated for changelog.\n' >&2
        exit 1
    fi

    prompt_file_name="${PROMPT_DIR}/changelog_prompt.md"
    tmp_prompt_file=$(portable_mktemp)
    build_prompt "${prompt_file_name}" "${summaries_file}" > "${tmp_prompt_file}"

    # TODO: add support for --update-mode
    generate_from_prompt "${tmp_prompt_file}" "${output_file:-${changelog_file}}"
    rm -f "${summaries_file}"
    rm -f "${tmp_prompt_file}"
}


if [ "${_is_sourced}" -eq 0 ]; then
    parse_args "$@"

    # Verify the PWD is a valid git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'Error: Current directory is not a valid git repository.\n'
        exit 1
    fi
    # # Enable debug mode if requested
    # if [ -n "${debug}" ]; then
    #     set -x
    # fi

    # Dispatch logic
    case "${subcmd}" in
    summary) cmd_summary ;;
    release-notes) cmd_release_notes ;;
    announcement) cmd_announcement ;;
    message) cmd_message "${REVISION}" ;;
    changelog) cmd_changelog ;;
    help)
        show_help
        exit 0
        ;;
    available-releases)
        get_available_releases
        ;;
    update)
        run_update "latest"
        ;;
    *) cmd_message "${REVISION}" ;;
    esac
fi
