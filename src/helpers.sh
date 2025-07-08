#!/bin/sh

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
    if [ -z "$GIV_TMPDIR" ]; then

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
    printf '%s\n' "$*" >&2
}
print_warn() {
    printf 'WARNING: %s\n' "$*" >&2
}
print_error() {
    printf 'ERROR: %s\n' "$*" >&2
}

build_prompt() {
    prompt_file="$1"
    diff_file="$2"

    # Concatenate the prompt template and diff file content
    result="$(
        cat "${diff_file}"
        echo "[INSTRUCTIONS]"
        cat "${prompt_file}"
        echo
    )"
    printf "%s\n" "${result}"
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
    body=$(printf '{"model":"%s","messages":[{"role":"user","content":%s}],"max_completion_tokens":8192}' \
        "${api_model}" "${escaped_content}")

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
    if [ "${dry_run:-}" = "true" ]; then
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

# helper: extract version text from a file or git index/commit
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

summarize_commit() {
    commit="$1"
    gen_mode="${2:-$model_mode}"
    hist=$(portable_mktemp "hist.${commit}.XXXXXX.md")
    pr=$(portable_mktemp "prompt.${commit}.XXXXXX.md")
    res_file=$(portable_mktemp "summary.${commit}.XXXXXX.md")
    print_debug "summarize_commit $commit $hist $pr"
    build_history "$hist" "$commit" "$todo_pattern" "$PATHSPEC"
    summary_template=$(build_prompt "${PROMPT_DIR}/summary_prompt.md" "$hist")
    print_debug "Using summary prompt: $summary_template"
    printf '%s\n' "$summary_template" >"$pr"
    res=$(generate_response "$pr" "${gen_mode}")
    echo "${res}" >"$res_file"

    printf '%s\n' "$res"
}

# Ensures that there are blank lines where required in the script or input.
# This function can be used to enforce formatting standards by adding or checking for blank lines.
# Usage:
#   ensure_blank_lines [arguments]
# Arguments:
#   [arguments] - Optional parameters to customize the behavior (if any).
# Returns:
#   None. Modifies input or outputs formatted result as needed.
ensure_blank_lines() {
    printf '%s' "$1" | awk '
    function is_header(l) { return l ~ /^#\s/ }   # "# " or "## " headers
    {
      if (is_header($0)) {
        if (NR > 1 && prev != "") print "";       # blank line **before** header
        print;                                    # the header itself
        prev = $0;  next
      }
      if (prev != "" && is_header(prev)) print "" # blank line **after** header
      print;  prev = $0
    }
    END { if (prev != "") print "" }              # newline-at-EOF
  ' | # 1st pass
        awk 'NF || !blank { print } { blank = !NF }      # de-dupe blank lines
       END { if (!blank) print "" }' # final newline
}

# Remove duplicate blank lines and ensure file ends with newline
remove_duplicate_blank_lines() {
    # $1: file path
    awk 'NR==1{print} NR>1{if (!($0=="" && p=="")) print} {p=$0} END{if(p!="")print ""}' "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

# Extracts a specific section from a changelog file.
#
# Usage:
#   extract_changelog_section <section_name> <changelog_file>
#
# Arguments:
#   section_name    The name of the section to extract (e.g., "Unreleased", "1.0.0").
#   changelog_file  The path to the changelog file.
#
# Output:
#   Prints the contents of the specified section to stdout.
#
# Returns:
#   0 if the section is found or file does not exist, otherwise non-zero.
#
# Notes:
#   - Assumes sections are marked with '## [section_name]' or '## section_name'.
#   - If the section or file is not found, outputs an empty string.
extract_changelog_section() {
    ecs_section="$1"
    ecs_file="$2"
    if [ ! -f "${ecs_file}" ]; then
        echo ""
        return 0
    fi
    ecs_esc=$(echo "${ecs_section}" | sed 's/[][\\/.*^$]/\\&/g')
    ecs_pattern="^##[[:space:]]*\[?${ecs_esc}\]?"
    start_line=$(grep -nE "${ecs_pattern}" "${ecs_file}" | head -n1 | cut -d: -f1)
    if [ -z "${start_line}" ]; then
        echo ""
        return 0
    else
        start_line=$((start_line + 1))
    fi
    end_line=$(tail -n "$((start_line + 1))" "${ecs_file}" | grep -n '^## ' | head -n1 | cut -d: -f1)
    if [ -n "${end_line}" ]; then
        end_line=$((start_line + end_line - 1))
    else
        end_line=$(wc -l <"${ecs_file}")
    fi
    sed -n "${start_line},${end_line}p" "${ecs_file}"
}

# Updates a specific section in a changelog file with new content for a given version.
#
# Arguments:
#   $1 - Path to the changelog file to update.
#   $2 - New content to insert into the changelog section.
#   $3 - Version string to use as the section header (e.g., "1.2.3").
#   $4 - Regular expression pattern to identify the section to update.
#
# Behavior:
#   - If the section matching the pattern exists, replaces its content with the new content under the specified version header.
#   - If the section does not exist, does nothing and returns 1.
#   - Ensures proper blank lines using the `ensure_blank_lines` function.
#
# Returns:
#   0 if the section was updated successfully.
#   1 if the section matching the pattern was not found.
update_changelog_section() {
    ic_file="$1"
    ic_content="$2"
    ic_version="$3"
    ic_pattern="$4"
    content_file=$(mktemp)
    print_debug "Updating changelog section in ${ic_file} with version ${ic_version} and pattern ${ic_pattern}"
    printf "%s\n" "${ic_content}" >"${content_file}"
    if grep -qE "${ic_pattern}" "${ic_file}"; then
        awk -v pat="${ic_pattern}" -v ver="${ic_version}" -v content_file="${content_file}" '
            BEGIN { in_section=0; replaced=0 }
            {
                if ($0 ~ pat && !replaced) {
                    print "";
                    print "## " ver;
                    while ((getline line < content_file) > 0) print line;
                    close(content_file);
                    in_section=1;
                    replaced=1;
                    next
                }
                if (in_section && $0 ~ /^## /) {
                    in_section=0
                }
                if (in_section) {
                    next
                }
                print $0
            }
            ' "${ic_file}" | ensure_blank_lines >"${ic_file}.tmp"
        mv "${ic_file}.tmp" "${ic_file}"
        return 0
    else
        print_debug "No section matching pattern ${ic_pattern} found in ${ic_file}"
        return 1
    fi
}

# prepend_changelog_section inserts a new changelog section at the top of a file after the H1 header.
#
# Arguments:
#   $1 - Path to the changelog file to update.
#   $2 - Content to insert under the new section.
#   $3 - Version string to use as the section header (e.g., "1.2.3").
#
# Behavior:
#   - Always inserts a new section at the top (after the first H1 header), even if a section for the same version already exists.
#   - Preserves the rest of the file content.
#   - Ensures proper formatting with blank lines between sections.
#   - If the content has no '##' headers, inserts as a single block.
#
# Usage:
#   prepend_changelog_section <changelog_file> <section_content> <version>
prepend_changelog_section() {
    ic_file="$1"
    ic_content="$2"
    ic_version="$3"
    content_file=$(portable_mktemp "content.XXXXXX.md")
    tmp_output_file=$(portable_mktemp "ic_file.XXXXXX.md")
    print_debug "Prepending changelog section in ${ic_file} with version ${ic_version}"
    cp "${ic_file}" "${tmp_output_file}"
    printf "%s\n" "$ic_content" >"$content_file"
    print_debug "Prepending changelog section in ${ic_file} with version ${ic_version}"
    {
        # Check if content_file has any '##' headers
        if grep -q '^## ' "$content_file"; then
            # Content has its own sections, insert as-is under the version header
            awk -v ver="$ic_version" -v content_file="$content_file" '
        BEGIN { added=0 }
        {
            if (!added && /^# /) {
                print;
                print "";
                print "## " ver;
                while ((getline line < content_file) > 0) print line;
                close(content_file);
                print "";
                added=1;
                next;
            }
            print;
        }
        END {
            if (!added) {
                print "## " ver;
                while ((getline line < content_file) > 0) print line;
                close(content_file);
                print "";
            }
        }
        ' "$ic_file"
        else
            # Content has no '##' headers, insert as a single block under the version header
            print_debug "Content has no ## headers, inserting as a single block under version ${ic_version}"
            # Insert the version header and content after the first H1 header
            # If no H1 header exists, # Changelog will be added at the top
            # If the file is empty, it will just add the version header and content
            if ! grep -q '^# ' "$ic_file"; then
                print_debug "No H1 header found, adding # Changelog at the top"
                printf '# Changelog\n\n%s\n' "${ic_content}"
            else
                print_debug "Found H1 header, inserting after it"
                # Insert the version header and content after the first H1 header
                ed -s "${ic_file}" <<ED
/#\s.*$/+1
a
${ic_content}
.
wq
ED

                if [ $? -ne 0 ]; then
                    echo "Error: Failed to insert content using ed" >&2
                    exit 1
                fi
                print_debug "Inserted content after H1 header"

            fi

        fi
    } >"$ic_file.tmp"
    #| awk 'NR==1{print} NR>1{if (!($0=="" && p=="")) print} {p=$0} END{if(p!="")print ""}' >"$ic_file.tmp"

    #printf 'Debug: Prepended content to %s\n' "${ic_file}.tmp" >&2

    rm -f "$content_file"
    if mv "$ic_file.tmp" "$ic_file"; then
        print_debug "Prepend completed, updated file ${ic_file}"
        return 0
    else
        printf 'Error: Failed to update changelog file %s\n' "${ic_file}" >&2
        exit 1
    fi

}

# Appends a new changelog section to the specified file.
#
# This function always inserts a new section at the bottom of the changelog file,
# even if a section for the given version already exists (duplicates are not checked).
#
# Arguments:
#   $1 - Path to the changelog file to update.
#   $2 - Content to insert under the new section.
#   $3 - Version string to use as the section header (e.g., "1.2.3").
#
# The function creates a temporary file for the content, appends a new section
# with the specified version header and content, and ensures there are no
# consecutive blank lines in the output file.
# Always inserts a new section at the bottom, even if duplicate exists.
append_changelog_section() {
    ic_file="$1"
    ic_content="$2"
    ic_version="$3"
    content_file=$(mktemp)
    printf "%s\n" "$ic_content" >"$content_file"
    print_debug "Appending changelog section in ${ic_file} with version ${ic_version} and pattern ${ic_pattern}"

    awk -v ver="$ic_version" -v content_file="$content_file" '
    { print }
    END { print ""; print "## " ver; while ((getline line < content_file) > 0) print line; close(content_file); print "" }
    ' "$ic_file" | awk 'NR==1{print} NR>1{if (!($0=="" && p=="")) print} {p=$0} END{if(p!="")print ""}' >"$ic_file.tmp"
    mv "$ic_file.tmp" "$ic_file"
    rm -f "$content_file"
}

# Updates, prepends, or appends a changelog section in the specified file.
#
# Arguments:
#   $1 - Path to the changelog file.
#   $2 - Content to insert into the changelog section.
#   $3 - Section name or version (used as the section header).
#   $4 - Mode of operation: "auto", "update", "prepend", or "append".
#
# Behavior:
#   - In "auto" or "update" mode, updates the section if it exists, otherwise prepends it.
#   - In "prepend" mode, adds the section at the top.
#   - In "append" mode, adds the section at the bottom.
#   - Ensures the changelog file exists.
#   - Adds a "Managed by giv" footer if not present.
#   - Ensures proper blank line formatting and removes duplicate blank lines.
#
# Dependencies:
#   - Requires helper functions: update_changelog_section, prepend_changelog_section,
#     append_changelog_section, ensure_blank_lines, remove_duplicate_blank_lines.
# Update/prepend/append changelog section
update_changelog() {
    ic_file="$1"
    ic_content="$2"
    ic_section_name="$3"
    ic_mode="$4"
    ic_version="$ic_section_name"
    ic_esc_version=$(echo "$ic_version" | sed 's/[][\\/.*^$]/\\&/g')
    ic_pattern="^##[[:space:]]*\[?$ic_esc_version\]?"

    # Create a temp file and copy ic_file into it (or create empty if ic_file doesn't exist)
    tmp_file=$(portable_mktemp "tmp_changelog.XXXXXX.md")
    if [ -f "$ic_file" ]; then
        cp "$ic_file" "$tmp_file"
        printf '# Changelog\n\n' >"$tmp_file"
    else
        : >"$tmp_file"
    fi

    content_file=$(portable_mktemp "tmp_changelog_content.XXXXXX.md")
    cat "$ic_content" >"$content_file"
    ic_content_block=$(cat "$content_file")

    print_debug "Updating changelog section in ${ic_file} with version {$ic_version} and mode $ic_mode"
    case "$ic_mode" in
    auto | update)
        if update_changelog_section "$tmp_file" "$ic_content_block" "$ic_version" "$ic_pattern"; then
            print_debug "Updated existing section for version $ic_version"
        else
            print_debug "No existing section found, prepending new section for version $ic_version"
            prepend_changelog_section "$tmp_file" "$ic_content_block" "$ic_version"
        fi
        ;;
    prepend)
        prepend_changelog_section "$tmp_file" "$ic_content_block" "$ic_version"
        ;;
    append)
        append_changelog_section "$tmp_file" "$ic_content_block" "$ic_version"
        ;;
    *)
        printf 'Unknown mode: %s\n' "$ic_mode" >&2
        return 1
        ;;
    esac

    print_debug "Tagging changelog document"

    if ! tail -n 5 "$tmp_file" | grep -q "Managed by giv"; then
        if printf '\n[Managed by giv](https://github.com/itlackey/giv)\n\n' >>"$tmp_file"; then
            print_debug "Added footer to changelog file $tmp_file"
        else
            print_error "Failed to add footer to changelog file $tmp_file"
            return 1
        fi
    fi
    cat "${tmp_file}"
    print_debug "Ensuring blank line spacing around headers"
    ensure_blank_lines "$(cat "${tmp_file}")" >"${tmp_file}.tmp" && mv "${tmp_file}.tmp" "$tmp_file"
    cat "${tmp_file}"
    print_debug "Removing duplicates blank lines"
    remove_duplicate_blank_lines "$tmp_file"

    # Return the path to the temp file
    cat "$tmp_file"
}
