#!/bin/sh
# provider_node_pkg.sh: Node.js project metadata provider

# Detect presence (0 = yes, >0 = no)
provider_custom_detect() {
  [ -f "${GIV_VERSION_FILE}" ]
}

# Collect metadata: output KEY=VALUE per line
provider_custom_collect() {
  title="${GIV_METADATA_PROJECT_TITLE:-$(basename "$PWD")}"
  description="${GIV_METADATA_PROJECT_DESCRIPTION:-No description provided}"
  version=$(provider_custom_get_version)
  repository="${GIV_METADATA_PROJECT_REPOSITORY:-}"
  author="${GIV_METADATA_PROJECT_AUTHOR:-}"

  [ -n "$title" ] && printf 'GIV_METADATA_TITLE="%s"\n' "$title"
  [ -n "$description" ] && printf 'GIV_METADATA_DESCRIPTION="%s"\n' "$description"
  [ -n "$version" ] && printf 'GIV_METADATA_LATEST_VERSION="%s"\n' "$version"
  [ -n "$repository" ] && printf 'GIV_METADATA_REPOSITORY_URL="%s"\n' "$repository"
  [ -n "$author" ] && printf 'GIV_METADATA_AUTHOR="%s"\n' "$author"
}


provider_custom_get_version() {
    # #printf 'Parsing version from: %s\n' "$1" >&2
    # # Accepts a string, returns version like v1.2.3 or 1.2.3
    # out=$(cat "$GIV_VERSION_FILE" | sed -n -E 's/.*([vV][0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
    # if [ -z "$out" ]; then
    #     out=$(cat "$GIV_VERSION_FILE" | sed -n -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
    # fi
    # printf '%s' "$out"
    if [ -z "$GIV_VERSION_FILE" ]; then
        printf ""
        return 0
    fi
    if [ ! -f "$GIV_VERSION_FILE" ]; then
        printf ""
        return 0
    fi
    # If file is JSON, extract "version" field (case-insensitive)
    if grep -i -q 'version' "$GIV_VERSION_FILE" 2>/dev/null; then
        #print_debug "Extracting version from file: $GIV_VERSION_FILE"
        version=$(grep -i 'version' "$GIV_VERSION_FILE" | sed -En 's/.*[vV]ersion"[[:space:]]*:[[:space:]]*([^\"]+)".*/\1/p' | head -n 1)
        # If version is empty or does not match a version pattern, fallback
        if [ -z "$version" ]; then
            parse_version "$(cat "$GIV_VERSION_FILE")"
        else
            printf '%s' "$version"
        fi
    else
        parse_version "$(cat "$GIV_VERSION_FILE")"
    fi
}

provider_custom_get_version_at_commit() {
    commit="$1"
    file_content=""
    # Try to get file content from commit, suppress errors
    file_content=$(git show "${commit}:${GIV_VERSION_FILE}" 2>/dev/null)
    if [ -z "$file_content" ]; then
        printf ""
        return 0
    fi
    # If file is JSON, extract "version" field (case-insensitive)
    if printf '%s' "$file_content" | grep -i -q 'version'; then
        version=$(printf '%s' "$file_content" | grep -i '"version"' | sed -En 's/.*"[vV]ersion"[[:space:]]*:[[:space:]]*"([^\"]+)".*/\1/p' | head -n 1)
        # If version is empty or does not match a version pattern, fallback
        if [ -z "$version" ] || ! printf '%s' "$version" | grep -Eq '^[vV]?[0-9]+\.[0-9]+\.[0-9]+$'; then
            parse_version "$file_content"
        else
            printf '%s' "$version"
        fi
    else
        parse_version "$file_content"
    fi
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
    #print_debug "Parsing version from: $1"
    # Accepts a string, returns version like v1.2.3 or 1.2.3
    echo "$1" | sed -n -E "s/.*['\"]?([vV][0-9]+\.[0-9]+\.[0-9]+)['\"]?.*/\1/p;s/.*['\"]?([0-9]+\.[0-9]+\.[0-9]+)['\"]?.*/\1/p" | head -n 1
}
