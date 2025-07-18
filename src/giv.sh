#!/bin/sh
# giv - A POSIX-compliant script to generate commit messages, summaries,
# changelogs, release notes, and announcements from Git history using AI
__VERSION="0.3.0-beta"

set -eu

# Ensure our temp-dir cleanup always runs:
# trap 'remove_tmp_dir' EXIT INT TERM

IFS='
'


# -------------------------------------------------------------------
# Path detection for libraries, templates, and docs (POSIX compatible)
# -------------------------------------------------------------------

# Get the directory where this script is located (absolute, even if symlinked)
get_script_dir() {
    # $1: path to script (may be $0 or a shell-specific value)
    target="$1"
    [ -z "${target}" ] && target="$0"
    # Prefer readlink -f if available, fallback to manual cd/pwd
    if command -v readlink >/dev/null 2>&1 && readlink -f "${target}" >/dev/null 2>&1; then
        dirname "$(readlink -f "${target}")"
    else
        cd "$(dirname "${target}")" 2>/dev/null && pwd
    fi
}
get_is_sourced(){
    # Detect if sourced (works in bash, zsh, dash, sh)
    _is_sourced=0
    # shellcheck disable=SC2296
    # if [ "${BATS_TEST_FILENAME:-}" ]; then
    #     _is_sourced=1
    # el
    if [ "$(basename -- "$0")" = "sh" ] || [ "$(basename -- "$0")" = "-sh" ]; then
        _is_sourced=1
    elif [ "${0##*/}" = "dash" ] || [ "${0##*/}" = "-dash" ]; then
        _is_sourced=1
    elif [ -n "${ZSH_EVAL_CONTEXT:-}" ] && case $ZSH_EVAL_CONTEXT in *:file) true;; *) false;; esac; then
        _is_sourced=1
    elif [ -n "${KSH_VERSION:-}" ] && [ -n "${.sh.file:-}" ] && [ "${.sh.file}" != "" ] && [ "${.sh.file}" != "$0" ]; then
        _is_sourced=1
    elif [ -n "${BASH_VERSION:-}" ] && [ -n "${BASH_SOURCE:-}" ] && [ "${BASH_SOURCE}" != "$0" ]; then
        _is_sourced=1
    fi
    echo "${_is_sourced}"
}

# Try to detect the actual script path
SCRIPT_PATH="$0"
# shellcheck disable=SC2296
if [ -n "${BASH_SOURCE:-}" ]; then
    SCRIPT_PATH="${BASH_SOURCE}"
elif [ -n "${ZSH_VERSION:-}" ] && [ -n "${(%):-%x}" ]; then
    SCRIPT_PATH="${(%):-%x}"
fi
SCRIPT_DIR="$(get_script_dir "${SCRIPT_PATH}")"

# Allow overrides for advanced/testing/dev
LIB_DIR=""
TEMPLATE_DIR=""
DOCS_DIR=""

# Library location (.sh files)
if [ -n "${GIV_LIB_DIR:-}" ]; then
    LIB_DIR="${GIV_LIB_DIR}"
elif [ -d "/usr/local/lib/giv" ]; then
    LIB_DIR="/usr/local/lib/giv"
elif [ -d "${SCRIPT_DIR}" ]; then
    # Local or system install: helpers in same dir
    LIB_DIR="${SCRIPT_DIR}"
elif [ -n "${SNAP:-}" ] && [ -d "${SNAP}/lib/giv" ]; then
    LIB_DIR="${SNAP}/lib/giv"
else
    printf 'Error: Could not find giv lib directory. %s\n' "$SCRIPT_PATH" >&2
    exit 1
fi
GIV_LIB_DIR="${LIB_DIR}"

# Template location
if [ -n "${GIV_TEMPLATE_DIR:-}" ]; then
    TEMPLATE_DIR="${GIV_TEMPLATE_DIR}"
elif [ -d "${LIB_DIR}/../templates" ]; then
    TEMPLATE_DIR="${LIB_DIR}/../templates"
elif [ -d "/usr/local/share/giv/templates" ]; then
    TEMPLATE_DIR="/usr/local/share/giv/templates"
elif [ -n "${SNAP:-}" ] && [ -d "${SNAP}/share/giv/templates" ]; then
    TEMPLATE_DIR="${SNAP}/share/giv/templates"
else
    printf 'Error: Could not find giv template directory.\n' >&2
    exit 1
fi
GIV_TEMPLATE_DIR="${TEMPLATE_DIR}"

# Docs location (optional)
if [ -n "${GIV_DOCS_DIR:-}" ]; then
    DOCS_DIR="${GIV_DOCS_DIR}"
elif [ -d "${LIB_DIR}/../docs" ]; then
    DOCS_DIR="${LIB_DIR}/../docs"
elif [ -d "/usr/local/share/giv/docs" ]; then
    DOCS_DIR="/usr/local/share/giv/docs"
elif [ -n "${SNAP:-}" ] && [ -d "${SNAP}/share/giv/docs" ]; then
    DOCS_DIR="${SNAP}/share/giv/docs"
else
    DOCS_DIR=""  # It's optional; do not fail if not found
fi
GIV_DOCS_DIR="${DOCS_DIR}"

# shellcheck source=./config.sh
. "${LIB_DIR}/config.sh"
# shellcheck source=./system.sh
. "${LIB_DIR}/system.sh"
# shellcheck source=./args.sh
. "${LIB_DIR}/args.sh"
# shellcheck source=markdown.sh
. "${LIB_DIR}/markdown.sh"
# shellcheck source=llm.sh
. "${LIB_DIR}/llm.sh"
# shellcheck source=project.sh
. "${LIB_DIR}/project.sh"
# shellcheck source=history.sh
. "${LIB_DIR}/history.sh"
# shellcheck source=commands.sh
. "${LIB_DIR}/commands.sh"


is_sourced="$(get_is_sourced)"
if [ "${is_sourced}" -eq 0 ]; then
    # Ensure .giv directory is initialized
    ensure_giv_dir_init
    portable_mktemp_dir
    parse_args "$@"

    # # Verify the PWD is a valid git repository
    # if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    #     printf 'Error: Current directory is not a valid git repository.\n'
    #     exit 1
    # fi
    # # Enable debug mode if requested
    # if [ "${debug}" = "true" ]; then
    #     set -x
    # fi


    # Dispatch logic
    case "${subcmd}" in
    message | msg) cmd_message "${GIV_REVISION}" \
        "${GIV_PATHSPEC}" \
        "${GIV_TODO_PATTERN}" \
        "${GIV_MODEL_MODE}" ;;
    document | doc) cmd_document \
      "${prompt_file}" \
      "${GIV_REVISION}" \
      "${GIV_PATHSPEC}" \
      "${output_file:-}" \
      "${GIV_MODEL_MODE}" \
      "0.7" "" ;;
    summary) cmd_document \
      "${GIV_TEMPLATE_DIR}/final_summary_prompt.md" \
      "${GIV_REVISION}" \
      "${GIV_PATHSPEC}" \
      "${output_file:-}" \
      "${GIV_MODEL_MODE}" \
      "0.7" "" ;;
    release-notes) cmd_document \
      "${GIV_TEMPLATE_DIR}/release_notes_prompt.md" \
      "${GIV_REVISION}" \
      "${GIV_PATHSPEC}" \
      "${output_file:-$release_notes_file}" \
      "${GIV_MODEL_MODE}" \
      "0.6" \
      "65536" ;;
    announcement)  cmd_document \
      "${GIV_TEMPLATE_DIR}/announcement_prompt.md" \
      "${GIV_REVISION}" \
      "${GIV_PATHSPEC}" \
      "${output_file:-$announce_file}" \
      "${GIV_MODEL_MODE}" \
      "0.5" \
      "65536" ;;
    changelog) cmd_changelog "${GIV_REVISION}" "${GIV_PATHSPEC}" ;;
    help)
        show_help
        exit 0
        ;;
    available-releases)
        get_available_releases
        ;;
    update)
        run_update "latest"
        ;;
    init)
        ensure_giv_dir_init
        if [ -d "${GIV_TEMPLATE_DIR}" ]; then
            cp -r "${GIV_TEMPLATE_DIR}"/* "$(pwd)/.giv/templates/"
            print_info "Templates copied to .giv/templates."
        else
            print_error "Template directory not found: ${GIV_TEMPLATE_DIR}"
            exit 1
        fi
        ;;
    *) cmd_message "${GIV_REVISION}" ;;
    esac

    if [ -z "${GIV_TMPDIR_SAVE:-}" ]; then
        # Clean up temporary directory if it was created
        remove_tmp_dir
    fi
fi
