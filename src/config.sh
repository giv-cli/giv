# GIV Configuration Variables
export __VERSION="0.3.0-beta"

## Directory locations
export GIV_LIB_DIR="${GIV_LIB_DIR:-}"
export GIV_DOCS_DIR="${GIV_DOCS_DIR:-}"
export GIV_TEMPLATE_DIR="${GIV_TEMPLATE_DIR:-}"
export GIV_HOME="${GIV_HOME:-$(pwd)/.giv}"
export GIV_TMP_DIR="${GIV_TMP_DIR:-$GIV_HOME/.tmp}"
export GIV_CACHE_DIR="${GIV_CACHE_DIR:-$GIV_HOME/cache}"
export GIV_CONFIG_FILE="${GIV_CONFIG_FILE:-}"

## Debugging
export GIV_DEBUG="${GIV_DEBUG:-}"
export GIV_DRY_RUN="${GIV_DRY_RUN:-}"
export GIV_TMPDIR_SAVE="${GIV_TMPDIR_SAVE:-true}"

## Default git revision and pathspec
export GIV_REVISION="--current"
export GIV_PATHSPEC=""

## Model and API configuration
export GIV_API_MODEL="${GIV_API_MODEL:-'devstral'}"
export GIV_API_URL="${GIV_API_URL:-'http://localhost:11434/v1/chat/completions'}"
export GIV_API_KEY="${GIV_API_KEY:-'giv'}"

## Project details
export GIV_METADATA_PROJECT_TYPE="${GIV_METADATA_PROJECT_TYPE:-auto}"
export GIV_VERSION_FILE="${GIV_VERSION_FILE:-}"
export GIV_VERSION_PATTERN="${GIV_VERSION_PATTERN:-}"
export GIV_TODO_PATTERN="${GIV_TODO_PATTERN:-}"
export GIV_TODO_FILES="${GIV_TODO_FILES:-*todo*}"

## Prompt file and tokens
export GIV_PROMPT_FILE="${GIV_PROMPT_FILE:-}"
export GIV_TOKEN_PROJECT_TITLE="${GIV_TOKEN_PROJECT_TITLE:-}"
export GIV_TOKEN_VERSION="${GIV_TOKEN_VERSION:-}"
export GIV_TOKEN_EXAMPLE="${GIV_TOKEN_EXAMPLE:-}"
export GIV_TOKEN_RULES="${GIV_TOKEN_RULES:-}"

## Output configuration
export GIV_OUTPUT_FILE="${GIV_OUTPUT_FILE:-}"
export GIV_OUTPUT_MODE="${GIV_OUTPUT_MODE:-}"
export GIV_OUTPUT_VERSION="${GIV_OUTPUT_VERSION:-}"

### Changelog & release default output files
export changelog_file='CHANGELOG.md'
export release_notes_file='RELEASE_NOTES.md'
export announce_file='ANNOUNCEMENT.md'

# Validate GIV_TEMPLATE_DIR
if [ -z "$GIV_TEMPLATE_DIR" ]; then
    GIV_TEMPLATE_DIR="$GIV_HOME/templates"
    mkdir -p "$GIV_TEMPLATE_DIR"
    #print_debug "GIV_TEMPLATE_DIR not set. Defaulting to: $GIV_TEMPLATE_DIR"
fi

if [ ! -d "$GIV_TEMPLATE_DIR" ]; then
    printf 'Error: GIV_TEMPLATE_DIR does not point to a valid directory: %s\n' "$GIV_TEMPLATE_DIR" >&2
    exit 1
fi


load_config_file(){
    config_file="${1:-GIV_CONFIG_FILE:-${PWD}/.giv/config}"
    env_file="${PWD}/.env"

    if [ -f "${env_file}" ]; then
        print_debug "Sourcing environment file: ${env_file}"
        # shellcheck disable=SC1090
        . "${env_file}"
        print_debug "Loaded environment file: ${env_file}"
    else
        print_debug "Environment file ${env_file} not found, skipping."
    fi
        # Always attempt to source config file if it exists; empty config_file is a valid state.
    if [ -f "${config_file}" ]; then
        print_debug "Sourcing config file: ${config_file}"
        # shellcheck disable=SC1090
        . "${config_file}"
        print_debug "Loaded config file: ${config_file}"
    elif [ ! -f "${config_file}" ] && [ "${config_file}" != "${PWD}/.env" ]; then
        print_warn "config file ${config_file} not found."
    else
        print_debug "No config file specified or found, using defaults."
    fi
}