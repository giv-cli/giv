#!/bin/sh

GIV_TOKEN_PROJECT_TITLE=""
GIV_TOKEN_VERSION=""
GIV_TOKEN_EXAMPLE=""
GIV_TOKEN_RULES=""

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
    summary_file=$1
    shift

    awk -v summary_file="$summary_file" '
    # ----- helpers --------------------------------------------------------
    function emit_summary(   l) {
        if (summary_file_read || summary_file == "") return
        while ((getline l < summary_file) > 0) print l "\n"
        close(summary_file)
        summary_file_read = 1
    }

    # ----- build the map from env ----------------------------------------
    BEGIN {
        ORS = ""
        for (v in ENVIRON) {
            if (substr(v,1,10) == "GIV_TOKEN_" && v != "GIV_TOKEN_SUMMARY") {
                name = substr(v,11)          # strip the prefix
                map[name] = ENVIRON[v]
            }
        }
    }

    # ----- main loop ------------------------------------------------------
    {
        if (index($0, "[SUMMARY]")) {
            # Split the line on the placeholder so we can inject the diff
            n = split($0, parts, /\[SUMMARY\]/)
            for (i = 1; i <= n; i++) {
                fragment = parts[i]
                for (k in map) gsub("\\[" k "\\]", map[k], fragment)
                printf "%s", fragment
                if (i < n) emit_summary()
            }
            print "\n"
        } else {
            line = $0
            for (k in map) gsub("\\[" k "\\]", map[k], line)
            print line "\n"
        }
    }
    ' "$@"
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

extract_content_from_response() {
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
    result=$(extract_content_from_response "${response}")

    #print_debug "Parsed response:$result"
    echo "${result}"
}
run_local() {
    # Backup original values of OLLAMA_TEMPERATURE and OLLAMA_NUM_CTX
    orig_ollama_temperature="${OLLAMA_TEMPERATURE:-}"
    orig_ollama_num_ctx="${OLLAMA_NUM_CTX:-}"

    export OLLAMA_TEMPERATURE="${3:-0.9}"
    export OLLAMA_NUM_CTX="${4:-32768}"

    if [ "$debug" = "true" ]; then
        # shellcheck disable=SC2154
        ollama run "${model}" --verbose <"$1"
    else
        ollama run "${model}" <"$1"
    fi

    # Reset to original values after the command completes
    export OLLAMA_TEMPERATURE="${orig_ollama_temperature}"
    export OLLAMA_NUM_CTX="${orig_ollama_num_ctx}"
}

# The `generate_response` function generates a response based on the specified mode.
#
# Parameters:
#   $1 - Path to the input file.
#   $2 (optional) - Mode for generating the response. Possible values are 'remote', 'none', or any other value for local generation.
#   $3 (optional) - Temperature setting for the model, if applicable.
#   $4 (optional) - Context window size for the model, if applicable.
#
# Description:
#   The function determines the mode of operation based on the second argument ($2), falling back to the `model_mode` environment variable, and finally defaulting to 'auto'.
#   If debugging is enabled (via the `debug` environment variable), it prints a debug message indicating the chosen mode.
#
#   Depending on the mode:
#     - 'remote': Calls the `generate_remote` function with the input file path as an argument, along with temperature and context window size if provided.
#     - 'none': Outputs the content of the input file directly using `cat`.
#     - Any other value: Calls the `run_local` function with the input file path as an argument, along with temperature and context window size if provided.
generate_response() {
    gen_mode="${2:-$model_mode:-auto}"
    temp="${3:-0.9}"         # Default to a neutral temperature of 1.0
    ctx_window="${4:-32768}" # Default context window size

    print_debug "Generating response using $gen_mode mode with temperature=$temp and context window size=$ctx_window"

    case ${gen_mode} in
    remote)
        generate_remote "$1" "$temp" "$ctx_window"
        ;;
    none)
        cat "$1"
        ;;
    *)
        run_local "$1" "$temp" "$ctx_window"
        ;;
    esac
}

# Function to generate a response from a prompt file and write it to an output file.
#
# Parameters:
#   $1 - Path to the prompt file (required).
#   $2 - Path to the response output file (required).
#   $3 - Generation mode. Defaults to GIV_MODEL_MODE or 'auto' if not set.
#   $4 - Temperature for response generation. Default is 0.9.
#   $5 - Context window size for response generation. Default is 32768.
#
# The function performs the following steps:
# 1) Invokes the AI to generate a response based on the prompt file and parameters.
# 2) If in dry-run mode or if no output file is specified, prints the response and exits.
# 3) Otherwise, writes the generated response to the specified output file.
#
# Returns:
#   0 - Success
#   1 - Error (e.g., generate_response failed or unable to write to output file)
generate_from_prompt() {
    prompt_file="$1"
    response_output_file="$2"
    gen_mode="${3:-${GIV_MODEL_MODE:-${model_mode:-auto}}}"
    temperature="${4:-0.9}"      # Default value for temperature
    context_window="${5:-32768}" # Default value for context window

    print_debug "Prompt file: $prompt_file"
    print_debug "Output file: $response_output_file"
    print_debug "Model mode: $gen_mode"

    # 1) Invoke the AI
    if ! res=$(generate_response "$prompt_file" "$gen_mode" "$temperature" "$context_window"); then
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
        
        extra=$(git --no-pager diff --no-prefix --unified=0 --no-color -b -w \
            --minimal --compact-summary --color-moved=no \
            --no-index /dev/null "$f" 2>/dev/null || true)

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

    # diff for todos
    td=$(extract_todo_changes "$commit" "$todo_pattern")
    print_debug "TODO changes: $td"
    # shellcheck disable=SC2016
    [ -n "$td" ] && printf '\n### TODO Changes\n```diff\n%s\n```\n' "$td" >>"$hist"

    return 0
}

# build_prompt: fill a prompt template with tokens and diff content
#
# Usage:
#   build_prompt \
#     [--project-title X] \
#     [--version V] \
#     [--example E] \
#     [--rules R] \
#     --template TEMPLATE_FILE \
#     --summary SUMMARY_FILE
#
# Exports:
#   GIV_TOKEN_PROJECT_TITLE, GIV_TOKEN_VERSION,
#   GIV_TOKEN_EXAMPLE, GIV_TOKEN_RULES, GIV_TOKEN_SUMMARY
#
# Reads TEMPLATE_FILE, appends instructions, then pipes through replace_tokens
# using SUMMARY_FILE as the summary source.
build_prompt() {
    # default tokens
    project_title="$(parse_project_title)"
    version="${output_version:-${GIV_TOKEN_VERSION:-}}"
    example=""
    rules=""
    template_file=""
    summary_file=""

    # resolve version if unset or 'auto'
    if [ -z "${version}" ] || [ "${version}" = "auto" ]; then
        print_debug "No version set or version is 'auto', trying to find it from version file"
        version_file="$(find_version_file)"
        version="$(get_version_info --current "${version_file:-}")"
    fi

    # parse named options
    while [ $# -gt 0 ]; do
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
        --template)
            template_file=$2
            shift 2
            ;;
        --summary)
            summary_file=$2
            shift 2
            ;;
        *)
            printf 'unknown option: %s\n' "$1" >&2
            return 1
            ;;
        esac
    done

    # require both template and diff
    if [ -z "${template_file}" ]; then
        printf 'Error: --template TEMPLATE_FILE is required\n' >&2
        return 1
    fi
    if [ -z "${summary_file}" ]; then
        printf 'Error: --summary SUMMARY_FILE is required\n' >&2
        return 1
    fi

    print_debug "Building prompt from template: ${template_file}, using diff file: ${summary_file}"

    # validate files exist
    if [ ! -f "${template_file}" ]; then
        printf 'template file not found: %s\n' "${template_file}" >&2
        return 1
    fi
    if [ ! -f "${summary_file}" ]; then
        printf 'diff file not found: %s\n' "${summary_file}" >&2
        return 1
    fi

    # export token env vars for replace_tokens
    unset GIV_TOKEN_SUMMARY
    export GIV_TOKEN_PROJECT_TITLE="${project_title:-${GIV_TOKEN_PROJECT_TITLE}}"
    export GIV_TOKEN_VERSION="${version:-${GIV_TOKEN_VERSION}}"
    export GIV_TOKEN_EXAMPLE="${example:-${GIV_TOKEN_EXAMPLE}}"
    export GIV_TOKEN_RULES="${rules:-${GIV_TOKEN_RULES}}"

    # combine template + instructions, then replace tokens using diff as summary
    {
        cat "${template_file}"
        printf '\nOutput just the final content—no extra commentary or code fencing. '
        printf 'Use only information contained in this prompt and the summaries provided above.\n'
    } | replace_tokens "${summary_file}"

    return
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
    summary_template=$(build_prompt --version "${sc_version}" \
        --template "${TEMPLATE_DIR}/summary_prompt.md" --summary "${hist}")
    print_debug "Using summary prompt: ${summary_template}"
    printf '%s\n' "${summary_template}" >"${pr}"
    res=$(generate_response "${pr}" "${gen_mode}" "0.9" "32768")
    echo "${res}" >"${res_file}"

    printf '%s\n' "${res}"
}
# -------------------------------------------------------------------
# cmd_document: generic driver for any prompt template
#
# Arguments:
#   $1 = full path to prompt template file
#   $2 = revision specifier     (e.g. "--current" or "$REVISION")
#   $3 = output file path
#   $4 = model mode             (e.g. "auto", "your-model")
#   $5 = temperature            (e.g. "0.7", "0.6")
#   $6 = context window size    (optional; e.g. "65536")
#   $7… = extra flags for build_prompt (e.g. --example, --rules)
#
# Side-effects:
#   - Summaries are written to a temp file
#   - A prompt is built and written to another temp file
#   - generate_from_prompt is invoked to create the final output
#
cmd_document() {
    prompt_tpl="$1"
    revision="${2:---current}"
    out="${3:-}"
    mode="${4:-auto}"
    temp="${5:-0.9}"
    ctx="${6:-32768}"
    shift 6

    # validate template exists
    if [ ! -f "${prompt_tpl}" ]; then
        printf 'template file not found: %s\n' "${prompt_tpl}" >&2
        exit 1
    fi

    # derive base name for temp file prefixes
    doc_base=$(basename "${prompt_tpl%.*}")

    # 1) Summarize
    summaries=$(portable_mktemp "${doc_base}_summaries_XXXXXX.md")
    print_debug "Generating summaries to: ${summaries}"
    summarize_target "${revision}" "${summaries}" "${mode}"

    # bail if no summaries
    if [ ! -f "${summaries}" ]; then
        printf 'Error: No summaries generated for %s.\n' "${revision}" >&2
        exit 1
    fi

    # 2) Build prompt
    prompt_tmp=$(portable_mktemp "${doc_base}_prompt_XXXXXX.md")
    title=$(parse_project_title "${summaries}")
    current_version="$(get_version_info --current "$(find_version_file)" )"

    print_debug "Building prompt from ${prompt_tpl} using ${summaries}"
    build_prompt \
      --project-title "${title}" \
      --version "${current_version}" \
      --template "${prompt_tpl}" \
      --summary "${summaries}" \
      "$@" >"${prompt_tmp}"

    print_debug "Built prompt file: ${prompt_tmp}"

    # 3) Generate final document
    if [ -n "${ctx}" ]; then
        generate_from_prompt "${prompt_tmp}" "${out}" "${mode}" "${temp}" "${ctx}"
    else
        generate_from_prompt "${prompt_tmp}" "${out}" "${mode}" "${temp}"
    fi
}

