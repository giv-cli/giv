#!/bin/sh
# init.sh: Initialize the environment for the giv CLI

set -eu
#trap 'remove_tmp_dir' EXIT INT TERM
IFS="\n\t"

# Defaults
## Directory locations
export GIV_HOME="${GIV_HOME:-$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/.giv")}"
export GIV_LIB_DIR="${GIV_LIB_DIR:-}"
export GIV_DOCS_DIR="${GIV_DOCS_DIR:-}"
export GIV_TEMPLATE_DIR="${GIV_TEMPLATE_DIR:-}"
export GIV_TMP_DIR="${GIV_TMP_DIR:-$GIV_HOME/.tmp}"
export GIV_CACHE_DIR="${GIV_CACHE_DIR:-$GIV_HOME/cache}"
export GIV_CONFIG_FILE="${GIV_CONFIG_FILE:-}"

## Debugging
export GIV_DEBUG="${GIV_DEBUG:-}"
export GIV_DRY_RUN="${GIV_DRY_RUN:-}"
export GIV_TMPDIR_SAVE="${GIV_TMPDIR_SAVE:-}"


# Platform & path detection
get_script_dir() {
    target="$1"
    [ -z "${target}" ] && target="$0"
    if command -v readlink >/dev/null 2>&1 && readlink -f "${target}" >/dev/null 2>&1; then
        dirname "$(readlink -f "${target}")"
    else
        cd "$(dirname "${target}")" 2>/dev/null && pwd
    fi
}

detect_platform() {
    OS="$(uname -s)"
    case "$OS" in
        Linux*)
            if [ -f /etc/wsl.conf ] || grep -qi microsoft /proc/version 2>/dev/null; then
                printf 'windows'
            else
                printf 'linux'
            fi;;
        Darwin*) printf 'macos';;
        CYGWIN*|MINGW*|MSYS*) printf 'windows';;
        *) printf 'unsupported';;
    esac
}

compute_app_dir() {
    case "$PLATFORM" in
        linux)
            printf '%s/giv' "${XDG_DATA_HOME:-$HOME/.local/share}";;
        windows)
            printf '%s/giv' "${LOCALAPPDATA:-$HOME/AppData/Local}";;
        macos)
            printf '%s/Library/Application Scripts/com.github.%s' "$HOME" "giv-cli/giv";;
    esac
}

# Initialize paths
SCRIPT_DIR="$(get_script_dir "$0")"
PLATFORM="$(detect_platform)"
APP_DIR="$(compute_app_dir)"

# Export SCRIPT_DIR for external use
export SCRIPT_DIR


# Library location (.sh files)
LIB_DIR=""
if [ -n "${GIV_LIB_DIR:-}" ]; then
    LIB_DIR="${GIV_LIB_DIR}"
elif [ -d "${APP_DIR}/src" ]; then
    LIB_DIR="${APP_DIR}/src"
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

TEMPLATE_DIR=""
if [ -n "${GIV_TEMPLATE_DIR:-}" ]; then
    TEMPLATE_DIR="${GIV_TEMPLATE_DIR}"
elif [ -d "${APP_DIR}/templates" ]; then
    TEMPLATE_DIR="${APP_DIR}/templates"
else
    printf 'Error: Could not find giv template directory.\n' >&2
    exit 1
fi
GIV_TEMPLATE_DIR="${TEMPLATE_DIR}"

DOCS_DIR=""
if [ -n "${GIV_DOCS_DIR:-}" ]; then
    DOCS_DIR="${GIV_DOCS_DIR}"
elif [ -d "${APP_DIR}/docs" ]; then
    DOCS_DIR="${APP_DIR}/docs"
else
    DOCS_DIR=""
fi
GIV_DOCS_DIR="${DOCS_DIR}"

# Export resolved globals
export GIV_LIB_DIR GIV_TEMPLATE_DIR GIV_DOCS_DIR
[ "$GIV_DEBUG" = "true" ] && printf 'Using giv lib directory: %s\n' "${GIV_LIB_DIR}"
[ "$GIV_DEBUG" = "true" ] && printf 'Using giv template directory: %s\n' "${GIV_TEMPLATE_DIR}"
[ "$GIV_DEBUG" = "true" ] && printf 'Using giv docs directory: %s\n' "${GIV_DOCS_DIR}"

# Load shared modules
. "${GIV_LIB_DIR}/config.sh"
. "${GIV_LIB_DIR}/system.sh"
. "${GIV_LIB_DIR}/args.sh"
. "${GIV_LIB_DIR}/markdown.sh"
. "${GIV_LIB_DIR}/llm.sh"
. "${GIV_LIB_DIR}/project/metadata.sh"
. "${GIV_LIB_DIR}/history.sh"
. "${GIV_LIB_DIR}/commands.sh"
