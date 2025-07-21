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
            sed -i '' "/^$key=/d" "$ENV_FILE"
            printf '%s=%s\n' "$key" "$esc_val" >> "$ENV_FILE"
        done
    fi

    # If no metadata was collected, set the title to the directory name
    if [ ! -s "$ENV_FILE" ]; then
        dirname=$(basename "$PWD")
        print_debug "No metadata collected. Setting title to directory name: $dirname"
        sed -i '' "/^GIV_METADATA_TITLE=/d" "$ENV_FILE"
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
            sed -i '' "/^$k=/d" "$ENV_FILE"
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

    # Detect project type
    if [ -f package.json ]; then
        project_type=node_pkg
    elif [ -f pyproject.toml ]; then
        project_type=python_pkg
    else
        project_type=generic
    fi

    # Write project_type to metadata cache
    echo "GIV_METADATA_PROJECT_TYPE=$project_type" >> "$ENV_FILE"

    # -------------------------
    # Export for current shell
    # -------------------------
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
}

# parse_version - Extracts version information from a string.
#
# This function takes a single argument (a string) and attempts to extract a version number
# in the format of v1.2.3 or 1.2.3. It uses sed to match patterns that include an optional 'v' or 'V'
# followed by three numbers separated by dots.
#
# Arguments:
#   $1 - The input string from which to extract the version number.
#
# Returns:
#   A string representing the extracted version number, or an empty string if no valid version
#   is found in the input.
parse_version() {
    #printf 'Parsing version from: %s\n' "$1" >&2
    # Accepts a string, returns version like v1.2.3 or 1.2.3
    out=$(echo "$1" | sed -n -E 's/.*([vV][0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
    if [ -z "$out" ]; then
        out=$(echo "$1" | sed -n -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
    fi
    printf '%s' "$out"
}

# Finds and returns the path to a version file in the current directory.
# The function checks if the variable 'GIV_VERSION_FILE' is set and points to an existing file.
# If not, it searches for common version files (package.json, pyproject.toml, setup.py, Cargo.toml, composer.json, build.gradle, pom.xml).
# If none are found, it attempts to locate a 'giv.sh' script using git.
# If no suitable file is found, it returns an empty string.
# helper: finds the version file path
find_version_file() {
    print_debug "Finding version file..."
    if [ -n "${GIV_VERSION_FILE}" ] && [ -f "${GIV_VERSION_FILE}" ]; then
        echo "${GIV_VERSION_FILE}"
        return
    fi
    for vf in package.json pyproject.toml setup.py Cargo.toml composer.json build.gradle pom.xml; do
        [ -f "${vf}" ] && {
            echo "${vf}"
            return
        }
    done
    print_debug "No version file found, searching for giv.sh..."
    giv_sh=$(git ls-files --full-name | grep '/giv\.sh$' | head -n1)
    if [ -n "${giv_sh}" ]; then
        echo "${giv_sh}"
    else
        print_debug "No version file found, returning empty string."
        echo ""
    fi

}

# get_version_info
#
# Extracts version information from a specified file or from a file as it exists
# in a given git commit or index state.
#
# Usage:
#   get_version_info <commit> <file_path>
#
# Parameters:
#   commit    - Specifies the git commit or index state to extract the version from.
#               Accepts:
#                 --current or "" : Use the current working directory file.
#                 --cached        : Use the staged (index) version of the file.
#                 <commit_hash>   : Use the file as it exists in the specified commit.
#   file_path - Path to the file containing the version information.
#
# Behavior:
#   - Searches for a version string matching the pattern 'versionX.Y' or 'version X.Y.Z'
#     (case-insensitive) in the specified file or git object.
#   - Returns the first matching version string found, parsed by parse_version.
#   - Returns an empty string if the file or version string is not found.
#
# Dependencies:
#   - Requires 'git' command-line tool for accessing git objects.
#   - Relies on a 'parse_version' function to process the raw version string.
#   - Uses 'print_debug' for optional debug output.
#
# Example:
#   get_version_info --current ./package.json
#   get_version_info --cached ./setup.py
#   get_version_info abc123 ./src/version.txt
get_version_info() {
    commit="$1"
    vf="$(find_version_file)"

    [ -z "${vf}" ] && [ -f "${vf}" ] && {
        print_debug "No version file specified."
        echo ""
        return
    }
    print_debug "Getting version info for commit $commit from $vf"

    # Ensure empty string is returned on failure
    case "$commit" in
    --current | "")
        if [ -f "$vf" ]; then
            grep -Ei 'version[^0-9]*[0-9]+\.[0-9]+(\.[0-9]+)?' "$vf" | head -n1 || echo ""
        else
            echo ""
        fi
        ;;
    --cached)
        if git ls-files --cached --error-unmatch "$vf" >/dev/null 2>&1; then
            git show ":$vf" | grep -Ei 'version[^0-9]*[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo ""
        elif [ -f "$vf" ]; then
            grep -Ei 'version[^0-9]*[0-9]+\.[0-9]+(\.[0-9]+)?' "$vf" | head -n1 || echo ""
        else
            echo ""
        fi
        ;;
    *)
        if git rev-parse --verify "$commit" >/dev/null 2>&1; then
            if git ls-tree -r --name-only "$commit" | grep -Fxq "$vf"; then
                git show "${commit}:${vf}" | grep -Ei 'version[^0-9]*[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo ""
            elif [ -f "$vf" ]; then
                grep -Ei 'version[^0-9]*[0-9]+\.[0-9]+(\.[0-9]+)?' "$vf" | head -n1 || echo ""
            else
                echo ""
            fi
        else
            echo "" # Return empty string for invalid commit IDs
        fi
        ;;
    esac | {
        read -r raw
        parse_version "${raw:-}" || echo ""
    }
}


# Ensure the metadata cache file exists
touch "$ENV_FILE"

# Ensure ENV_FILE is initialized to avoid unbound variable errors.
: "${ENV_FILE:=/tmp/giv_env_file}"

# get_metadata_value: retrieve a metadata value by key
get_metadata_value() {
    key="$1"
    eval "printf '%s\n' \"\${$key:-}\""
}

# Added functions to retrieve current and historical version information.

get_current_version_for_file() {
    file_path="$1"
    provider_get_version_from_content < "$file_path"
}

get_version_at_commit() {
    commit="$1"
    file_path="$2"
    git show "$commit:$file_path" | provider_get_version_from_content
}

# Mock implementation of provider_get_version_from_content for testing purposes.

provider_get_version_from_content() {
    grep -Eo 'Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+'
}
