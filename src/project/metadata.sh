#!/bin/sh
# project/metadata.sh: Orchestrator for collecting project metadata in POSIX shell
# Produces: .giv/cache/project_metadata.env
# Usage: call metadata_init early; then source the env file or rely on exported vars.

metadata_init() {
    : "${GIV_CACHE_DIR:?GIV_CACHE_DIR not set}"
    : "${GIV_LIB_DIR:?GIV_LIB_DIR not set}"
    : "${GIV_HOME:?GIV_HOME not set}"
    
    mkdir -p "${GIV_CACHE_DIR}/" || return 1
    
    DETECTED_PROVIDER=""
    # -------------------------
    # Determine Provider
    # -------------------------
    # If the project type is "custom", source a user-defined provider script if it exists.
    if [ "${GIV_PROJECT_TYPE}" = "custom" ]; then
        [ -f "${GIV_HOME}/project_provider.sh" ] && . "${GIV_HOME}/project_provider.sh"
        
        # If the project type is "auto", attempt to automatically detect the provider.
        elif [ "${GIV_PROJECT_TYPE}" = "auto" ]; then
        # Source all provider scripts from the providers directory to register their detect functions.
        provider_detect_fns=""
        for f in "${GIV_LIB_DIR}/project/providers"/*.sh; do
            [ -f "$f" ] && . "$f"
        done
        # List all shell functions matching provider_*_detect and collect their names.
        provider_detect_fns=$(set | awk -F'=' '/^provider_.*_detect=/ { sub("()","",$1); print $1 }')
        # Iterate over each detect function and call it; the first one that returns true is selected.
        for fn in $provider_detect_fns; do
            if "$fn"; then
                DETECTED_PROVIDER="$fn"
                break
            fi
        done
        
        # Otherwise, source the provider script matching the specified project type and set the detect function.
    else
        . "${GIV_LIB_DIR}/project/providers/provider_${GIV_PROJECT_TYPE}.sh"
        DETECTED_PROVIDER="provider_${GIV_PROJECT_TYPE}_detect"
    fi
    
    # -------------------------
    # Collect Metadata
    # -------------------------
    ENV_FILE="${GIV_CACHE_DIR}/project_metadata.env"
    : > "$ENV_FILE"
    
    if [ -n "$DETECTED_PROVIDER" ]; then
        coll="${DETECTED_PROVIDER%_detect}_collect"
        "$coll" | while IFS="$(printf '\t')" read -r key val; do
            [ -z "$key" ] && continue
            esc_val=$(printf '%s' "$val" | sed 's/"/\\"/g')
            printf 'GIV_METADATA_%s=%s\n' "$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')" "$esc_val" >> "$ENV_FILE"
        done
    fi
    
    # -------------------------
    # Apply Overrides
    # -------------------------
    if [ -f "${GIV_HOME}/project_metadata.env" ]; then
        tmp=$(portable_mktemp "tmp.env.XXXXXX")
        cat "${GIV_HOME}/project_metadata.env" > "$tmp"
        # shellcheck disable=SC1090
        . "$tmp"
        print_debug "Applying overrides from ${GIV_HOME}/project_metadata.env"
        awk -F= '!/^#/ && /^[A-Za-z0-9_]+=/ {print $1}' "${GIV_HOME}/project_metadata.env" | while read -r k; do
            print_debug "Applying override for $k"
            v="$(eval "printf '%s' \"\${$k}\"")"
            printf 'GIV_METADATA_%s="%s"\n' "$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')" "$v" >> "$ENV_FILE"
        done
    fi
    
    # -------------------------
    # Export for current shell
    # -------------------------
    set -a
    . "$ENV_FILE"
    set +a
}

# get_metadata_value: retrieve a metadata value by key
get_metadata_value() {
    key="$1"
    eval "printf '%s\n' \"\${$key:-}\""
}
