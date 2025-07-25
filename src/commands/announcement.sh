#!/bin/sh
# announcement.sh: Generate a marketing-style announcement

# # Source initialization script
# . "$GIV_LIB_DIR/init.sh"

# Wrapper to call document.sh with appropriate arguments
if [ -f "${GIV_SRC_DIR}/commands/document.sh" ]; then
    # Delegate to the subcommand script
    "${GIV_SRC_DIR}/commands/document.sh" "$@" \
        --template "${GIV_TEMPLATE_DIR}/announcement_prompt.md"
    exit 0
else
    echo "Available subcommands: $(find "${GIV_SRC_DIR}/commands" -maxdepth 1 -type f -name '*.sh' -exec basename {} .sh \; | tr '\n' ' ')" >&2
    exit 1
fi
