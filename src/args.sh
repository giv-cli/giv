show_help() {
    cat <<EOF
Usage: giv <subcommand> [revision] [pathspec] [OPTIONS]

Argument        Meaning
--------------- ------------------------------------------------------------------------------
revision        Any Git revision or revision-range (HEAD, v1.2.3, abc123, HEAD~2..HEAD, origin/main...HEAD, --cached, --current)
pathspec        Standard Git pathspec to narrow scope—supports magic prefixes, negation (! or :(exclude)), and case-insensitive :(icase)

Option Groups

General
  -h, --help            Show this help and exit
  -v, --version         Show giv version
  --verbose             Enable debug/trace output
  --dry-run             Preview only; don't write any files
  --config-file PATH    Shell config file to source before running

Revision & Path Selection (what to read)
  (positional) revision   Git revision or range
  (positional) pathspec   Git pathspec filter

Diff & Content Filters (what to keep)
  --todo-files PATHSPEC   Pathspec for files to scan for TODOs
  --todo-pattern REGEX    Regex to match TODO lines
  --version-file PATHSPEC Pathspec of file(s) to inspect for version bumps
  --version-pattern REGEX Custom regex to identify version strings

AI / Model (how to think)
  --model MODEL          Specify the local or remote model name
  --api-model MODEL      Remote model name
  --api-url URL          Remote API endpoint URL
  --api-key KEY          API key for remote mode

Output Behavior (where to write)
  --output-mode MODE     auto, prepend, append, update, none
  --output-version NAME  Override section header/tag name
  --output-file PATH     Destination file (defaults per subcommand)
  --prompt-file PATH     Markdown prompt template to use (required for 'document')

Maintenance Subcommands
  available-releases     List available script versions
  update                 Self-update giv to latest or specified version

Subcommands
  message                Draft an AI commit message (default)
  summary                Human-readable summary of changes
  changelog              Create or update CHANGELOG.md
  release-notes          Generate release notes for a tagged release
  announcement           Create a marketing-style announcement
  document               Generate custom content using your own prompt template
  init                   Initialize or update giv configuration
  config                 Initialize or update giv configuration values
  available-releases     List script versions
  update                 Self-update giv

Examples:
  giv message HEAD~3..HEAD src/
  giv summary --output-file SUMMARY.md
  giv changelog v1.0.0..HEAD --todo-files '*.js' --todo-pattern 'TODO:'
  giv release-notes v1.2.0..HEAD --api-model gpt-4o --api-url https://api.example.com
  giv announcement --output-file ANNOUNCE.md
  giv document --prompt-file templates/my_custom_prompt.md --output-file REPORT.md HEAD
EOF
    printf '\nFor more information, see the documentation at %s\n' "${DOCS_DIR:-<no docs dir>}"
}



# Parses command-line arguments passed to the script and sets corresponding
# variables or flags based on the provided options. Handles validation and
# error reporting for invalid or missing arguments.
#
# Usage:
#   parse_args "$@"
#
# Globals:
#   May set or modify global variables depending on parsed arguments.
#
# Arguments:
#   All command-line arguments passed to the script.
#
# Returns:
#   0 if parsing is successful, non-zero on error.
parse_args() {
    # Parse global options and subcommand first
    parse_global_args "$@"

    # Restore remaining arguments for subcommand-specific parsing
    set -- "$@"

    # Early config file parsing
    config_file="${GIV_HOME}/config"
    if [ -f "${config_file}" ]; then
        print_debug "Sourcing config file: ${config_file}"
        # shellcheck disable=SC1090
        . "${config_file}"
    fi

    print_debug "Setting initial variables"
    
    api_model="${GIV_API_MODEL:-'devstral'}"
    api_url="${GIV_API_URL:-}"
    api_key="${GIV_API_KEY:-}"
    print_debug "Initial API settings: $api_url"

    # Load config file if it exists
    is_config_loaded=false
    # Always attempt to source config file if it exists; empty config_file is a valid state.
    if [ -f "${config_file}" ]; then
        print_debug "Sourcing config file: ${config_file}"
        # shellcheck disable=SC1090
        . "${config_file}"
        print_debug "Loaded config file: ${config_file}"
        is_config_loaded=true
        elif [ ! -f "${config_file}" ] && [ "${config_file}" != "${PWD}/.env" ]; then
        print_warn "config file ${config_file} not found."
    else
        print_debug "No config file specified or found, using defaults."
    fi
    
    api_model=${GIV_API_MODEL:-${api_model}}
    api_url=${GIV_API_URL:-${api_url}}
    api_key=${GIV_API_KEY:-${api_key}}
    
    debug="${GIV_DEBUG:-}"
    output_file="${GIV_OUTPUT_FILE:-}"
    todo_pattern="${GIV_TODO_PATTERN:-}"
    todo_files="${GIV_TODO_FILES:-*todo*}"
    output_mode="${GIV_OUTPUT_MODE:-auto}"
    output_version="${GIV_OUTPUT_VERSION:-auto}"
    version_file="${GIV_PROJECT_VERSION_FILE:-}"
    version_pattern="${GIV_PROJECT_VERSION_PATTERN:-}"
    prompt_file="${GIV_PROMPT_FILE:-}"
    
    print_debug "Parsing revision"
    # 2. Next arg: revision (if present and not option)
    if [ $# -gt 0 ]; then
        case "$1" in
            --current | --staged | --cached)
                if [ "$1" = "--staged" ]; then
                    GIV_REVISION="--cached"
                else
                    GIV_REVISION="$1"
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
                        GIV_REVISION="$1"
                        # If it's a valid commit ID, shift it
                        print_debug "Valid commit range: $1"
                        shift
                    else
                        print_error "Invalid commit range: $1"
                        exit 1
                    fi
                    elif git rev-parse --verify "$1" >/dev/null 2>&1; then
                    GIV_REVISION="$1"
                    # If it's a valid commit ID, shift it
                    print_debug "Valid commit ID: $1"
                    shift
                else
                    print_error "Invalid target: $1"
                    exit 1
                fi
                # else: do not shift, let it fall through to pattern parsing
            ;;
        esac
    fi
    
    if [ -z "${GIV_REVISION}" ]; then
        # If no target specified, default to current working tree
        print_debug "Debug: No target specified, defaulting to current working tree."
        GIV_REVISION="--current"
    fi

        print_debug "Parsing revision"
        # 3. Collect all non-option args as pattern (until first option or end)
        # Only collect pathspec if there are non-option args left AND they are not files like the script itself
        while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do
            # Avoid setting pathspec to the script name itself (e.g., install.sh)
            if [ "$1" = "$(basename "$0")" ]; then
                print_debug "Skipping script name argument: $1"
                shift
                continue
            fi
            print_debug "Collecting pattern: $1"
            if [ -z "${GIV_PATHSPEC}" ]; then
                GIV_PATHSPEC="$1"
            else
                GIV_PATHSPEC="${GIV_PATHSPEC} $1"
            fi
            shift
        done
    
    print_debug "Target and pattern parsed: ${GIV_REVISION}, ${GIV_PATHSPEC}"
    
    # 4. Remaining args: global options
    while [ $# -gt 0 ]; do
        case "$1" in
            --verbose)
                debug="true"
                shift
            ;;
            --dry-run)
                GIV_DRY_RUN="true"
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
            --model)
                api_model=$2
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
            --api-key)
                api_key=$2
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
    
    print_debug "Parsed options"
    
    # If subcommand is document, ensure we have a prompt file
    if [ "${subcmd}" = "document" ] && [ -z "${prompt_file}" ]; then
        printf 'Error: --prompt-file is required for the document subcommand.\n' >&2
        exit 1
    fi

    print_debug "Set global variables:"
    GIV_TODO_FILES="${todo_files:-}"
    GIV_TODO_PATTERN="${todo_pattern:-}"
    GIV_API_MODEL="${api_model:-}"
    GIV_API_URL="${api_url:-}"
    GIV_API_KEY="${api_key:-}"
    GIV_OUTPUT_FILE="${output_file:-}"
    GIV_OUTPUT_MODE="${output_mode:-}"
    GIV_OUTPUT_VERSION="${output_version:-}"
    GIV_PROMPT_FILE="${prompt_file:-}"  # Default to empty if unset
    GIV_PROJECT_VERSION_FILE="${version_file:-}"
    GIV_PROJECT_VERSION_PATTERN="${version_pattern:-}"  # Default to empty if unset
    GIV_CONFIG_FILE="${config_file}"
    GIV_DEBUG="${debug:-}"
    print_debug "Global variables set"

    print_debug "Environment variables:"
    print_debug "  GIV_HOME: ${GIV_HOME:-}"
    print_debug "  GIV_TMP_DIR: ${GIV_TMP_DIR:-}"
    print_debug "  GIV_TMPDIR_SAVE: ${GIV_TMPDIR_SAVE:-}"
    print_debug "  GIV_API_MODEL: ${GIV_API_MODEL:-}"
    print_debug "  GIV_API_URL: ${GIV_API_URL:-}"
    print_debug "Parsed options:"
    print_debug "  Debug: ${GIV_DEBUG}"
    print_debug "  Dry Run: ${GIV_DRY_RUN}"
    print_debug "  Subcommand: ${subcmd}"
    print_debug "  Revision: ${GIV_REVISION}"
    print_debug "  Pathspec: ${GIV_PATHSPEC}"
    print_debug "  Template Directory: ${GIV_TEMPLATE_DIR:-}"
    print_debug "  Config File: ${GIV_CONFIG_FILE}"
    print_debug "  Config Loaded: ${is_config_loaded}"
    print_debug "  TODO Files: ${GIV_TODO_FILES}"
    print_debug "  TODO Pattern: ${GIV_TODO_PATTERN:-}"
    print_debug "  Version File: ${GIV_PROJECT_VERSION_FILE:-}"
    print_debug "  Version Pattern: ${GIV_PROJECT_VERSION_PATTERN:-}"
    print_debug "  API Model: ${GIV_API_MODEL:-}"
    print_debug "  API URL: ${GIV_API_URL:-}"
    print_debug "  Output File: ${GIV_OUTPUT_FILE:-}"
    print_debug "  Output Mode: ${GIV_OUTPUT_MODE:-}"
    print_debug "  Output Version: ${GIV_OUTPUT_VERSION:-}"
    print_debug "  Prompt File: ${GIV_PROMPT_FILE:-}"
}

# Parses global options and the subcommand
parse_global_args() {
    subcmd=''

    # Check if no arguments are provided
    if [ $# -eq 0 ]; then
        print_error "No arguments provided."
        exit 1
    fi

    # Parse the first argument as a subcommand or help/version
    case "$1" in
        -h | --help | help)
            show_help
            exit 0
        ;;
        -v | --version)
            show_version
            exit 0
        ;;
        message | msg | summary | changelog \
        | document | doc | release-notes | announcement \
        | available-releases | update | init | config)
            subcmd=$1
            shift
        ;;
        *)
            echo "First argument must be a subcommand or -h/--help/-v/--version"
            show_help
            exit 1
        ;;
    esac

    # Preserve remaining arguments for later parsing
    set -- "$@"

    # Parse global options
    while [ $# -gt 0 ]; do
        case "$1" in
            --verbose)
                GIV_DEBUG="true"
                shift
            ;;
            --dry-run)
                GIV_DRY_RUN="true"
                shift
            ;;
            --config-file)
                config_file=$2
                shift 2
            ;;
            --config-file=*)
                config_file="${1#--config-file=}"
                shift
            ;;
            *)
                # Stop parsing on the first non-global option
                break
            ;;
        esac
    done

    # Export parsed global variables
    export GIV_DEBUG
    export GIV_DRY_RUN
    export config_file
    export subcmd
}


