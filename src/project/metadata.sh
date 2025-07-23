#!/bin/sh
# project/metadata.sh: Orchestrator for collecting project metadata in POSIX shell


# Produces: .giv/cache/project_metadata.env
# Usage: call metadata_init early; then source the env file or rely on exported vars.

metadata_init() {
    : "${GIV_CACHE_DIR:?GIV_CACHE_DIR not set}"
    : "${GIV_LIB_DIR:?GIV_LIB_DIR not set}"
    : "${GIV_HOME:?GIV_HOME not set}"

    mkdir -p "${GIV_CACHE_DIR}/" || { echo "Error: Failed to create cache directory" >&2; return 1; }
    print_debug "Initializing project metadata in ${GIV_CACHE_DIR}/project_metadata.env"

    # Read metadata from .giv/config
    if [ -f "${GIV_HOME}/config" ]; then
        . "${GIV_HOME}/config"
    else
        echo "Error: .giv/config not found." >&2
        return 1
    fi

    # Set GIV_METADATA_PROJECT_TYPE for later use
    GIV_METADATA_PROJECT_TYPE="${GIV_METADATA_PROJECT_TYPE:-auto}"
    if [ -z "${GIV_METADATA_PROJECT_TYPE}" ]; then
        echo "Error: GIV_METADATA_PROJECT_TYPE not set after metadata_init" >&2
        return 1
    fi

    # Collect Metadata
    METADATA_CACHE_FILE="${GIV_CACHE_DIR}/project_metadata.env"
    : > "${METADATA_CACHE_FILE}" || { echo "Error: Failed to write to cache file" >&2; return 1; }
    print_debug "Collecting metadata into ${METADATA_CACHE_FILE}"

    # Example: Write metadata to cache file
    echo "GIV_METADATA_PROJECT_TYPE=${GIV_METADATA_PROJECT_TYPE}" >> "${METADATA_CACHE_FILE}" || {
        echo "Error: Failed to write metadata to cache file" >&2
        return 1
    }
    export GIV_METADATA_PROJECT_TYPE

    # -------------------------
    # Ensure All Variables Have GIV_METADATA_ Prefix
    # -------------------------
    print_debug "Ensuring all metadata variables have GIV_METADATA_ prefix"
    tmp_METADATA_CACHE_FILE="${METADATA_CACHE_FILE}.tmp"
    : > "${tmp_METADATA_CACHE_FILE}"
    while IFS="=" read -r k v; do
        # Remove any leading/trailing whitespace
        k="$(echo "${k}" | xargs)"
        v="$(echo "${v}" | xargs)"
        # Always prefix and uppercase
        if ! printf '%s' "${k}" | grep -q '^GIV_METADATA_'; then
            print_debug "Adding GIV_METADATA_ prefix to ${k}"
            k="GIV_METADATA_$(printf '%s' "${k}" | tr '[:lower:]' '[:upper:]')"
        fi
        printf '%s="%s"\n' "${k}" "${v}" >> "${tmp_METADATA_CACHE_FILE}"
    done < "${METADATA_CACHE_FILE}"
    mv "${tmp_METADATA_CACHE_FILE}" "${METADATA_CACHE_FILE}"
    print_debug "All metadata variables prefixed and saved to ${METADATA_CACHE_FILE}"

    # -------------------------
    # Export for current shell
    # -------------------------
    print_debug "Exporting metadata to current shell"
    # Ensure we export all variables with GIV_METADATA_ prefix
    
    set -a
    # shellcheck disable=SC1090
    . "${METADATA_CACHE_FILE}"
    set +a

    if [ -z "${GIV_METADATA_PROJECT_TYPE}" ]; then
        echo "Error: GIV_METADATA_PROJECT_TYPE not set after metadata_init" >&2
        return 1
    fi

    print_debug "Writing metadata to cache file: ${METADATA_CACHE_FILE}"
}

# get_project_version: dispatch to the correct provider for version info
# Add error handling and debugging to get_project_version
get_project_version() {
    commit="$1"
    project_type="${GIV_METADATA_PROJECT_TYPE:-}"

    if [ -z "${project_type}" ]; then
        echo "Error: GIV_METADATA_PROJECT_TYPE not set. Did you call metadata_init?" >&2
        return 1
    fi

    fn=""
    if [ -z "${commit}" ] || [ "$commit" = "--current" ] || [ "$commit" = "--staged" ] || [ "$commit" = "--cached" ]; then
        fn="provider_${project_type}_get_version"
    else
        fn="provider_${project_type}_get_version_at_commit"
    fi

    if command -v "$fn" >/dev/null 2>&1; then
        if ver_out=$("$fn" "$commit" 2>/dev/null); then
            printf '%s' "$ver_out"
            return 0
        else
            echo "Error: $fn failed to execute for commit $commit" >&2
            return 1
        fi
    else
        echo "Error: version function $fn not implemented for provider $project_type" >&2
        return 1
    fi
}

get_project_title() {
    # Returns the project title from metadata or defaults to directory name
    if [ -n "${GIV_METADATA_TITLE}" ]; then
        printf '%s' "${GIV_METADATA_TITLE}"
    else
        dirname=$(basename "${PWD}")
        printf '%s' "${dirname}"
    fi
}

load_config_metadata(){
        # -------------------------
    # Apply Overrides
    # -------------------------
    sed_inplace() {
        # $1: pattern, $2: file
        if sed --version 2>/dev/null | grep -q GNU; then
            sed -i "$1" "$2"
        else
            sed -i '' "$1" "$2"
        fi
    }
    if [ -f "${GIV_HOME}/project_metadata.env" ]; then
        print_debug "Processing overrides from ${GIV_HOME}/project_metadata.env"
        while IFS="=" read -r k v; do
            [ -z "${k}" ] || [ -z "${v}" ] && continue
            print_debug "Applying override for ${k}=${v}"
            k="GIV_METADATA_$(printf '%s' "${k}" | tr '[:lower:]' '[:upper:]')"
            sed_inplace "/^${k}=/d" "${METADATA_CACHE_FILE}"
            printf '%s="%s"\n' "${k}" "${v}" >> "${METADATA_CACHE_FILE}"
        done < "${GIV_HOME}/project_metadata.env"
    fi
}