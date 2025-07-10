#!/bin/sh

GIV_TOKEN_PROJECT_TITLE=""
GIV_TOKEN_VERSION=""
GIV_TOKEN_EXAMPLE=""
GIV_TOKEN_RULES=""
GIV_TOKEN_SUMMARY=""

is_valid_git_range() {
    git rev-list "$1" >/dev/null 2>&1
}

is_valid_pattern() {
    git ls-files --error-unmatch "$1" >/dev/null 2>&1
}

remove_tmp_dir() {
    # Remove the temporary directory if it exists
    if [ -n "$GIV_TMPDIR" ] && [ -d "$GIV_TMPDIR" ]; then
        rm -rf "$GIV_TMPDIR"
        print_debug "Removed temporary directory $GIV_TMPDIR"
    else
        print_debug 'No temporary directory to remove.'
    fi
    GIV_TMPDIR="" # Clear the variable
}

# Portable mktemp: fallback if mktemp not available
portable_mktemp_dir() {
    base_path="${TMPDIR:-/tmp}/giv/"
    mkdir -p "${base_path}"

    # Ensure only one subfolder under $TMPDIR/giv exists per execution of the script
    # If GIV_TMPDIR is not set, create a new temporary directory
    if [ -z "${GIV_TMPDIR}" ]; then

        if command -v mktemp >/dev/null 2>&1; then
            GIV_TMPDIR="$(mktemp -d -p "${base_path}")"
        else
            GIV_TMPDIR="${base_path}/giv.$$.$(date +%s)"
            mkdir -p "${GIV_TMPDIR}"
        fi

    fi
}

# Portable mktemp: fallback if mktemp not available
portable_mktemp() {
    [ -z "$GIV_TMPDIR" ] && portable_mktemp_dir
    if command -v mktemp >/dev/null 2>&1; then
        mktemp -p "${GIV_TMPDIR}" "$1"
    else
        echo "${GIV_TMPDIR}/giv.$$.$(date +%s)"
    fi
}

# -------------------------------------------------------------------
# Logging helpers
# -------------------------------------------------------------------
print_debug() {
    if [ "${debug:-}" = "true" ]; then
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

# Replaces every “[NAME]” in stdin with the contents of
# the environment variable GIV_TOKEN_NAME (if set).
#
# Usage:
#   export GIV_TOKEN_FOO="multi
#   line
#   text"
#   replace_tokens < template.md > output.md
replace_tokens() {
    awk '
  BEGIN {
    ORS = ""
    # build map[name] = value for all GIV_TOKEN_* vars
    for (v in ENVIRON) {
      if (substr(v, 1, 10) == "GIV_TOKEN_") {
        name = substr(v, 11)
        map[name] = ENVIRON[v]
      }
    }
  }
  {
    line = $0
    # apply each replacement; order is arbitrary but harmless
    for (n in map) {
      # \[ and \] to match literal brackets
      gsub("\\[" n "\\]", map[n], line)
    }
    print line "\n"
  }
  '
}

# build_prompt [--project-title X] [--version V] [--example E] [--rules R] \
#              <template_file> <diff_file>
#
# Exports GIV_TOKEN_SUMMARY (and any of PROJECT_TITLE, VERSION, EXAMPLE, RULES
# if passed) then runs replace_tokens on the template.
build_prompt() {
    project_title="$(parse_project_title)"

    version="${output_version:-${GIV_TOKEN_VERSION:-}}"
    if [ -z "${version}" ] || [ "${version}" = "auto" ]; then
        print_debug "No version set or version is 'auto', trying to find it from version file"
        # Try to find the version file and extract the version
        version_file="$(find_version_file)"
        version="$(get_version_info --current "${version_file:-}")"
    fi
    example=""
    rules=""
    # parse flags
    while [ $# -gt 2 ]; do
        case "$1" in
        --project-title)
            project_title=$2
            shift 2
            ;;
        --version)
            version=$2
            shift 2
            ;;
        --example)
            example=$2
            shift 2
            ;;
        --rules)
            rules=$2
            shift 2
            ;;
        *)
            printf 'unknown option: %s\n' "$1" >&2
            return 1
            ;;
        esac
    done

    prompt_template=$1
    diff_file=$2

    # validate files
    if [ ! -f "${prompt_template}" ]; then
        printf 'template file not found: %s\n' "${prompt_template}" >&2
        return 1
    fi
    if [ ! -f "${diff_file}" ]; then
        printf 'diff file not found: %s\n' "${diff_file}" >&2
        return 1
    fi
    # export our tokens
    # export our tokens
    export GIV_TOKEN_SUMMARY
    GIV_TOKEN_SUMMARY=$(cat "${diff_file}")

    export GIV_TOKEN_PROJECT_TITLE="${project_title:-${GIV_TOKEN_PROJECT_TITLE}}"
    export GIV_TOKEN_VERSION="${version:-${GIV_TOKEN_VERSION}}"
    export GIV_TOKEN_EXAMPLE="${example:-${GIV_TOKEN_EXAMPLE}}"
    export GIV_TOKEN_RULES="${rules:-${GIV_TOKEN_RULES}}"

    # Append the extra instructions to the prompt content before passing to replace_tokens
    {
        cat "${prompt_template}"
        printf '\nOutput just the final content—no extra commentary or code fencing. '
        printf 'Use only information contained in this prompt and the summaries provided above.'
    } | replace_tokens
    return
}

# Locate the project from the codebase. Looks for common project files
# like package.json, pyproject.toml, setup.py, Cargo.toml, composer.json
# build.gradle, pom.xml, etc. and extracts the project name.
# If no project file is found, returns an empty string.
# If a project name is found, it is printed to stdout.
parse_project_title() {
    # Look for common project files
    for file in package.json pyproject.toml setup.py Cargo.toml composer.json build.gradle pom.xml; do
        if [ -f "${file}" ]; then
            # Extract project name based on file type
            case "${file}" in
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

# Extract version string from a line (preserving v if present)
parse_version() {
    #printf 'Parsing version from: %s\n' "$1" >&2
    # Accepts a string, returns version like v1.2.3 or 1.2.3
    out=$(echo "$1" | sed -n -E 's/.*([vV][0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
    if [ -z "$out" ]; then
        out=$(echo "$1" | sed -n -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
    fi
    printf '%s' "$out"
}

json_escape() {
    # Reads stdin, outputs JSON-escaped string (with surrounding quotes)
    # Handles: backslash, double quote, newlines, tabs, carriage returns, form feeds, backspaces
    # Newlines are replaced with \n using tr
    sed -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/\r/\\r/g' \
        -e 's/\t/\\t/g' \
        -e 's/\f/\\f/g' \
        -e 's/\b/\\b/g' |
        awk 'BEGIN{printf "\""} {printf "%s", $0} END{print "\""}'
}

extract_content() {
    # Usage: extract_content "$json_string"
    json=$1

    # 1) Extract all lines from the "content" property (handles multi-line content)
    raw=$(printf '%s' "$json" | awk '
    BEGIN { in_content=0; esc=""; val="" }
    {
        line = $0
        if (!in_content) {
            # Look for "content":
            m = match(line, /"content"[[:space:]]*:[[:space:]]*"/)
            if (m) {
                in_content=1
                # Start after the opening quote
                start = RSTART + RLENGTH
                val = substr(line, start)
                # Check if closing quote is on this line
                i = 1; esc=0; out=""
                while (i <= length(val)) {
                    c = substr(val,i,1)
                    if (c == "\\" && esc == 0) {
                        esc = 1
                        out = out c
                    } else if (c == "\"" && esc == 0) {
                        print out
                        exit
                    } else {
                        esc = 0
                        out = out c
                    }
                    i++
                }
                print out
            }
        } else {
            # Already inside content, keep accumulating
            i = 1; esc=0; out=""
            while (i <= length(line)) {
                c = substr(line,i,1)
                if (c == "\\" && esc == 0) {
                    esc = 1
                    out = out c
                } else if (c == "\"" && esc == 0) {
                    print out
                    exit
                } else {
                    esc = 0
                    out = out c
                }
                i++
            }
            print out
        }
    }
    ')

    # 2) interpret backslash-escapes (\n, \", \\) into real characters:
    printf '%s' "$raw" | awk '
    {
        gsub(/\\\\/, "\\", $0)
        gsub(/\\"/, "\"", $0)
        gsub(/\\n/, "\n", $0)
        gsub(/\\r/, "\r", $0)
        gsub(/\\t/, "\t", $0)
        gsub(/\\b/, "\b", $0)
        gsub(/\\f/, "\f", $0)
        print
    }'
}

generate_remote() {
    content=$(cat "$1")

    # Escape for JSON (replace backslash, double quote, and control characters)
    # Use json_escape to safely encode the prompt as a JSON string
    escaped_content=$(printf "%s" "${content}" | json_escape)

    # shellcheck disable=SC2154
    body=$(printf '{"model":"%s","messages":[{"role":"user","content":%s}],"max_completion_tokens":8192}' \
        "${api_model}" "${escaped_content}")

    # shellcheck disable=SC2154
    response=$(curl -s -X POST "${api_url}" \
        -H "Authorization: Bearer ${api_key}" \
        -H "Content-Type: application/json" \
        -d "${body}")

    if [ "$debug" = "true" ]; then
        echo "Response from remote API:" >&2
        echo "${response}" >&2
        #echo "${response}" >> "response.json"
    fi

    # Extract the content field from the response
    result=$(extract_content "${response}")

    #print_debug "Parsed response:$result"
    echo "${result}"
}

run_local() {
    if [ "$debug" = "true" ]; then
        # shellcheck disable=SC2154
        ollama run "${model}" --verbose <"$1"
    else
        ollama run "${model}" <"$1"
    fi
}

# The `generate_response` function generates a response based on the specified mode.
#
# Parameters:
#   $1 - Path to the input file.
#   $2 (optional) - Mode for generating the response. Possible values are 'remote', 'none', or any other value for local generation.
#
# Description:
#   The function determines the mode of operation based on the second argument ($2), falling back to the `model_mode` environment variable, and finally defaulting to 'auto'.
#   If debugging is enabled (via the `debug` environment variable), it prints a debug message indicating the chosen mode.
#
#   Depending on the mode:
#     - 'remote': Calls the `generate_remote` function with the input file path as an argument.
#     - 'none': Outputs the content of the input file directly using `cat`.
#     - Any other value: Calls the `run_local` function with the input file path as an argument.
generate_response() {
    gen_mode="${2:-$model_mode:-auto}"
    print_debug "Generating response using $gen_mode mode"
    case ${gen_mode} in
    remote) generate_remote "$1" ;;
    none) cat "$1" ;;
    *) run_local "$1" ;;
    esac
}

# -------------------------------------------------------------------
# generate_from_prompt: run AI on a built prompt and write or print result
#
#   $1 = path to the prompt file
#   $2 = path to write the response into
#   $3 = (optional) model mode override
# -------------------------------------------------------------------
generate_from_prompt() {
    prompt_file="$1"
    response_output_file="$2"
    gen_mode="${3:-${GIV_MODEL_MODE:-${model_mode:-auto}}}"

    print_debug "Prompt file: $prompt_file"
    print_debug "Output file: $response_output_file"
    print_debug "Model mode: $gen_mode"

    # 1) Invoke the AI
    if ! res=$(generate_response "$prompt_file" "$gen_mode"); then
        printf 'Error: generate_response failed (mode=%s)\n' "$gen_mode" >&2
        exit 1
    fi

    # 2) Dry‐run?  Just print and exit
    if [ "${dry_run:-}" = "true" ] || [ -z "${response_output_file}" ]; then
        printf '%s\n' "$res"
        return 0
    fi

    # 3) Otherwise, write (create or overwrite) the output file
    if printf '%s\n' "$res" >"$response_output_file"; then
        print_info "Response written to $response_output_file"
        return 0
    else
        printf 'Error: Failed to write response to %s\n' "$response_output_file" >&2
        exit 1
    fi
}

# Extract TODO changes for history extraction
extract_todo_changes() {
    range="$1"
    pattern="${2:-$todo_pattern}"

    print_debug "Extracting TODO changes for range: ${range} and pattern ${pattern}"
    # Default to no pattern if not set
    set -- # Reset positional args to avoid confusion

    if [ "${range}" = "--cached" ]; then
        td=$(git --no-pager diff --cached --unified=0 -b -w --no-prefix --color=never -- "${pattern}" 2>/dev/null || true)
    elif [ "${range}" = "--current" ] || [ -z "${range}" ]; then
        td=$(git --no-pager diff --unified=0 -b -w --no-prefix --color=never -- "${pattern}" 2>/dev/null || true)
    else
        td=$(git --no-pager diff "${range}^!" --unified=0 -b -w --no-prefix --color=never -- "${pattern}" 2>/dev/null || true)
    fi
    printf '%s' "${td}"
}

# helper: writes message header based on commit type
get_message_header() {
    commit="$1"
    print_debug "Getting message header for commit $commit"
    case "$commit" in
    --cached) echo "Staged Changes" ;;
    --current | "") echo "Current Changes" ;;
    *) git log -1 --pretty=%B "$commit" ;;
    esac
}

# Finds and returns the path to a version file in the current directory.
# The function checks if the variable 'version_file' is set and points to an existing file.
# If not, it searches for common version files (package.json, pyproject.toml, setup.py, Cargo.toml, composer.json, build.gradle, pom.xml).
# If none are found, it attempts to locate a 'giv.sh' script using git.
# If no suitable file is found, it returns an empty string.
# helper: finds the version file path
find_version_file() {
    print_debug "Finding version file..."
    if [ -n "${version_file}" ] && [ -f "${version_file}" ]; then
        echo "${version_file}"
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

# helper: builds main diff output (tracked + optional untracked)
build_diff() {
    commit="$1"
    diff_pattern="$2"

    # Build git diff command as a string (POSIX-compatible, no arrays)
    diff_cmd="git --no-pager diff"
    case "$commit" in
    --cached) diff_cmd="$diff_cmd --cached" ;;
    --current | "") ;;
    *) diff_cmd="$diff_cmd ${commit}^!" ;;
    esac
    print_debug "Building diff for commit $commit with pattern $diff_pattern"

    diff_cmd="$diff_cmd --minimal --no-prefix --unified=3 --no-color -b -w --compact-summary --color-moved=no"
    if [ -n "$diff_pattern" ]; then
        diff_cmd="$diff_cmd -- \"$diff_pattern\""
    fi

    print_debug "$diff_cmd"
    # shellcheck disable=SC2086
    diff_output=$(eval "$diff_cmd")

    # handle untracked files
    untracked=$(git ls-files --others --exclude-standard)
    OLD_IFS=$IFS
    IFS='
'
    for f in $untracked; do
        [ ! -f "$f" ] && continue
        if [ -n "$diff_pattern" ]; then
            # Only match if the pattern matches the filename (basic glob)
            # shellcheck disable=SC2254
            case "$f" in
            $diff_pattern) ;;
            *) continue ;;
            esac
        fi
        extra=$(git --no-pager diff --no-prefix --unified=0 --no-color -b -w --minimal --compact-summary --color-moved=no --no-index /dev/null "$f" 2>/dev/null || true)
        if [ -n "$diff_output" ] && [ -n "$extra" ]; then
            diff_output="${diff_output}
            ${extra}"
        elif [ -n "$extra" ]; then
            diff_output="$extra"
        fi
    done
    IFS=$OLD_IFS

    printf '%s\n' "$diff_output"
}

# top-level refactored build_history
build_history() {
    hist="$1"
    commit="$2"
    todo_pattern="${3:-${GIV_TODO_PATTERN:-TODO}}"
    diff_pattern="${4:-}"

    print_debug "Building history for commit $commit"
    : >"$hist"

    if [ -z "$commit" ]; then
        commit="--current"
    fi

    # Verify the commit is valid
    if [ "$commit" != "--cached" ] && [ "$commit" != "--current" ] && ! git rev-parse --verify "$commit" >/dev/null 2>&1; then
        printf 'Error: Could not build history for commit: %s\n' "$commit" >&2
        exit 1
    fi

    # header
    msg=$(get_message_header "$commit")
    printf '**Message:** %s\n' "$msg" >>"$hist"

    # version
    vf=$(find_version_file)
    [ -n "$vf" ] && print_debug "Found version file: $vf"
    [ -n "$vf" ] && {
        ver=$(get_version_info "$commit" "$vf")
        [ -n "$ver" ] && printf '**Version:** %s\n' "$ver" >>"$hist"
    }

    # diff
    diff_out=$(build_diff "$commit" "$diff_pattern" "$debug")
    # shellcheck disable=SC2016
    printf '```diff\n%s\n```\n' "$diff_out" >>"$hist"

    # TODO diff
    td=$(extract_todo_changes "$commit" "$todo_pattern")
    print_debug "TODO changes: $td"
    # shellcheck disable=SC2016
    [ -n "$td" ] && printf '\n### TODO Changes\n```diff\n%s\n```\n' "$td" >>"$hist"

    return 0
}

# -------------------------------------------------------------------
# summarize_target: summarize a commit, or an inclusive two-/three-dot
# range, or the working tree/index.
#
#   $1 = target (SHA, range, --current, --cached, or "")
#   $2 = path to write summaries into
#   $3 = (optional) override for model_mode
# -------------------------------------------------------------------
summarize_target() {
    target="$1"
    summaries_file="$2"
    gen_mode="${3:-$model_mode}"

    # 1) Special "current" / "cached" / empty
    if [ -z "$target" ] || [ "$target" = "--current" ] || [ "$target" = "--cached" ]; then
        print_debug "Processing special target: ${target}"
        summarize_commit "$target" "$gen_mode" >>"$summaries_file"
        printf '\n' >>"$summaries_file"
        return
    fi

    # 2) Two- or three-dot range?
    if printf '%s' "$target" | grep -qE '\.\.\.?'; then
        print_debug "Detected commit-range syntax: ${target}"
        # Figure out which sep
        if printf '%s' "$target" | grep -q '\.\.\.'; then
            sep='...'
        else
            sep='..'
        fi

        # Split endpoints
        left="${target%%"$sep"*}"
        right="${target#*"$sep"}"
        print_debug "Range endpoints: left='${left}' right='${right}'"

        # Validate both endpoints
        for c in "$left" "$right"; do
            if ! git rev-parse --verify "$c" >/dev/null 2>&1; then
                printf 'Error: Invalid commit in range: %s\n' "$c" >&2
                exit 1
            fi
        done

        # Summarize left endpoint first
        summarize_commit "$left" "$gen_mode" >>"$summaries_file"
        printf '\n' >>"$summaries_file"

        # Now list & summarize everything in the range (excludes left)
        commits_file=$(portable_mktemp "commits_list_XXXXXX")
        git rev-list --reverse "$target" >"$commits_file"

        while IFS= read -r commit; do
            print_debug "Summarizing commit: $commit"
            summarize_commit "$commit" "$gen_mode" >>"$summaries_file"
            printf '\n' >>"$summaries_file"
        done <"$commits_file"

        rm -f "$commits_file"
        return
    fi

    # 3) Single commit (tags, HEAD~N, SHA, etc.)
    if git rev-parse --verify "$target" >/dev/null 2>&1; then
        print_debug "Summarizing single commit: $target"
        summarize_commit "$target" "$gen_mode" >>"$summaries_file"
        printf '\n' >>"$summaries_file"
        return
    fi

    # 4) Nothing matched → fatal
    print_error "Error: Invalid target: $target"
    exit 1
}

# summarize_commit - Generates a summary for a given commit.
#
# Arguments:
#   $1 - The commit hash or identifier to summarize.
#   $2 - (Optional) The generation mode to use; defaults to the value of $model_mode.
#
# Description:
#   This function creates temporary files to store commit history, prompt, and summary results.
#   It builds the commit history, retrieves version information, and constructs a summary prompt.
#   The prompt is then used to generate a summary response, which is saved to a file and printed.
#
# Outputs:
#   Prints the generated summary to stdout.
#
# Dependencies:
#   - portable_mktemp
#   - print_debug
#   - build_history
#   - find_version_file
#   - get_version_info
#   - build_prompt
#   - generate_response
summarize_commit() {
    commit="$1"
    gen_mode="${2:-${model_mode}}"
    hist=$(portable_mktemp "hist.${commit}.XXXXXX.md")
    pr=$(portable_mktemp "prompt.${commit}.XXXXXX.md")
    res_file=$(portable_mktemp "summary.${commit}.XXXXXX.md")
    print_debug "summarize_commit ${commit} ${hist} ${pr}"
    build_history "${hist}" "${commit}" "${todo_pattern}" "$PATHSPEC"
    sc_version_file=$(find_version_file)
    sc_version=$(get_version_info "${commit}" "${sc_version_file}")
    summary_template=$(build_prompt --version "${sc_version}" "${PROMPT_DIR}/summary_prompt.md" "${hist}")
    print_debug "Using summary prompt: ${summary_template}"
    printf '%s\n' "${summary_template}" >"${pr}"
    res=$(generate_response "${pr}" "${gen_mode}")
    echo "${res}" >"${res_file}"

    printf '%s\n' "${res}"
}

# extract_section <section_name> <markdown_file> [<header_id>]
#
# Prints the matching section (including its heading) and its content
# up to—but not including—the next heading of the same or higher level.
#
#   <section_name>  The literal text of the heading (e.g. "1.0.0" or "Unreleased")
#   <markdown_file> Path to the file to search
#   <header_id>     Heading marker (e.g. "##" or "###"); defaults to "##"
#
# Returns 0 always; prints nothing if file or section is missing.
extract_section() {
    section=$1
    file=$2
    header=${3:-"##"}

    # nothing to do if file absent
    [ ! -f "$file" ] && return 0

    # escape section name for regex
    esc=$(printf '%s' "$section" | sed 's/[][\\/.*^$]/\\&/g')

    # build pattern to find the heading line
    pat="^${header}[[:space:]]*\\[?${esc}\\]?"

    # locate the first matching heading line number
    start=$(grep -nE "$pat" "$file" 2>/dev/null | head -n1 | cut -d: -f1)
    [ -z "$start" ] && return 0

    # count how many "#" in header to get its level
    HL=${#header}

    # build a regex matching any heading of level ≤ HL
    lvl_pat="^#{1,${HL}}[[:space:]]"

    # find the next heading (same or higher level) after start
    offset=$(tail -n +"$((start + 1))" "$file" |
        grep -nE "$lvl_pat" |
        head -n1 |
        cut -d: -f1)

    if [ -n "$offset" ]; then
        end=$((start + offset - 1))
    else
        # no further heading: go to EOF
        end=$(wc -l <"$file")
    fi

    # print from the header line through end
    sed -n "${start},${end}p" "$file"
}
