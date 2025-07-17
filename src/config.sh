# # References to Variables in the Codebase

# ## `changelog_file`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/commands.sh`, Line 112: `output_file="${output_file:-$changelog_file}"`
# - **File:** `src/commands.sh`, Line 113: `print_debug "Changelog file: $output_file"`

# ## `release_notes_file`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/giv.sh`, Line 161: `output_file:-$release_notes_file`

# ## `announce_file`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/giv.sh`, Line 168: `output_file:-$announce_file`

# ## `GIV_TMPDIR`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/system.sh`, Line 26: `if [ -n "$GIV_TMPDIR" ] && [ -d "$GIV_TMPDIR" ]; then`
# - **File:** `src/system.sh`, Line 32: `GIV_TMPDIR="" # Clear the variable`
# - **File:** `src/system.sh`, Line 45: `GIV_TMPDIR="$(mktemp -d -p "${base_path}")"`

# ## `GIV_REVISION`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 8: `revision Any Git revision or revision-range`
# - **File:** `src/commands.sh`, Line 120: `if ! summarize_target "$GIV_REVISION"`

# ## `GIV_PATHSPEC`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/commands.sh`, Line 58: `build_history "${hist}" "${commit_id}" "${todo_pattern}" "${GIV_PATHSPEC}"`

# ## `config_file`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 153: `if [ -n "${config_file}" ] && [ -f "${config_file}" ]; then`

# ## `is_config_loaded`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 156: `is_config_loaded=true`

# ## `debug`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/system.sh`, Line 7: `if [ "${debug:-}" = "true" ]; then`

# ## `GIV_DRY_RUN`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/commands.sh`, Line 190: `if [ "$GIV_DRY_RUN" = "true" ]; then`

# ## `GIV_TEMPLATE_DIR`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/giv.sh`, Line 85: `GIV_TEMPLATE_DIR="${GIV_TEMPLATE_DIR}"`

# ## `output_file`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/giv.sh`, Line 149: `output_file:-`

# ## `todo_pattern`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/history.sh`, Line 128: `todo_pattern="${3:-${GIV_TODO_PATTERN:-TODO}}"`

# ## `todo_files`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 25: `--todo-files GIV_PATHSPEC Pathspec for files to scan for TODOs`

# ## `subcmd`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/giv.sh`, Line 144: `case "${subcmd}" in`

# ## `output_mode`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/commands.sh`, Line 169: `print_debug "Updating changelog (version=$output_version, mode=$output_mode)"`

# ## `output_version`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/commands.sh`, Line 181: `"$output_version"`

# ## `GIV_VERSION_FILE`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/project.sh`, Line 83: `if [ -n "${GIV_VERSION_FILE}" ] && [ -f "${GIV_VERSION_FILE}" ]; then`

# ## `version_pattern`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/commands.sh`, Line 281: `version_pattern=$2`

# ## `prompt_file`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/giv.sh`, Line 147: `prompt_file`

# ## `model`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 31: `--model MODEL Local Ollama model name`

# ## `GIV_MODEL_MODE`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 32: `--model-mode MODE auto (default), local, remote, none`

# ## `api_model`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 33: `--api-model MODEL Remote model name when in remote mode`

# ## `api_url`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 330: `if [ -z "${api_url}" ]; then`

# ## `api_key`
# - **File:** `src/config.sh` (Definition)
# - **File:** `src/args.sh`, Line 325: `if [ -z "${api_key}" ]; then`


export GIV_TMPDIR=""
export GIV_TMPDIR_SAVE=""
export GIV_LIB_DIR="${GIV_LIB_DIR:-}"
export GIV_DOCS_DIR="${GIV_DOCS_DIR:-}"
export GIV_TEMPLATE_DIR="${GIV_TEMPLATE_DIR:-}"

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


# config_file=""
# is_config_loaded=false
# debug=false
# template_dir="${TEMPLATE_DIR}"
# output_file=''
# todo_pattern=''
# todo_files="*todo*"
# subcmd=''
# output_mode='auto'
# output_version='auto'
# version_file=''
# version_pattern=''
# prompt_file=''

