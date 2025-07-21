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

  [ -n "$title" ] && printf 'title="%s"\n' "$title"
  [ -n "$description" ] && printf 'description="%s"\n' "$description"
  [ -n "$version" ] && printf 'latest_version="%s"\n' "$version"
  [ -n "$repository" ] && printf 'repository_url="%s"\n' "$repository"
  [ -n "$author" ] && printf 'author="%s"\n' "$author"
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
    parse_version "$(cat "$GIV_VERSION_FILE")"
}

provider_custom_get_version_at_commit() {
    commit="$1"
    file_content=$(git show "${commit}:${GIV_VERSION_FILE}") || return 1
    parse_version "${file_content}"
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
    echo "$1" | sed -n -E 's/.*([vV]?[0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n 1
}
