#!/bin/sh
# summary.sh: Generate a summary of changes

# Source initialization script
. "$GIV_LIB_DIR/init.sh"
# Allow test harness to inject mock functions (for bats)
if [ -n "${GIV_TEST_MOCKS:-}" ] && [ -f "${GIV_TEST_MOCKS:-}" ]; then
  . "$GIV_TEST_MOCKS"
fi

# Set defaults for revision and pathspec if not provided
GIV_REVISION="${GIV_REVISION:---current}"
GIV_PATHSPEC="${GIV_PATHSPEC:-}"
export GIV_REVISION
export GIV_PATHSPEC

# All arguments are already parsed by the unified parser
# Use environment variables set by the parser: GIV_REVISION, GIV_PATHSPEC, etc.

# Check if any arguments were provided - if not, fail with usage message
if [ "${GIV_REVISION}" = "--current" ] && [ -z "${GIV_PATHSPEC}" ] && [ $# -eq 0 ]; then
    echo "Missing path argument" >&2
    exit 1
fi

# Set default template for summary
GIV_PROMPT_FILE="${GIV_PROMPT_FILE:-${GIV_TEMPLATE_DIR}/final_summary_prompt.md}"
export GIV_PROMPT_FILE

# Wrapper to call document.sh with appropriate arguments
if [ -f "${GIV_SRC_DIR}/commands/document.sh" ]; then
    # Delegate to the subcommand script - no additional parsing needed
    "${GIV_SRC_DIR}/commands/document.sh"
    exit 0
else
    echo "Available subcommands: $(find "${GIV_SRC_DIR}/commands" -maxdepth 1 -type f -name '*.sh' -exec basename {} .sh \; | tr '\n' ' ')" >&2
    exit 1
fi
