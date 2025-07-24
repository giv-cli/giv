

# -------------------------------------------------------------------
# Logging helpers
# -------------------------------------------------------------------
print_debug() {
    if [ "${GIV_DEBUG:-}" = "true" ]; then
        printf 'DEBUG: %s\n' "$*" >&2
    fi
}
print_info() {
    printf 'INFO: %s\n' "$*" >&2
}
print_warn() {
    printf 'WARNING: %s\n' "$*" >&2
}
print_error() {
    printf 'ERROR: %s\n' "$*" >&2
}
print_plain() {
    printf '%s\n' "$*" >&2
}
# This function prints a markdown file using the 'glow' command.
#
# Usage: print_md_file <file>
#
# Arguments:
#   <file> - The path to the markdown file to be printed.
#
# Returns:
#   0 on success, 1 if no argument is provided or the file does not exist.
print_md_file() {
    ensure_glow
    if [ -z "$1" ]; then
        echo "Usage: view_md <file>"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo "File not found: $1"
        return 1
    fi
    
    glow "$1"
}

# Added a new helper function to handle Markdown output.

print_md() {
    if command -v glow >/dev/null 2>&1; then
        glow -   # read from stdin
    else
        cat -
    fi
}

# -------------------------------------------------------------------
# Filesystem helpers
# -------------------------------------------------------------------
remove_tmp_dir() {
    if [ -z "${GIV_TMPDIR_SAVE:-}" ]; then
        print_debug "Removing temporary directory: ${GIV_TMP_DIR}"
        
        # Remove the temporary directory if it exists
        if [ -n "${GIV_TMP_DIR}" ] && [ -d "${GIV_TMP_DIR}" ]; then
            rm -rf "${GIV_TMP_DIR}"
            print_debug "Removed temporary directory ${GIV_TMP_DIR}"
        else
            print_debug 'No temporary directory to remove.'
        fi
        GIV_TMP_DIR="" # Clear the variable
    else
        print_debug "Preserving temporary directory: ${GIV_TMP_DIR}"
        return 0
    fi
}

# Portable mktemp: fallback if mktemp not available
portable_mktemp_dir() {
    base_path="${GIV_TMP_DIR:-TMPDIR:-${GIV_HOME}/tmp}"
    mkdir -p "${base_path}"
    
    # Ensure only one subfolder under $TMPDIR/giv exists per execution of the script
    # If GIV_TMP_DIR is not set, create a new temporary directory
    if [ -z "${GIV_TMP_DIR}" ]; then
        
        if command -v mktemp >/dev/null 2>&1; then
            GIV_TMP_DIR="$(mktemp -d -p "${base_path}")"
        else
            GIV_TMP_DIR="${base_path}/giv.$$.$(date +%s)"
            mkdir -p "${GIV_TMP_DIR}"
        fi
        
    fi
}

# Portable mktemp: fallback if mktemp not available
portable_mktemp() {
    [ -z "${GIV_TMP_DIR}" ] && portable_mktemp_dir
    
    mkdir -p "${GIV_TMP_DIR}"
    
    local tmpfile
    if command -v mktemp >/dev/null 2>&1; then
       tmpfile=$(mktemp "${GIV_TMP_DIR}/$1")
    else
        tmpfile="${GIV_TMP_DIR}/giv.$$.$(date +%s)"
    fi
    printf '%s\n' "$tmpfile"

    # Only clean up the temp file, not the whole temp dir
    trap 'rm -f "$tmpfile"' EXIT
}

load_env_file() {
    # Try to load .env from current directory
    env_file="${PWD}/.env"

    # If not found, try to find git root and load .env from there
    if [ ! -f "${env_file}" ]; then
        if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
            env_file="${git_root}/.env"
        fi
    fi

    if [ -f "${env_file}" ]; then
        print_debug "Sourcing environment file: ${env_file}"
        # shellcheck disable=SC1090
        . "${env_file}"
        print_debug "Loaded environment file: ${env_file}"
    else
        print_debug "No .env file found in current directory or git root."
    fi
}

find_giv_dir() {
    dir=$(pwd)
    while [ "${dir}" != "/" ]; do
        if [ -d "${dir}/.giv" ]; then
            printf '%s\n' "${dir}/.giv"
            return 0
        fi
        dir=$(dirname "${dir}")
    done
    printf '%s\n' "$(pwd)/.giv"
}


# Function to ensure .giv directory is initialized
ensure_giv_dir_init() {
    
    [ -z "${GIV_HOME:-}" ] && GIV_HOME="$(find_giv_dir)"
    
    if [ ! -d "${GIV_HOME}" ]; then
        print_debug "Initializing .giv directory..."
        mkdir -p "${GIV_HOME}"
    fi

    [ ! -f "${GIV_HOME}/config" ] && cp "${GIV_DOCS_DIR}/config.example" "${GIV_HOME}/config"
    mkdir -p "${GIV_HOME}" "${GIV_HOME}/cache" "${GIV_HOME}/.tmp" "${GIV_HOME}/templates"
}

initialize_metadata() {
    if [ "${1:-}" = "true" ] || [ "$(${GIV_LIB_DIR}/commands/config.sh initialized)" != "true" ]; then
        printf "Initializing Giv for this repository...\n"
        # Detect project type, version file, and version pattern
        detect_project_type

        printf "Project Name: "
        read -r project_name
        printf "Project Description:\n"
        read -r project_description
        printf "Project URL: "
        read -r project_url

        existing_name="$("${GIV_LIB_DIR}"/commands/config.sh --get project.title || basename "$(pwd)")"
        "${GIV_LIB_DIR}"/commands/config.sh project.title "${project_name:-$existing_name}"
        "${GIV_LIB_DIR}"/commands/config.sh project.description "${project_description:-}"
        "${GIV_LIB_DIR}"/commands/config.sh project.url "$project_url"


        # TODO: setup API URL and Model by prompting user or using defaults
        printf 'What is your OpenAI API compatible URL?\n'
        printf 'Open AI: https://api.openai.com/v1/chat/completions\n'
        printf 'Ollama (default): http://localhost:11434/v1/chat/completions\n'
        read -r api_url
        "${GIV_LIB_DIR}"/commands/config.sh api.url "${api_url:-http://localhost:11434/v1/chat/completions}"

        printf "What model do you want to use?\n"
        printf 'Ollama (default): devstral\n'
        read -r model
        "${GIV_LIB_DIR}"/commands/config.sh api.model "${model:-devstral}"

        "${GIV_LIB_DIR}"/commands/config.sh initialized true
        printf "Metadata has been set in the Git config.\n"

    else
        print_debug "Giv is already initialized. Fetching metadata from Git config..."
        project_name="$("${GIV_LIB_DIR}"/commands/config.sh project.title)"
        print_debug "Project Name: ${project_name}"
        project_description="$("${GIV_LIB_DIR}"/commands/config.sh project.description)"
        print_debug "Project Description: ${project_description}"
        project_url="$("${GIV_LIB_DIR}"/commands/config.sh project.url)"
        print_debug "Project URL: ${project_url}"
    fi
}

############################################################
# Project type detection
############################################################
# Sets "${GIV_LIB_DIR}"/commands/config.sh values:
#   project.type
#   version.file
#   version.pattern
detect_project_type() {
    # List of known project types and their identifying files
    if [ -f "package.json" ]; then
        "${GIV_LIB_DIR}"/commands/config.sh project.type "node"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_file "package.json"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_pattern '"version"[[:space:]]*:[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Node.js project."
        return
    elif [ -f "pyproject.toml" ]; then
        "${GIV_LIB_DIR}"/commands/config.sh project.type "python"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_file "pyproject.toml"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_pattern '^version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Python project (pyproject.toml)."
        return
    elif [ -f "setup.py" ]; then
        "${GIV_LIB_DIR}"/commands/config.sh project.type "python"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_file "setup.py"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_pattern 'version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Python project (setup.py)."
        return
    elif [ -f "Cargo.toml" ]; then
        "${GIV_LIB_DIR}"/commands/config.sh project.type "rust"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_file "Cargo.toml"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_pattern '^version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Rust project."
        return
    elif [ -f "composer.json" ]; then
        "${GIV_LIB_DIR}"/commands/config.sh project.type "php"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_file "composer.json"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_pattern '"version"[[:space:]]*:[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected PHP project."
        return
    elif [ -f "build.gradle" ]; then
        "${GIV_LIB_DIR}"/commands/config.sh project.type "gradle"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_file "build.gradle"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_pattern 'version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Gradle project."
        return
    elif [ -f "pom.xml" ]; then
        "${GIV_LIB_DIR}"/commands/config.sh project.type "maven"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_file "pom.xml"
        "${GIV_LIB_DIR}"/commands/config.sh project.version_pattern '<version>([0-9]+\\.[0-9]+\\.[0-9]+)</version>'
        print_debug "Detected Maven project."
        return
    # elif [ -f "src/giv.sh" ]; then
    #     "${GIV_LIB_DIR}"/commands/config.sh project.type "custom"
    #     "${GIV_LIB_DIR}"/commands/config.sh project.version_file "src/config.sh"
    #     "${GIV_LIB_DIR}"/commands/config.sh project.version_pattern 'version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
    #     print_debug "Detected Custom project."
    #     return
    else
        "${GIV_LIB_DIR}"/commands/config.sh project.type "custom"
        print_debug "Project type could not be detected. Defaulting to 'custom'."
        printf 'Project type could not be detected.\n'
        printf 'Please enter a path that contains the version of this project.\n'
        read -r version_file
        "${GIV_LIB_DIR}"/commands/config.sh project.version.file "$version_file"
        
        # shellcheck disable=SC2016
        "${GIV_LIB_DIR}"/commands/config.sh project.version.pattern "version[[:space:]]*=[[:space:]]*\"([0-9]+\\.[0-9]+\\.[0-9]+)"

    fi
}

is_valid_git_range() {
    git rev-list "$1" >/dev/null 2>&1
}

is_valid_pattern() {
    git ls-files --error-unmatch "$1" >/dev/null 2>&1
}
