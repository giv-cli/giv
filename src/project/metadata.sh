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
    print_debug "Determining project provider for type: ${GIV_PROJECT_TYPE:-auto}"
    if [ "${GIV_PROJECT_TYPE}" = "custom" ]; then
        # shellcheck disable=SC1091
        [ -f "${GIV_HOME}/project_provider.sh" ] && . "${GIV_HOME}/project_provider.sh"
    elif [ "${GIV_PROJECT_TYPE}" = "auto" ]; then
        for f in "${GIV_LIB_DIR}/project/providers"/*.sh; do
            # shellcheck disable=SC1090
            [ -f "$f" ] && . "$f"
        done
        for fn in $(set | awk -F'=' '/^provider_.*_detect=/ { sub("()","",$1); print $1 }'); do
            if "$fn"; then
                DETECTED_PROVIDER="$fn"
                break
            fi
        done
    else
        # shellcheck disable=SC1090
        . "${GIV_LIB_DIR}/project/providers/provider_${GIV_PROJECT_TYPE}.sh" || return 1
        DETECTED_PROVIDER="provider_${GIV_PROJECT_TYPE}_detect"
    fi

    if [ -z "$DETECTED_PROVIDER" ]; then
        print_debug "No valid provider detected."
    fi

    # -------------------------
    # Collect Metadata
    # -------------------------
    ENV_FILE="${GIV_CACHE_DIR}/project_metadata.env"
    : > "$ENV_FILE"
    print_debug "Collecting metadata into $ENV_FILE"
    if [ -n "$DETECTED_PROVIDER" ]; then
        coll="${DETECTED_PROVIDER%_detect}_collect"
        "$coll" | while IFS="$(printf '\t')" read -r key val; do
            [ -z "$key" ] && continue
            esc_val=$(printf '%s' "$val" | sed 's/"/\\"/g')
            key="GIV_METADATA_$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"
            sed -i "/^$key=/d" "$ENV_FILE"
            printf '%s=%s\n' "$key" "$esc_val" >> "$ENV_FILE"
        done
    fi

    # If no metadata was collected, set the title to the directory name
    if [ ! -s "$ENV_FILE" ]; then
        dirname=$(basename "$PWD")
        print_debug "No metadata collected. Setting title to directory name: $dirname"
        sed -i "/^GIV_METADATA_TITLE=/d" "$ENV_FILE"
        printf 'GIV_METADATA_TITLE=%s\n' "$dirname" >> "$ENV_FILE"
    fi

    # -------------------------
    # Apply Overrides
    # -------------------------
    if [ -f "${GIV_HOME}/project_metadata.env" ]; then
        print_debug "Processing overrides from ${GIV_HOME}/project_metadata.env"
        while IFS="=" read -r k v; do
            [ -z "$k" ] || [ -z "$v" ] && continue
            print_debug "Applying override for $k=$v"
            k="GIV_METADATA_$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')"
            sed -i "/^$k=/d" "$ENV_FILE"
            printf '%s=%s\n' "$k" "$v" >> "$ENV_FILE"
        done < "${GIV_HOME}/project_metadata.env"
    fi

    # -------------------------
    # Ensure All Variables Have GIV_METADATA_ Prefix
    # -------------------------
    tmp_env_file="${ENV_FILE}.tmp"
    : > "$tmp_env_file"
    while IFS="=" read -r k v; do
        if ! printf '%s' "$k" | grep -q '^GIV_METADATA_'; then
            print_debug "Adding GIV_METADATA_ prefix to $k"
            k="GIV_METADATA_$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')"
        fi
        printf '%s=%s\n' "$k" "$v" >> "$tmp_env_file"
    done < "$ENV_FILE"
    mv "$tmp_env_file" "$ENV_FILE"

    # -------------------------
    # Export for current shell
    # -------------------------
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
}

# get_metadata_value: retrieve a metadata value by key
get_metadata_value() {
    key="$1"
    eval "printf '%s\n' \"\${$key:-}\""
}
