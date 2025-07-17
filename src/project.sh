
# Locate the project from the codebase. Looks for common project files
# like package.json, pyproject.toml, setup.py, Cargo.toml, composer.json
# build.gradle, pom.xml, etc. and extracts the project name.
# If no project file is found, returns an empty string.
# If a project name is found, it is printed to stdout.
get_project_title() {
    # Look for common project files
    for file in src/giv.sh package.json pyproject.toml setup.py Cargo.toml composer.json build.gradle pom.xml; do
        if [ -f "${file}" ]; then
            # Extract project name based on file type
            case "${file}" in
            "src/giv.sh")
                printf 'giv'
                ;;
            package.json)
                awk -F'"' '/"name"[[:space:]]*:/ {print $4; exit}' "${file}"
                ;;
            pyproject.toml)
                awk -F' = ' '/^name/ {gsub(/"/, "", $2); print $2; exit}' "${file}"
                ;;
            setup.py)
                # Double quotes
                grep -E '^[[:space:]]*name[[:space:]]*=[[:space:]]*"[^"]+"' "${file}" | sed -E 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/' | head -n1 &&
                    # Single quotes
                    grep -E "^[[:space:]]*name[[:space:]]*=[[:space:]]*'[^']+'" "${file}" | sed -E "s/^[[:space:]]*name[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/" | head -n1
                ;;
            Cargo.toml)
                awk -F' = ' '/^name/ {gsub(/"/, "", $2); print $2; exit}' "${file}"
                ;;
            composer.json)
                awk -F'"' '/"name"[[:space:]]*:/ {print $4; exit}' "${file}"
                ;;
            build.gradle)
                # Double quotes
                grep -E '^[[:space:]]*rootProject\.name[[:space:]]*=[[:space:]]*"[^"]+"' "${file}" | sed -E 's/^[[:space:]]*rootProject\.name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/' | head -n1 &&
                    # Single quotes
                    grep -E "^[[:space:]]*rootProject\.name[[:space:]]*=[[:space:]]*'[^']+'" "${file}" | sed -E "s/^[[:space:]]*rootProject\.name[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/" | head -n1
                ;;
            pom.xml)
                awk -F'[<>]' '/<name>/ {print $3; exit}' "${file}"
                ;;
            *)
                echo "Unknown project file type: ${file}" >&2
                return 1
                ;;
            esac
            return
        fi
    done
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
    vf="$2"
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
        parse_version "$raw"
    }
}