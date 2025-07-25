#!/usr/bin/env bash
# Allow test harness to inject mock functions (for bats)
if [ -n "$GIV_TEST_MOCKS" ] && [ -f "$GIV_TEST_MOCKS" ]; then
  . "$GIV_TEST_MOCKS"
fi
# giv - A POSIX-compliant script to generate commit messages, summaries,
# changelogs, release notes, and announcements from Git history using AI
set -eu

# Ensure our temp-dir cleanup always runs:
# trap 'remove_tmp_dir' EXIT INT TERM


IFS='
'
GIV_DEBUG="${GIV_DEBUG:-}"
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

detect_platform() {
  OS="$(uname -s)"
  case "$OS" in
    Linux*)
      if [ -f /etc/wsl.conf ] || grep -qi microsoft /proc/version 2>/dev/null; then
        printf 'windows'
      else
        printf 'linux'
      fi;;
    Darwin*)  printf 'macos';;
    CYGWIN*|MINGW*|MSYS*) printf 'windows';;
    *)         printf 'unsupported';;
  esac
}

compute_app_dir() {
  # If running from local repo (e.g., ./src/giv.sh), use $PWD/src as lib dir
  if [ -f "$PWD/src/giv.sh" ]; then
    printf '%s' "$PWD"
    return
  fi
  case "${PLATFORM}" in
    windows)
      printf '%s/giv' "${LOCALAPPDATA:-${HOME}/AppData/Local}";;
    macos)
      printf '%s/Library/Application Scripts/com.github.%s' "${HOME}" "giv-cli/giv";;
    *)
      printf '%s/giv' "${XDG_DATA_HOME:-${HOME}/.local/share}";;
  esac
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
export SCRIPT_DIR

# Allow overrides for advanced/testing/dev
PLATFORM="$(detect_platform)"
APP_DIR="$(compute_app_dir)"
[ "${GIV_DEBUG}" = "true" ] && printf 'Using giv app directory: %s\n' "${APP_DIR}"

SRC_DIR=""
# Library location (.sh files)
if [ -n "${GIV_SRC_DIR:-}" ]; then
    SRC_DIR="${GIV_SRC_DIR}"
elif [ -d "${APP_DIR}/src" ]; then
    SRC_DIR="${APP_DIR}/src"
elif [ -d "${SCRIPT_DIR}" ]; then
    # Local or system install: helpers in same dir
    SRC_DIR="${SCRIPT_DIR}"
elif [ -n "${SNAP:-}" ] && [ -d "${SNAP}/lib/giv" ]; then
    SRC_DIR="${SNAP}/lib/giv"
else
    printf 'Error: Could not find giv lib directory. %s\n' "${SCRIPT_PATH}" >&2
    exit 1
fi

GIV_LIB_DIR="${SRC_DIR}/lib"

[ "${GIV_DEBUG}" = "true" ] && printf 'Using giv lib directory: %s\n' "${GIV_LIB_DIR}"

# shellcheck source=./init.sh
. "$GIV_LIB_DIR/init.sh"


# Ensure basic directory initialization
ensure_giv_dir_init

# Parse all arguments using unified parser
. "$GIV_LIB_DIR/argument_parser.sh"
parse_arguments "$@"

# Show help/version immediately if requested
case "${GIV_SUBCMD:-}" in
    help)
        . "$GIV_SRC_DIR/commands/help.sh"
        exit 0
        ;;
    version)
        . "$GIV_SRC_DIR/commands/version.sh"
        exit 0
        ;;
esac

# Initialize metadata for commands that need it (skip for config/init)
case "${GIV_SUBCMD:-}" in
    config|init)
        # Skip metadata initialization for config/init commands
        ;;
    *)
        initialize_metadata "false"
        ;;
esac

# Validate subcommand requirements
validate_subcommand_requirements

if [ -f "${GIV_SRC_DIR}/commands/${GIV_SUBCMD}.sh" ]; then
    # Delegate to the subcommand script - pass remaining arguments for commands that need them
    [ "${GIV_DEBUG}" = "true" ] && printf 'Executing subcommand: %s\n' "${GIV_SUBCMD}" >&2
    case "${GIV_SUBCMD}" in
        config|init)
            # These commands need access to raw positional arguments
            shift # Remove subcommand name
            "${GIV_SRC_DIR}/commands/${GIV_SUBCMD}.sh" "$@"
            ;;
        *)
            # Other commands use environment variables from unified parser
            "${GIV_SRC_DIR}/commands/${GIV_SUBCMD}.sh"
            ;;
    esac
    exit 0
else
    echo "Unknown subcommand: ${GIV_SUBCMD}" >&2
    echo "Available subcommands: $(find ${GIV_SRC_DIR}/commands -name '*.sh' -exec basename {} .sh \; | sort | tr '\n' ' ')" >&2
    exit 1
fi
