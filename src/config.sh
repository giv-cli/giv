

export GIV_TOKEN_PROJECT_TITLE=""
export GIV_TOKEN_VERSION=""
export GIV_TOKEN_EXAMPLE=""
export GIV_TOKEN_RULES=""

# Changelog & release defaults
export changelog_file='CHANGELOG.md'
export release_notes_file='RELEASE_NOTES.md'
export announce_file='ANNOUNCEMENT.md'

GIV_TMPDIR=""
REVISION=""
PATHSPEC=""

config_file=""
is_config_loaded=false
debug=false
dry_run=""
template_dir="${TEMPLATE_DIR}"
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

