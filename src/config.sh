# Updated references to variables in the codebase
# ## `changelog_file`
# - **File:** `src/config.sh`, Line 148: `export changelog_file='CHANGELOG.md'`
# - **File:** `src/commands.sh`, Line 117: `output_file="${output_file:-$changelog_file}"`
# - **File:** `src/commands.sh`, Line 118: `print_debug "Changelog file: $output_file"`
# - **File:** `tests/test_commands.bats`, Line 47: `# changelog_file="changelog.out"`

# ## `release_notes_file`
# - **File:** `src/config.sh`, Line 149: `export release_notes_file='RELEASE_NOTES.md'`
# - **File:** `src/giv.sh`, Line 169: `"${output_file:-$release_notes_file}" \\

# ## `announce_file`
# - **File:** `src/config.sh`, Line 150: `export announce_file='ANNOUNCEMENT.md'`
# - **File:** `src/giv.sh`, Line 177: `"${output_file:-$announce_file}" \\
# - **File:** `tests/test_commands.bats`, Line 46: `# announce_file="announce.out"`

# ## `GIV_TMP_DIR`
# - **File:** `src/config.sh`, Line 113: `export GIV_TMP_DIR="${GIV_TMP_DIR:-}"`
# - **File:** `src/system.sh`, Line 26: `if [ -n "$GIV_TMP_DIR" ] && [ -d "$GIV_TMP_DIR" ]; then`
# - **File:** `src/system.sh`, Line 32: `GIV_TMP_DIR="" # Clear the variable`
# - **File:** `src/system.sh`, Line 45: `GIV_TMP_DIR="$(mktemp -d -p "${base_path}")"`
# - **File:** `src/args.sh`, Line 390: `print_debug "  GIV_TMP_DIR: ${GIV_TMP_DIR:-}"`

# ## `GIV_REVISION`
# - **File:** `src/config.sh`, Line 124: `export GIV_REVISION="--current"`
# - **File:** `src/args.sh`, Line 192: `GIV_REVISION="--cached"`
# - **File:** `src/args.sh`, Line 245: `print_debug "Target and pattern parsed: ${GIV_REVISION}, ${GIV_PATHSPEC}"`
# - **File:** `src/giv.sh`, Line 147: `message | msg) cmd_message "${GIV_REVISION}" \\

# ## `GIV_PATHSPEC`
# - **File:** `src/config.sh`, Line 125: `export GIV_PATHSPEC=""`
# - **File:** `src/args.sh`, Line 237: `if [ -z "${GIV_PATHSPEC}" ]; then`
# - **File:** `src/args.sh`, Line 245: `print_debug "Target and pattern parsed: ${GIV_REVISION}, ${GIV_PATHSPEC}"`
# - **File:** `src/giv.sh`, Line 148: `"${GIV_PATHSPEC}" \\

# ## `config_file`
# - **File:** `src/config.sh`, Line 142: `export GIV_CONFIG_FILE="${GIV_CONFIG_FILE:-}"`
# - **File:** `src/args.sh`, Line 153: `if [ -n "${config_file}" ] && [ -f "${config_file}" ]; then`
# - **File:** `src/args.sh`, Line 402: `print_debug "  Config File: ${GIV_CONFIG_FILE}"`

# ## `is_config_loaded`
# - **File:** `src/config.sh`, Line 154: `# is_config_loaded=false`
# - **File:** `src/args.sh`, Line 175: `is_config_loaded=true`
# - **File:** `src/args.sh`, Line 403: `print_debug "  Config Loaded: ${is_config_loaded}"`

# ## `debug`
# - **File:** `src/config.sh`, Line 143: `export GIV_DEBUG="${GIV_DEBUG:-}"`
# - **File:** `src/args.sh`, Line 92: `debug="${GIV_DEBUG:-}"`
# - **File:** `src/args.sh`, Line 386: `GIV_DEBUG="${debug:-GIV_DEBUG}"`
# - **File:** `src/args.sh`, Line 371: `print_debug "Set global variables:"`

# ## `GIV_DRY_RUN`
# - **File:** `src/config.sh`, Line 128: `export GIV_DRY_RUN="${GIV_DRY_RUN:-}"`
# - **File:** `src/args.sh`, Line 255: `GIV_DRY_RUN="true"`
# - **File:** `src/args.sh`, Line 397: `print_debug "  Dry Run: ${GIV_DRY_RUN}"`
# - **File:** `src/commands.sh`, Line 198: `if [ "$GIV_DRY_RUN" = "true" ]; then`

# ## `GIV_TEMPLATE_DIR`
# - **File:** `src/config.sh`, Line 111: `export GIV_TEMPLATE_DIR="${GIV_TEMPLATE_DIR:-}"`
# - **File:** `src/giv.sh`, Line 85: `GIV_TEMPLATE_DIR="${GIV_TEMPLATE_DIR}"`
# - **File:** `src/args.sh`, Line 401: `print_debug "  Template Directory: ${GIV_TEMPLATE_DIR:-}"`

# ## `output_file`
# - **File:** `src/config.sh`, Line 136: `export GIV_OUTPUT_FILE="${GIV_OUTPUT_FILE:-}"`
# - **File:** `src/args.sh`, Line 93: `output_file="${GIV_OUTPUT_FILE:-}"`
# - **File:** `src/args.sh`, Line 412: `print_debug "  Output File: ${GIV_OUTPUT_FILE:-}"`
# - **File:** `src/giv.sh`, Line 155: `"${output_file:-}" \\

# ## `todo_pattern`
# - **File:** `src/config.sh`, Line 117: `export GIV_TODO_PATTERN="${GIV_TODO_PATTERN:-}"`
# - **File:** `src/args.sh`, Line 94: `todo_pattern="${GIV_TODO_PATTERN:-}"`
# - **File:** `src/args.sh`, Line 405: `print_debug "  TODO Pattern: ${GIV_TODO_PATTERN:-}"`
# - **File:** `src/history.sh`, Line 128: `todo_pattern="${3:-${GIV_TODO_PATTERN:-TODO}}"`

# ## `todo_files`
# - **File:** `src/config.sh`, Line 118: `export GIV_TODO_FILES="${GIV_TODO_FILES:-*todo*}"`
# - **File:** `src/args.sh`, Line 95: `todo_files="${GIV_TODO_FILES:-*todo*}"`
# - **File:** `src/args.sh`, Line 404: `print_debug "  TODO Files: ${GIV_TODO_FILES}"`

# ## `subcmd`
# - **File:** `src/config.sh`, Line 160: `# subcmd=''`
# - **File:** `src/args.sh`, Line 96: `subcmd=''`
# - **File:** `src/args.sh`, Line 398: `print_debug "  Subcommand: ${subcmd}"`
# - **File:** `src/giv.sh`, Line 146: `case "${subcmd}" in`

# ## `output_mode`
# - **File:** `src/config.sh`, Line 137: `export GIV_OUTPUT_MODE="${GIV_OUTPUT_MODE:-}"`
# - **File:** `src/args.sh`, Line 97: `output_mode="${GIV_OUTPUT_MODE:-auto}"`
# - **File:** `src/args.sh`, Line 413: `print_debug "  Output Mode: ${GIV_OUTPUT_MODE:-}"`
# - **File:** `src/commands.sh`, Line 121: `output_mode="$GIV_OUTPUT_MODE"`

# ## `output_version`
# - **File:** `src/config.sh`, Line 138: `export GIV_OUTPUT_VERSION="${GIV_OUTPUT_VERSION:-}"`
# - **File:** `src/args.sh`, Line 98: `output_version="${GIV_OUTPUT_VERSION:-auto}"`
# - **File:** `src/args.sh`, Line 414: `print_debug "  Output Version: ${GIV_OUTPUT_VERSION:-}"`
# - **File:** `src/commands.sh`, Line 120: `output_version="$GIV_OUTPUT_VERSION"`

# ## `GIV_VERSION_FILE`
# - **File:** `src/config.sh`, Line 140: `export GIV_VERSION_FILE="${GIV_VERSION_FILE:-}"`
# - **File:** `src/args.sh`, Line 99: `version_file="${GIV_VERSION_FILE:-}"`
# - **File:** `src/args.sh`, Line 406: `print_debug "  Version File: ${GIV_VERSION_FILE:-}"`
# - **File:** `src/project.sh`, Line 83: `if [ -n "${GIV_VERSION_FILE}" ] && [ -f "${GIV_VERSION_FILE}" ]; then`

# ## `version_pattern`
# - **File:** `src/config.sh`, Line 141: `export GIV_VERSION_PATTERN="${GIV_VERSION_PATTERN:-}"`
# - **File:** `src/args.sh`, Line 100: `version_pattern="${GIV_VERSION_PATTERN:-}"`
# - **File:** `src/args.sh`, Line 407: `print_debug "  Version Pattern: ${GIV_VERSION_PATTERN:-}"`
# - **File:** `src/commands.sh`, Line 281: `version_pattern=$2`

# ## `prompt_file`
# - **File:** `src/config.sh`, Line 139: `export GIV_PROMPT_FILE="${GIV_PROMPT_FILE:-}"`
# - **File:** `src/args.sh`, Line 101: `prompt_file="${GIV_PROMPT_FILE:-}"`
# - **File:** `src/args.sh`, Line 415: `print_debug "  Prompt File: ${GIV_PROMPT_FILE:-}"`
# - **File:** `src/giv.sh`, Line 152: `"${prompt_file}" \\

# ## `model`
# - **File:** `src/config.sh`, Line 129: `export GIV_MODEL="${GIV_MODEL:-'devstral'}"`
# - **File:** `src/args.sh`, Line 87: `model=${GIV_MODEL:-'devstral'}`
# - **File:** `src/args.sh`, Line 372: `GIV_MODEL_MODE="${model_mode:-GIV_MODEL_MODE}"`
# - **File:** `src/args.sh`, Line 409: `print_debug "  Model Mode: ${GIV_MODEL_MODE:-}"`

# ## `GIV_MODEL_MODE`
# - **File:** `src/config.sh`, Line 130: `export GIV_MODEL_MODE="${GIV_MODEL_MODE:-'auto'}"`
# - **File:** `src/args.sh`, Line 88: `model_mode=${GIV_MODEL_MODE:-'auto'}`
# - **File:** `src/args.sh`, Line 391: `print_debug "  GIV_MODEL_MODE: ${GIV_MODEL_MODE:-}"`
# - **File:** `src/giv.sh`, Line 150: `"${GIV_MODEL_MODE}" ;;

# ## `api_model`
# - **File:** `src/config.sh`, Line 131: `export GIV_API_MODEL="${GIV_API_MODEL:-}"`
# - **File:** `src/args.sh`, Line 89: `api_model=${GIV_API_MODEL:-}`
# - **File:** `src/args.sh`, Line 410: `print_debug "  API Model: ${GIV_API_MODEL:-}"`
# - **File:** `src/llm.sh`, Line 124: `"${GIV_API_MODEL}" "${escaped_content}")`

# ## `api_url`
# - **File:** `src/config.sh`, Line 132: `export GIV_API_URL="${GIV_API_URL:-}"`
# - **File:** `src/args.sh`, Line 90: `api_url=${GIV_API_URL:-}`
# - **File:** `src/args.sh`, Line 411: `print_debug "  API URL: ${GIV_API_URL:-}"`
# - **File:** `src/llm.sh`, Line 127: `response=$(curl -s -X POST "${GIV_API_URL}" \\

# ## `api_key`
# - **File:** `src/config.sh`, Line 133: `export GIV_API_KEY="${GIV_API_KEY:-}"`
# - **File:** `src/args.sh`, Line 91: `api_key=${GIV_API_KEY:-}`
# - **File:** `src/args.sh`, Line 378: `GIV_API_KEY="${api_key:-GIV_API_KEY}"`
# - **File:** `src/llm.sh`, Line 128: `-H "Authorization: Bearer ${GIV_API_KEY}" \\`

# These values are typically set in the main script or environment
# We export them here to ensure they are available globally
export GIV_LIB_DIR="${GIV_LIB_DIR:-}"
export GIV_DOCS_DIR="${GIV_DOCS_DIR:-}"
export GIV_TEMPLATE_DIR="${GIV_TEMPLATE_DIR:-}"
export GIV_HOME="${GIV_HOME:-$(pwd)/.giv}"

export GIV_TMP_DIR="${GIV_TMP_DIR:-$GIV_HOME/.tmp}"
export GIV_TMPDIR_SAVE="${GIV_TMPDIR_SAVE:-true}"
export GIV_CACHE_DIR="${GIV_CACHE_DIR:-$GIV_HOME/cache}"


export GIV_TODO_PATTERN="${GIV_TODO_PATTERN:-}"
export GIV_TODO_FILES="${GIV_TODO_FILES:-*todo*}"
export GIV_TOKEN_PROJECT_TITLE="${GIV_TOKEN_PROJECT_TITLE:-}"
export GIV_TOKEN_VERSION="${GIV_TOKEN_VERSION:-}"
export GIV_TOKEN_EXAMPLE="${GIV_TOKEN_EXAMPLE:-}"
export GIV_TOKEN_RULES="${GIV_TOKEN_RULES:-}"

export GIV_REVISION="--current"
export GIV_PATHSPEC=""


export GIV_DRY_RUN="${GIV_DRY_RUN:-}"
export GIV_MODEL="${GIV_MODEL:-'devstral'}"
export GIV_MODEL_MODE="${GIV_MODEL_MODE:-'auto'}"
export GIV_API_MODEL="${GIV_API_MODEL:-}"
export GIV_API_URL="${GIV_API_URL:-}"
export GIV_API_KEY="${GIV_API_KEY:-}"


export GIV_OUTPUT_FILE="${GIV_OUTPUT_FILE:-}"
export GIV_OUTPUT_MODE="${GIV_OUTPUT_MODE:-}"
export GIV_OUTPUT_VERSION="${GIV_OUTPUT_VERSION:-}"
export GIV_PROMPT_FILE="${GIV_PROMPT_FILE:-}"
export GIV_VERSION_FILE="${GIV_VERSION_FILE:-}"
export GIV_VERSION_PATTERN="${GIV_VERSION_PATTERN:-}"
export GIV_CONFIG_FILE="${GIV_CONFIG_FILE:-}"
export GIV_DEBUG="${GIV_DEBUG:-}"
export GIV_DRY_RUN="${GIV_DRY_RUN:-}"


# Changelog & release defaults
export changelog_file='CHANGELOG.md'
export release_notes_file='RELEASE_NOTES.md'
export announce_file='ANNOUNCEMENT.md'
