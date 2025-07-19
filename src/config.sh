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
export GIV_MODEL_MODE="${GIV_MODEL_MODE:-'auto'}"
export GIV_MODEL="${GIV_MODEL:-'devstral'}"
export GIV_API_MODEL="${GIV_API_MODEL:-}"
export GIV_API_URL="${GIV_API_URL:-}"
export GIV_API_KEY="${GIV_API_KEY:-}"

## Project details
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

# Validate GIV_MODEL_MODE
valid_modes="local remote none auto"
if ! echo "$valid_modes" | grep -qw "$GIV_MODEL_MODE"; then
    #print_debug "Invalid GIV_MODEL_MODE: $GIV_MODEL_MODE. Defaulting to 'local'."
    export GIV_MODEL_MODE="local"
fi

# # Ensure required templates exist
# required_templates="final_summary_prompt.md message_prompt.md changelog_prompt.md release_notes_prompt.md announcement_prompt.md"

# for template in $required_templates; do
#     if [ ! -f "$GIV_TEMPLATE_DIR/$template" ]; then
#         printf 'Error: Missing required template file: %s\n' "$GIV_TEMPLATE_DIR/$template" >&2
#         exit 1
#     fi
# done
