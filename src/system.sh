

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

# -------------------------------------------------------------------
# Filesystem helpers
# -------------------------------------------------------------------
remove_tmp_dir() {
    if [ -z "${GIV_TMPDIR_SAVE:-}" ]; then
        print_debug "Removing temporary directory: $GIV_TMP_DIR"
        
        # Remove the temporary directory if it exists
        if [ -n "$GIV_TMP_DIR" ] && [ -d "$GIV_TMP_DIR" ]; then
            rm -rf "$GIV_TMP_DIR"
            print_debug "Removed temporary directory $GIV_TMP_DIR"
        else
            print_debug 'No temporary directory to remove.'
        fi
        GIV_TMP_DIR="" # Clear the variable
    else
        print_debug "Preserving temporary directory: $GIV_TMP_DIR"
        return 0
    fi
}

# Portable mktemp: fallback if mktemp not available
portable_mktemp_dir() {
    base_path="${GIV_TMP_DIR:-TMPDIR:-.giv/.tmp}"
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
    [ -z "$GIV_TMP_DIR" ] && portable_mktemp_dir
    
    mkdir -p "$GIV_TMP_DIR"
    
    if command -v mktemp >/dev/null 2>&1; then
        mktemp "${GIV_TMP_DIR}/$1"
    else
        echo "${GIV_TMP_DIR}/giv.$$.$(date +%s)"
    fi
}


find_giv_dir() {
    dir=$(pwd)
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.giv" ]; then
            printf '%s\n' "$dir/.giv"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    printf '%s\n' "$(pwd)/.giv"
}


# Function to ensure .giv directory is initialized
ensure_giv_dir_init() {
    
    [ -z "${GIV_HOME:-}" ] && GIV_HOME="$(find_giv_dir)"
    
    if [ ! -d "${GIV_HOME}" ]; then
        print_debug "Initializing .giv directory..."
        mkdir -p "$GIV_HOME"
    fi
    
    [ ! -f "$GIV_HOME/config" ] && cp "$GIV_DOCS_DIR/config.example" "$GIV_HOME/config"
    mkdir -p "$GIV_HOME" "$GIV_HOME/cache" "$GIV_HOME/.tmp" "$GIV_HOME/templates"
}