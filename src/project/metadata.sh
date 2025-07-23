#!/bin/sh
# project/metadata.sh: Orchestrator for collecting project metadata in POSIX shell
# Produces: .giv/cache/project_metadata.env
# Usage: call metadata_init early; then source the env file or rely on exported vars.

metadata_init() {
    : "${GIV_CACHE_DIR:?GIV_CACHE_DIR not set}"
    : "${GIV_LIB_DIR:?GIV_LIB_DIR not set}"
    : "${GIV_HOME:?GIV_HOME not set}"

    mkdir -p "${GIV_CACHE_DIR}/" || return 1
    print_debug "Initializing project metadata in ${GIV_CACHE_DIR}/project_metadata.env"

    DETECTED_PROVIDER=""
    # -------------------------
    # Determine Provider
    # -------------------------
    print_debug "Determining project provider for type: ${GIV_METADATA_PROJECT_TYPE:-auto}"
    if [ "${GIV_METADATA_PROJECT_TYPE}" = "auto" ]; then
        for f in "${GIV_LIB_DIR}/project/providers"/*.sh; do
            # shellcheck disable=SC1090
            [ -f "${f}" ] && . "${f}"
        done
        for fn in $(set | awk -F'=' '/^provider_.*_detect=/ { sub("()","",$1); print $1 }'); do
            if "${fn}"; then
                DETECTED_PROVIDER="${fn}"
                break
            fi
        done
        print_debug "Detected provider: ${DETECTED_PROVIDER}"
    else
        provider_file="${GIV_LIB_DIR}/project/providers/provider_${GIV_METADATA_PROJECT_TYPE}.sh"
        if [ ! -f "${provider_file}" ]; then
            echo "Error: Provider file not found: ${provider_file}" >&2
            return 1
        fi
        # shellcheck disable=SC1090
        . "${provider_file}" || return 1
        DETECTED_PROVIDER="provider_${GIV_METADATA_PROJECT_TYPE}_detect"
        print_debug "Provider set to: ${DETECTED_PROVIDER}"
    fi

    if [ -z "${DETECTED_PROVIDER}" ]; then
        print_warn "No valid metadata provider detected."
    fi

    # Set GIV_METADATA_PROJECT_TYPE for later use
    GIV_METADATA_PROJECT_TYPE="${DETECTED_PROVIDER#provider_}"
    # If provider is set to "custom", ensure the GIV_PROJECT_VERSION_FILE is set
    if [ "${GIV_METADATA_PROJECT_TYPE}" = "custom" ] && [ -z "${GIV_PROJECT_VERSION_FILE}" ]; then
        print_warn "GIV_PROJECT_VERSION_FILE must be set for custom projects."
    fi

    # -------------------------
    # Collect Metadata
    # -------------------------
    METADATA_CACHE_FILE="${GIV_CACHE_DIR}/project_metadata.env"
    : > "${METADATA_CACHE_FILE}"
    print_debug "Collecting metadata into ${METADATA_CACHE_FILE}"
    sed_inplace() {
        # $1: pattern, $2: file
        if sed --version 2>/dev/null | grep -q GNU; then
            sed -i "$1" "$2"
        else
            sed -i '' "$1" "$2"
        fi
    }
    if [ -n "${DETECTED_PROVIDER}" ]; then
        coll="${DETECTED_PROVIDER%_detect}_collect"
        print_debug "Raw output from ${coll}:" >&2
        "${coll}" | while IFS="=" read -r key val; do
            print_debug "Processing line: key='${key}', value='${val}'" >&2
            [ -z "${key}" ] && continue
            esc_val=$(printf '%s' "${val}" | sed 's/"/\\\\"/g')
            # Only add prefix if not already present
            if ! printf '%s' "${key}" | grep -q '^GIV_METADATA_'; then
                key="GIV_METADATA_$(printf '%s' "${key}" | tr '[:lower:]' '[:upper:]')"
            else
                key="$(printf '%s' "${key}" | tr '[:lower:]' '[:upper:]')"
            fi
            # Remove any trailing = from key
            key="${key%%=*}"
            sed_inplace "/^${key}=/d" "${METADATA_CACHE_FILE}"
            printf '%s=%s\n' "${key}" "${val}" >> "${METADATA_CACHE_FILE}"
            print_debug "Processed metadata: key=${key}, value=${esc_val}" >&2
        done

        # Add project_type to metadata
        project_type=${DETECTED_PROVIDER#provider_}
        project_type=${project_type%_detect}
        printf 'GIV_METADATA_PROJECT_TYPE="%s"\n' "${project_type}" >> "${METADATA_CACHE_FILE}"
    fi

    load_config_metadata
    
    # If no metadata was collected, set the title to the directory name
    if [ ! -s "${METADATA_CACHE_FILE}" ]; then
        dirname=$(basename "${PWD}")
        print_debug "No metadata collected. Setting title to directory name: ${dirname}"
        sed -i "/^GIV_METADATA_TITLE=/d" "${METADATA_CACHE_FILE}"
        printf 'GIV_METADATA_TITLE="%s"\n' "${dirname}" >> "${METADATA_CACHE_FILE}"
        # Also set a default description to avoid sourcing errors
        sed -i "/^GIV_METADATA_DESCRIPTION=/d" "${METADATA_CACHE_FILE}"
        printf 'GIV_METADATA_DESCRIPTION="%s"\n' "No description provided" >> "${METADATA_CACHE_FILE}"
    fi



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
get_project_version() {
    commit="$1"
    project_type="${GIV_METADATA_PROJECT_TYPE:-}"

    if [ -z "${project_type}" ]; then
        echo "Error: GIV_METADATA_PROJECT_TYPE not set. Did you call metadata_init?" >&2
        return 1
    fi

    #print_debug "Getting project version for type: ${project_type}, commit: ${commit}"

    fn=""
    if [ -z "${commit}" ] || [ "${commit}" = "--current" ] || [ "${commit}" = "--staged" ] || [ "${commit}" = "--cached" ]; then
        fn="provider_${project_type}_get_version"
    else
        fn="provider_${project_type}_get_version_at_commit"
    fi

    #print_debug "Using version function: $fn for project type: $project_type"
    if command -v "${fn}" >/dev/null 2>&1; then
        ver=""
        if ver_out=$("${fn}" "${commit}" 2>/dev/null); then
            ver="${ver_out}"
        else
            #print_debug "Error: $fn failed to execute for commit $commit"
            ver=""
        fi
        #print_debug "Version extracted: $ver"
        printf '%s' "${ver}"
        return 0
    else
        #print_debug "Error: version function $fn not implemented for provider $project_type"
        printf ""
        return 0
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