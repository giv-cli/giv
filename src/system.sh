

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
    
    if command -v mktemp >/dev/null 2>&1; then
        mktemp "${GIV_TMP_DIR}/$1"
    else
        echo "${GIV_TMP_DIR}/giv.$$.$(date +%s)"
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
    if [ "${1:-}" = "true" ] || [ "$(git config --get giv.initialized)" != "true" ]; then
        printf "Initializing Giv for this repository...\n"
        printf "Project Name: "
        read -r project_name
        printf "Project Description:\n"
        read -r project_description
        printf "Project URL: "
        read -r project_url

        existing_name="$(git config --get giv.project.title || basename "$(pwd)")"
        git config giv.project.title "${project_name:-$existing_name}"
        echo "${project_description}" > .git/description
        git config giv.project.url "$project_url"


        # Detect project type, version file, and version pattern
        detect_project_type

        # TODO: setup API URL and Model by prompting user or using defaults
        printf 'What is your OpenAI API compatible URL?\n'
        printf 'Open AI: https://api.openai.com/v1/chat/completions\n'
        printf 'Ollama (default): http://localhost:11434/v1/chat/completions\n'
        read -r api_url
        git config giv.api.url "${api_url:-http://localhost:11434/v1/chat/completions}"

        git config giv.initialized true
        printf "Metadata has been set in the Git config.\n"

    else
        print_debug "Giv is already initialized. Fetching metadata from Git config..."
        project_name="$(git config --get giv.project.title)"
        project_description="$(git config --get giv.project.description)"
        project_url="$(git config --get giv.project.url)"

        print_debug "Project Name: $project_name"
        print_debug "Project Description: $project_description"
        print_debug "Project URL: $project_url"
    fi
}

############################################################
# Project type detection
############################################################
# Sets git config values:
#   giv.project.type
#   giv.version.file
#   giv.version.pattern
detect_project_type() {
    # List of known project types and their identifying files
    if [ -f "package.json" ]; then
        git config giv.project.type "node"
        git config giv.project.version_file "package.json"
        git config giv.project.version_pattern '"version"[[:space:]]*:[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Node.js project."
        return
    elif [ -f "pyproject.toml" ]; then
        git config giv.project.type "python"
        git config giv.project.version_file "pyproject.toml"
        git config giv.project.version_pattern '^version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Python project (pyproject.toml)."
        return
    elif [ -f "setup.py" ]; then
        git config giv.project.type "python"
        git config giv.project.version_file "setup.py"
        git config giv.project.version_pattern 'version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Python project (setup.py)."
        return
    elif [ -f "Cargo.toml" ]; then
        git config giv.project.type "rust"
        git config giv.project.version_file "Cargo.toml"
        git config giv.project.version_pattern '^version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Rust project."
        return
    elif [ -f "composer.json" ]; then
        git config giv.project.type "php"
        git config giv.project.version_file "composer.json"
        git config giv.project.version_pattern '"version"[[:space:]]*:[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected PHP project."
        return
    elif [ -f "build.gradle" ]; then
        git config giv.project.type "gradle"
        git config giv.project.version_file "build.gradle"
        git config giv.project.version_pattern 'version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
        print_debug "Detected Gradle project."
        return
    elif [ -f "pom.xml" ]; then
        git config giv.project.type "maven"
        git config giv.project.version_file "pom.xml"
        git config giv.project.version_pattern '<version>([0-9]+\\.[0-9]+\\.[0-9]+)</version>'
        print_debug "Detected Maven project."
        return
    # elif [ -f "src/giv.sh" ]; then
    #     git config giv.project.type "custom"
    #     git config giv.project.version_file "src/config.sh"
    #     git config giv.project.version_pattern 'version[[:space:]]*=[[:space:]]*"([0-9]+\\.[0-9]+\\.[0-9]+)"'
    #     print_debug "Detected Custom project."
    #     return
    else
        git config giv.project.type "custom"
        print_debug "Project type could not be detected. Defaulting to 'custom'."
        printf 'Project type could not be detected.\n'
        printf 'Please enter a path that contains the version of this project.\n'
        read -r version_file
        git config giv.version.file "$version_file"
        
        # shellcheck disable=SC2016
        git config giv.version.pattern "version[[:space:]]*=[[:space:]]*\"([0-9]+\\.[0-9]+\\.[0-9]+)"

    fi
}

is_valid_git_range() {
    git rev-list "$1" >/dev/null 2>&1
}

is_valid_pattern() {
    git ls-files --error-unmatch "$1" >/dev/null 2>&1
}
