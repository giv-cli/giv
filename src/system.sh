

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
    # Remove the temporary directory if it exists
    if [ -n "$GIV_TMP_DIR" ] && [ -d "$GIV_TMP_DIR" ]; then
        rm -rf "$GIV_TMP_DIR"
        print_debug "Removed temporary directory $GIV_TMP_DIR"
    else
        print_debug 'No temporary directory to remove.'
    fi
    GIV_TMP_DIR="" # Clear the variable
}

# Portable mktemp: fallback if mktemp not available
portable_mktemp_dir() {
    base_path="${GIV_TMP_DIR:-TMPDIR:-.giv/tmp}"
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
        mktemp -p "${GIV_TMP_DIR}" "$1"
    else
        echo "${GIV_TMP_DIR}/giv.$$.$(date +%s)"
    fi
}