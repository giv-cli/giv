#!/bin/sh

# Explicitly initialize GIV_HOME and GIV_TEMPLATE_DIR
: "${GIV_HOME:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.giv}"
: "${GIV_TEMPLATE_DIR:=${GIV_HOME}/templates}"

# Ensure GIV_HOME and GIV_TEMPLATE_DIR are initialized

# Source project_metadata for tests and runtime
if [ -n "${BATS_TEST_DIRNAME:-}" ]; then
  . "$BATS_TEST_DIRNAME/../src/project_metadata.sh"
else
  . "${GIV_LIB_DIR}/project_metadata.sh"
fi

# Extract TODO changes for history extraction
extract_todo_changes() {
    range="$1"
    pattern="${2:-$GIV_TODO_PATTERN}"

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
    print_debug "Getting message header for commit ${commit}"
    case "${commit}" in
    --cached) printf "Staged Changes" | sed '/^$/d' | print_md ;;
    --current | "") printf "Current Changes" | sed '/^$/d' | print_md ;;
    *) git log -1 --pretty=%B "${commit}" | sed '/^$/d' | print_md ;;
    esac
}


# get_commit_date - Retrieves the date of a given commit, or the current date for special cases.
#
# Arguments:
#   $1 - The commit hash or identifier to retrieve the date from (e.g., SHA, --current, --cached).
#
# Description:
#   This function returns the date associated with a specific git commit. If the commit is
#   "--current" or "--cached", it returns the current date.
#
# Outputs:
#   Prints the date of the specified commit to stdout.
get_commit_date() {
    commit="$1"

    if [ "$commit" = "--current" ] || [ "$commit" = "--cached" ]; then
        # Return the current date for special cases
        date +"%Y-%m-%d" || { print_error "Failed to retrieve current date"; return 1; }
    else
        # Get the date of the specified commit
        commit_date=$(git show -s --format=%ci "$commit" 2>/dev/null | cut -d' ' -f1)
        if [ -z "$commit_date" ]; then
            print_error "Failed to retrieve date for commit: $commit"
            return 1
        fi
        printf '%s' "$commit_date"
    fi
}

print_commit_metadata() {
    commit="$1"
    commit_version="$(get_metadata_value "version" "$commit")"
    printf '**Project Title:*** %s\n' "$(get_project_title)"
    printf '**Version:*** %s\n' "${commit_version}"
    printf '**Commit ID:*** %s\n' "$commit"
    printf '**Date:** %s\n' "$(get_commit_date "$commit")"
    printf '**Message:** %s\n' "$(get_message_header "$commit")"
}


# Get git diff output for a commit and write to file
get_diff() {
    commit="$1"
    diff_pattern="$2"
    output_file="$3"
    
    print_debug "Getting diff for commit: $commit with pattern: $diff_pattern"
    
    case "$commit" in
        --cached)
            git --no-pager diff --cached --unified=3 --no-prefix --color=never -- $diff_pattern > "$output_file" 2>/dev/null || true
            ;;
        --current | "")
            git --no-pager diff --unified=3 --no-prefix --color=never -- $diff_pattern > "$output_file" 2>/dev/null || true
            ;;
        *)
            git --no-pager diff "${commit}^!" --unified=3 --no-prefix --color=never -- $diff_pattern > "$output_file" 2>/dev/null || true
            ;;
    esac
}

# helper: builds main diff output (tracked + optional untracked)
build_diff() {
    commit="$1"
    diff_pattern="$2"

    # Build git diff command as a string (POSIX-compatible, no arrays)
    # Use consolidated get_diff logic
    diff_file=$(mktemp)
    get_diff "$commit" "$diff_pattern" "$diff_file"
    diff_output=$(cat "$diff_file")
    rm -f "$diff_file"
    # handle untracked files (unchanged)
    untracked=$(git ls-files --others --exclude-standard)
    OLD_IFS=$IFS
    IFS='
'
    for f in $untracked; do
        [ ! -f "$f" ] && continue
        if [ -n "$diff_pattern" ]; then
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

    print_debug "Starting build_history with hist=$hist, commit=$commit, todo_pattern=$todo_pattern, diff_pattern=$diff_pattern"

    history_cache="$GIV_HOME/cache/${commit}-history.md"

    if [ -f "$history_cache" ]; then
        print_debug "Using cached history at $history_cache"
        cat "$history_cache" > "$hist"
        return 0
    fi

    : >"$hist" || { print_error "Failed to create history file: $hist"; return 1; }

    if [ -z "$commit" ]; then
        commit="--current"
    fi

    print_debug "Building history for commit $commit"

    if [ "$commit" != "--cached" ] && [ "$commit" != "--current" ] \
        && ! git rev-parse --verify "$commit" >/dev/null 2>&1; then
        print_error "Error: Could not build history for commit: $commit"
        return 1
    fi

    printf '### Commit ID %s\n' "$commit" >>"$hist" || { print_error "Failed to write commit ID to history file"; return 1; }
    printf '**Date:** %s\n' "$(get_commit_date "$commit")" >>"$hist" || { print_error "Failed to write commit date to history file"; return 1; }

    print_debug "Getting version for commit $commit"
    ver=$(get_metadata_value "version" "$commit" 2>/dev/null || true)
    if [ -n "$ver" ]; then
        print_debug "Version found: $ver"
        printf '**Version:** %s\n' "$ver" >>"$hist" || { print_error "Failed to write version to history file"; return 1; }
    else
        print_debug "No version found for commit $commit"
    fi
  
    print_debug "Getting message header for commit $commit"
    msg=$(get_message_header "$commit") || { print_error "Failed to get message header for commit: $commit"; return 1; }
    print_debug "Message header: $msg"
    printf '**Message:** %s\n' "$msg" >>"$hist" || { print_error "Failed to write message to history file"; return 1; }

    diff_out=$(build_diff "$commit" "$diff_pattern") || { print_error "Failed to build diff for commit: $commit"; return 1; }
    print_debug "Diff output: $diff_out"
    printf '```diff\n%s\n```\n' "$diff_out" >>"$hist" || { print_error "Failed to write diff to history file"; return 1; }

    td=$(extract_todo_changes "$commit" "$todo_pattern") || { print_error "Failed to extract TODO changes for commit: $commit"; return 1; }
    print_debug "TODO changes: $td"
    if [ -n "$td" ]; then
        printf '### TODO Changes\n%s\n' "$td" >>"$hist" || { print_error "Failed to write TODO changes to history file"; return 1; }
    fi
}

# Helper function to handle special targets
handle_special_target() {
    target="$1"
    summaries_file="$2"
    pathspec="$3"

    print_debug "Processing special target: ${target}"
    summarize_commit "$target" "$pathspec" >>"$summaries_file"
    printf '\n' >>"$summaries_file"
}

# Helper function to handle commit ranges
handle_commit_range() {
    target="$1"
    summaries_file="$2"
    pathspec="$3"

    print_debug "Detected commit-range syntax: ${target}"
    sep="$(printf '%s' "$target" | grep -q '\.\.\.' && echo '...' || echo '..')"
    left="${target%%"$sep"*}"
    right="${target#*"$sep"}"

    print_debug "Range endpoints: left='${left}' right='${right}'"
    for c in "$left" "$right"; do
        if ! git rev-parse --verify "$c" >/dev/null 2>&1; then
            printf 'Error: Invalid commit in range: %s\n' "$c" >&2
            exit 1
        fi
    done

    summarize_commit "$left" "$pathspec" >>"$summaries_file"
    printf '\n' >>"$summaries_file"

    commits_file=$(portable_mktemp "commits_list_XXXXXX")
    git rev-list --reverse "$target" >"$commits_file"

    while IFS= read -r commit; do
        print_debug "Summarizing commit: $commit"
        summarize_commit "$commit" "$pathspec" >>"$summaries_file"
        printf '\n' >>"$summaries_file"
    done <"$commits_file"

    rm -f "$commits_file"
}

# Helper function to handle single commits
handle_single_commit() {
    target="$1"
    summaries_file="$2"
    pathspec="$3"

    if ! is_valid_commit "$target"; then
        print_error "Error: Invalid target: $target"
        return 1
    fi

    print_debug "Summarizing single commit: $target"
    summarize_commit "$target" "$pathspec" >>"$summaries_file"
    printf '\n========================\n\n'  >>"$summaries_file"
}

is_valid_commit() {
    [ "$1" = "--current" ] || [ "$1" = "--cached" ] && return 0
    # Check if the commit is a valid git reference
    git rev-parse --verify "$1^{commit}" >/dev/null 2>&1
}

# Modularized summarize_commit function
summarize_commit() {
  commit="$1"
  pathspec="${2:-}"

  print_debug "Starting summarize_commit for commit: $commit"

  summary_cache=$(get_summary_cache "$commit")
  print_debug "Summary cache path: $summary_cache"

  if [ -f "$summary_cache" ]; then
    # Check if cache has proper metadata format (starts with "Commit:")
    if head -1 "$summary_cache" | grep -q "^Commit:"; then
      print_debug "Cache hit for commit: $commit with proper metadata"
      cat "$summary_cache"
      return 0
    else
      print_debug "Cache exists but lacks metadata, regenerating for commit: $commit"
      rm -f "$summary_cache"
    fi
  fi

  hist=$(portable_mktemp "hist.${commit}.XXXXXXX") || { print_error "Failed to create temp file for history"; return 1; }
  pr=$(portable_mktemp "prompt.${commit}.XXXXXXX") || { print_error "Failed to create temp file for prompt"; return 1; }
  res_file=$(portable_mktemp "summary.${commit}.XXXXXXX") || { print_error "Failed to create temp file for summary"; return 1; }

  print_debug "Temporary files created: hist=$hist, prompt=$pr, res_file=$res_file"

  if ! generate_commit_history "$hist" "$commit" "$pathspec"; then
    print_error "Failed to generate commit history for $commit"
    return 1
  fi

  sc_version=$(get_metadata_value "version" "$commit" 2>/dev/null || true)
  print_debug "Commit version: $sc_version"

  summary_template=$(build_commit_summary_prompt "$sc_version" "$hist")
  if [ -z "$summary_template" ]; then
    print_error "Failed to build summary prompt template for commit: $commit"
    return 1
  fi
  print_debug "Summary template generated: ${summary_template}"
  printf '%s\n' "$summary_template" >"$pr"

  # Generate response and write to cache
  if ! generate_response "$pr" >"$res_file"; then
    print_error "Failed to generate response for commit: $commit"
    return 1
  fi

  # Prepend commit metadata to the response
  tmp_output=$(portable_mktemp "output.${commit}.XXXXXXX") || { print_error "Failed to create temp output file"; return 1; }
  print_debug "Saving commit metadata for: $commit"
  save_commit_metadata "$commit" "$tmp_output"
  cat "$res_file" >> "$tmp_output"
  
  mv "$tmp_output" "$summary_cache"
  print_debug "Summary cached at: $summary_cache"
  print_debug "Final output contains: $(head -1 "$summary_cache")"
  cat "$summary_cache"
}

# Generates commit history and saves it to a temporary file.
generate_commit_history() {
    hist_file="$1"
    commit="$2"
    pathspec="$3"

    print_debug "Generating commit history for commit: $commit"
    if ! build_history "$hist_file" "$commit" "$pathspec"; then
        print_error "Failed to build history for commit: $commit"
        return 1
    fi
}

# Builds a summary prompt based on the commit history.
build_commit_summary_prompt() {
    version="$1"
    hist_file="$2"
    template_file="${GIV_TEMPLATE_DIR}/summary_prompt.md"

    print_debug "Building summary prompt using version: $version and history file: $hist_file"

    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi

    if ! build_prompt --version "$version" --template "$template_file" --summary "$hist_file"; then
        print_error "Failed to build prompt for version: $version"
        return 1
    fi
}

# Generates a summary response based on the prompt.
generate_summary_response() {
    prompt_file="$1"

    print_debug "Generating summary response"

    generate_response "$prompt_file"
}

# Function to get the path to the cached summary for a given commit
get_summary_cache() {
  commit="$1"
  echo "$GIV_HOME/cache/${commit}-summary.md"
}

# Function to cache a summary for a given commit
cache_summary() {
  commit="$1"
  summary_file="$2"

  cache_path=$(get_summary_cache "$commit")
  mkdir -p "$(dirname "$cache_path")"
  cp -f "$summary_file" "$cache_path"
}

# Function to create a temporary file with a given prefix
create_temp_file() {
    prefix="$1"
    tmpdir="${GIV_TMP_DIR:-/tmp}"
    mkdir -p "$tmpdir"
    tmpfile=$(mktemp "$tmpdir/${prefix}.XXXXXX")
    # Only clean up the temp file, not the whole temp dir
    trap 'rm -f "$tmpfile"' EXIT
    echo "$tmpfile"
}

# Function to save metadata for a given commit
save_commit_metadata() {
    commit="$1"
    metadata_file="$2"

    print_debug "Saving metadata for commit: $commit"
    printf 'Commit: %s\n' "$commit" >> "$metadata_file"
    printf 'Date: %s\n' "$(get_commit_date "$commit")" >> "$metadata_file"
    printf 'Message: %s\n' "$(get_message_header "$commit")" >> "$metadata_file"
}

summarize_target() {
    target="$1"
    summaries_file="$2"
    pathspec="$3"
    gen_mode="${4:-auto}"  # Default gen_mode to 'auto' if not provided

    print_debug "Starting summarize_target with target: $target, summaries_file: $summaries_file, pathspec: $pathspec, gen_mode: $gen_mode"

    if [ -z "$target" ]; then
        target="--current"
    fi

    case "$target" in
    --current | --cached)
        print_debug "Handling special target: $target"
        handle_special_target "$target" "$summaries_file" "$pathspec"
        ;;
    *...*)
        print_debug "Handling three-dot commit range: $target"
        handle_commit_range "$target" "$summaries_file" "$pathspec"
        ;;
    *..*)
        print_debug "Handling two-dot commit range: $target"
        handle_commit_range "$target" "$summaries_file" "$pathspec"
        ;;
    *)
        print_debug "Handling single commit: $target"
        version=$(get_version_at_commit "$target" "$(get_current_version_for_file)")
        if [ -n "$version" ]; then
            printf 'Version: %s\n' "$version" >> "$summaries_file"
        else
            print_debug "No version found for commit: $target"
        fi
        handle_single_commit "$target" "$summaries_file" "$pathspec"
        ;;
    esac

    print_debug "Finished summarize_target for target: $target"
}

# # Ensure the temporary directory exists
mkdir -p "${GIV_TMP_DIR:-/tmp}"

