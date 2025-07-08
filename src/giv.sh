#!/bin/sh
# giv - A POSIX-compliant script to generate commit messages, summaries,
# changelogs, release notes, and announcements from Git history using AI
__VERSION="0.3.0-beta"

set -eu

# Ensure our temp-dir cleanup always runs:
# trap 'remove_tmp_dir' EXIT INT TERM

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
GIV_TMPDIR=""

# shellcheck source=helpers.sh
. "${SCRIPT_DIR}/helpers.sh"

REVISION=""
PATHSPEC=""

config_file=""
is_config_loaded=false
debug=false
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
model=${GIV_MODEL:-'devstral'}
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
        # shellcheck disable=SC2154
        case "$arg" in
        --config-file)
            next=$((i + 1))
            if [ $next -le $# ]; then
                eval "config_file=\${$next}"
                print_debug "Debug: Found config file argument: --config-file ${config_file}"
                break
            else
                printf 'Error: --config-file requires a file path argument.\n'
                exit 1
            fi
            ;;
        --config-file=*)
            config_file="${arg#--config-file=}"
            print_debug "Found config file argument: --config-file=${config_file}"
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

    # Always attempt to source config file if it exists; empty config_file is a valid state.
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        # shellcheck disable=SC1090
        . "$config_file"
        is_config_loaded=true
        print_debug "Loaded config file: $config_file"
        # Override defaults with config file values
        model=${GIV_MODEL:-$model}
        model_mode=${GIV_MODEL_MODE:-$model_mode}
        api_model=${GIV_API_MODEL:-$api_model}
        api_url=${GIV_API_URL:-$api_url}
        api_key=${GIV_API_KEY:-$api_key}
    elif [ ! -f "$config_file" ] && [ "${config_file}" != "${PWD}/.env" ]; then
        print_warn "config file ${config_file} not found."
    fi

    # 2. Next arg: revision (if present and not option)
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
            print_debug "Parsing revision: $1"
            # Check if $1 is a valid commit range or commit id
            if echo "$1" | grep -q '\.\.'; then
                if git rev-list "$1" >/dev/null 2>&1; then
                    REVISION="$1"
                    # If it's a valid commit ID, shift it
                    print_debug "Valid commit range: $1"
                    shift
                else
                    printf 'Error: Invalid commit range: %s\n' "$1" >&2
                    exit 1
                fi
            elif git rev-parse --verify "$1" >/dev/null 2>&1; then
                REVISION="$1"
                # If it's a valid commit ID, shift it
                print_debug "Valid commit ID: $1"
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
        print_debug "Debug: No target specified, defaulting to current working tree."
        REVISION="--current"
    fi
    # 3. Collect all non-option args as pattern (until first option or end)
    PATHSPEC=""
    while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do
        # If the first argument is a pattern, collect it
        print_debug "Collecting pattern: $1"
        if [ -z "${PATHSPEC}" ]; then
            PATHSPEC="$1"
        else
            PATHSPEC="${PATHSPEC} $1"
        fi
        shift
    done

    print_debug "Target and pattern parsed: $REVISION, $PATHSPEC"

    # 4. Remaining args: global options
    while [ $# -gt 0 ]; do
        case "$1" in
        --verbose)
            debug="true"
            shift
            ;;
        --dry-run)
            dry_run="true"
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
            print_debug "ollama not found, forcing remote mode (local model unavailable)"
            model_mode="remote"
            if [ -z "${api_key}" ]; then
                print_warn "ollama not found, so remote mode is required, but GIV_API_KEY is not set"
                model_mode="none"
                dry_run=true
            fi
            if [ -z "${api_url}" ]; then
                print_warn "ollama not found, so remote mode is required, but no API URL provided (use --api-url or GIV_API_URL)"
                model_mode="none"
                dry_run=true
            fi
        else
            model_mode="local"
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

    [ "${model_mode}" = "none" ] && print_warn "Model mode set to \"none\", no model will be used."

    if [ "$debug" = "true" ]; then
        printf 'Environment variables:\n'
        printf '  GIV_TMPDIR: %s\n' "${GIV_TMPDIR:-}"
        printf '  GIV_MODEL_MODE: %s\n' "${GIV_MODEL_MODE:-}"
        printf '  GIV_MODEL: %s\n' "${GIV_MODEL:-}"
        printf '  GIV_API_MODEL: %s\n' "${GIV_API_MODEL:-}"
        printf '  GIV_API_URL: %s\n' "${GIV_API_URL:-}"
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
    commit_id="$1"
    if [ -z "${commit_id}" ]; then
        commit_id="--current"
    fi

    print_debug "Generating commit message for ${commit_id}"

    # Handle both --current and --cached, as argument parsing may set either value.
    # This duplication ensures correct behavior regardless of which is set.
    if [ "$commit_id" = "--current" ] || [ "$commit_id" = "--cached" ]; then
        hist=$(portable_mktemp "commit_history_XXXXXX.md")
        build_history "$hist" "$commit_id" "$todo_pattern" "$PATHSPEC"
        print_debug "Generated history file $hist"
        pr=$(portable_mktemp "commit_message_prompt_XXXXXX.md")
        printf '%s' "$(build_prompt "${PROMPT_DIR}/commit_message_prompt.md" "$hist")" >"$pr"
        print_debug "Generated prompt file $pr"
        res=$(generate_response "$pr" "$model_mode")
        printf '%s\n' "$res"
        return
    fi

    # Detect exactly two- or three-dot ranges (A..B or A...B)
    if echo "$commit_id" | grep -qE '\.\.\.?'; then
        print_debug "Detected commit range syntax: $commit_id"

        # Confirm Git accepts it as a valid range
        if ! git rev-list "$commit_id" >/dev/null 2>&1; then
            print_error "Invalid commit range: $commit_id"
            exit 1
        fi

        # Use symmetric-difference for three-dot, exclusion for two-dot
        case "$commit_id" in
        *...*)
            print_debug "Processing three-dot range: $commit_id"
            git --no-pager log --pretty=%B --left-right "$commit_id" | sed '${/^$/d;}'
            ;;
        *..*)
            print_debug "Processing two-dot range: $commit_id"
            git --no-pager log --reverse --pretty=%B "$commit_id" | sed '${/^$/d;}'
            ;;
        esac
        return
    fi

    print_debug "Processing single commit: $commit_id"
    if ! git rev-parse --verify "$commit_id" >/dev/null 2>&1; then
        printf 'Error: Invalid commit ID: %s\n' "$commit_id" >&2
        exit 1
    fi
    git --no-pager log -1 --pretty=%B "$commit_id" | sed '${/^$/d;}'
    return
}

cmd_summary() {
    sum_output_file="${1:-}"
    sum_revision="${2:---current}"
    sum_model_mode="${3:-auto}"
    sum_dry_run="${4:-}"

    summaries_file=$(portable_mktemp "summary_summaries_XXXXXX.md")

    summarize_target "${sum_revision}" "${summaries_file}" "${sum_model_mode}"
    cat "${summaries_file}" >&2
    # Early exit if no summaries were produced
    if [ ! -f "${summaries_file}" ]; then
        printf 'Error: No summaries generated for %s.\n' "$sum_revision" >&2
        exit 1
    fi

    if [ -n "${sum_output_file}" ]; then
        if [ "${sum_dry_run}" != "true" ]; then
            cp "${summaries_file}" "${sum_output_file}"
            printf 'Summary written to %s\n' "${sum_output_file}"
        else
            cat "${summaries_file}"
        fi
    else
        cat "${summaries_file}"
    fi
}

cmd_release_notes() {
    summaries_file=$(portable_mktemp "release_notes_summaries_XXXXXX.md")
    summarize_target "${REVISION}" "${summaries_file}" "${model_mode}"

    # Early exit if no summaries were produced
    if [ ! -s "${summaries_file}" ]; then
        printf 'Error: No summaries generated for release notes.\n' >&2
        exit 1
    fi

    prompt_file_name="${PROMPT_DIR}/release_notes_prompt.md"
    tmp_prompt_file=$(portable_mktemp "release_notes_prompt_XXXXXX.md")
    build_prompt "${prompt_file_name}" "${summaries_file}" >"${tmp_prompt_file}"
    [ "${debug}" = "true" ] && printf 'Debug: Generated prompt file %s\n' "${tmp_prompt_file}"

    generate_from_prompt "${tmp_prompt_file}" \
        "${output_file:-${release_notes_file}}" "${model_mode}"
}

cmd_announcement() {
    summaries_file=$(portable_mktemp "announcement_summaries_XXXXXX.md")
    summarize_target "${REVISION}" "${summaries_file}" "${model_mode}"

    # Early exit if no summaries were produced
    if [ ! -s "${summaries_file}" ]; then
        printf 'Error: No summaries generated for announcements.\n' >&2
        exit 1
    fi

    prompt_file_name="${PROMPT_DIR}/announcement_prompt.md"
    tmp_prompt_file=$(portable_mktemp "announcement_prompt_XXXXXX.md")
    build_prompt "${prompt_file_name}" "${summaries_file}" >"${tmp_prompt_file}"

    generate_from_prompt "${tmp_prompt_file}" \
        "${output_file:-${announce_file}}" "${model_mode}"
}

# -------------------------------------------------------------------
# cmd_changelog: generate or update CHANGELOG.md from Git history
#
# Globals:
#   REVISION, model_mode, output_file, changelog_file,
#   PROMPT_DIR, output_version, output_mode, dry_run
# Dependencies:
#   portable_mktemp, summarize_target, build_prompt,
#   generate_from_prompt, update_changelog
# -------------------------------------------------------------------
cmd_changelog() {
    # 1) Determine output file
    output_file="${output_file:-$changelog_file}"
    print_debug "Changelog file: $output_file"

    # 2) Summarize Git history
    summaries_file=$(portable_mktemp "changelog_summaries_XXXXXX")
    if ! summarize_target "$REVISION" "$summaries_file" "$model_mode"; then
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
    prompt_template="${PROMPT_DIR}/changelog_prompt.md"
    print_debug "Building prompt from template: $prompt_template"
    tmp_prompt_file=$(portable_mktemp "changelog_prompt_XXXXXX")
    if ! build_prompt "$prompt_template" "$summaries_file" >"$tmp_prompt_file"; then
        printf 'Error: build_prompt failed\n' >&2
        rm -f "$summaries_file" "$tmp_prompt_file"
        exit 1
    fi

    # 5) Generate AI response
    response_file=$(portable_mktemp "changelog_response_XXXXXX")
    if ! generate_from_prompt "$tmp_prompt_file" "$response_file" "$model_mode"; then
        printf 'Error: generate_from_prompt failed\n' >&2
        rm -f "$summaries_file" "$tmp_prompt_file" "$response_file"
        exit 1
    fi

    # 6) Prepare for update_changelog
    tmp_out=$(portable_mktemp "changelog_temp_out_XXXXXX")
    # Ensure existing file (so cp won't fail on first run)
    if [ ! -f "$output_file" ]; then
        print_debug "Output file missing; creating empty $output_file"
        : >"$output_file"
    fi
    cp "$output_file" "$tmp_out"

    print_debug "Updating changelog (version=$output_version, mode=$output_mode)"

    # 7) Dry-run?
    if [ "${dry_run}" = "true" ]; then
        if ! update_changelog "$tmp_out" "$response_file" "$output_version" "$output_mode"; then
            printf 'Error: update_changelog failed\n' >&2
            rm -f "$summaries_file" "$tmp_prompt_file" "$response_file" "$tmp_out"
            exit 1
        fi
        print_debug "Dry run: updated changelog content:"
        cat "$tmp_out"
        rm -f "$summaries_file" "$tmp_prompt_file" "$response_file" "$tmp_out"
        return 0
    fi

    # 8) Write back to real changelog
    if update_changelog "$tmp_out" "$response_file" "$output_version" "$output_mode"; then
        if cat "$tmp_out" >"$output_file"; then
            printf 'Changelog written to %s\n' "$output_file"
        else
            printf 'Error: Failed to write %s\n' "$output_file" >&2
            rm -f "$summaries_file" "$tmp_prompt_file" "$response_file" "$tmp_out"
            exit 1
        fi
    else
        printf 'Error: update_changelog failed\n' >&2
        rm -f "$summaries_file" "$tmp_prompt_file" "$response_file" "$tmp_out"
        exit 1
    fi

    print_debug "Changelog generated successfully."
    rm -f "$summaries_file" "$tmp_prompt_file" "$response_file" "$tmp_out"
}

if [ "${_is_sourced}" -eq 0 ]; then
    portable_mktemp_dir
    parse_args "$@"

    # # Verify the PWD is a valid git repository
    # if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    #     printf 'Error: Current directory is not a valid git repository.\n'
    #     exit 1
    # fi
    # # Enable debug mode if requested
    # if [ "${debug}" = "true" ]; then
    #     set -x
    # fi

    # Dispatch logic
    case "${subcmd}" in
    summary) cmd_summary "${output_file}" "${REVISION}" "${model_mode}" "${dry_run}" ;;
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

    if [ -z "${GIV_TMPDIR_SAVE:-}" ]; then
        # Clean up temporary directory if it was created
        remove_tmp_dir
    fi
fi
