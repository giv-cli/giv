# GIV Configuration Variables
export __VERSION="0.3.0-beta"



## Default git revision and pathspec
export GIV_REVISION="--current"
export GIV_PATHSPEC=""

## Model and API configuration
export GIV_API_MODEL="${GIV_API_MODEL:-'devstral'}"
export GIV_API_URL="${GIV_API_URL:-'http://localhost:11434/v1/chat/completions'}"
export GIV_API_KEY="${GIV_API_KEY:-'giv'}"

## Project details
export GIV_METADATA_PROJECT_TYPE="${GIV_METADATA_PROJECT_TYPE:-auto}"
export GIV_PROJECT_VERSION_FILE="${GIV_PROJECT_VERSION_FILE:-}"
export GIV_PROJECT_VERSION_PATTERN="${GIV_PROJECT_VERSION_PATTERN:-}"
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



