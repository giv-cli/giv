#!/usr/bin/env bash

# shellcheck disable=SC3040
set -euo pipefail


VERSION="$1"
PIP_DIST_DIR="./dist/${VERSION}/pypi"
PIP_BUILD_TEMP="$2"

# Copy built files to output directory
rm -rf "${PIP_DIST_DIR}"
# Create the output directory
mkdir -p "${PIP_DIST_DIR}"
cp -r "${PIP_BUILD_TEMP}/package/"* "${PIP_DIST_DIR}"

# ─── 1) SRC files ─────────────────────────────────────────────────────────────
SRC_FILES_PY=$(find "${2}/package/src" \
    -type f -name '*.sh' \
    -printf '"src/%P", ')
if [ -n "$SRC_FILES_PY" ]; then
  SRC_FILES_PY="${SRC_FILES_PY%, }"
else
  SRC_FILES_PY=""
fi

# ─── 2) TEMPLATE files ────────────────────────────────────────────────────────
TEMPLATE_FILES_PY=$(find "${2}/package/templates" \
    -type f -name '*.md'  \
    -printf '"templates/%P", ')
if [ -n "$TEMPLATE_FILES_PY" ]; then
  TEMPLATE_FILES_PY="${TEMPLATE_FILES_PY%, }"
else
  TEMPLATE_FILES_PY=""
fi

# ─── 3) DOCS files ───────────────────────────────────────────────────────────
DOCS_FILES_PY=$(find "${2}/package/docs" \
    -type f -name '*.md' \
    -printf '"docs/%P", ')
if [ -n "$DOCS_FILES_PY" ]; then
  DOCS_FILES_PY="${DOCS_FILES_PY%, }"
else
  DOCS_FILES_PY=""
fi

# Fill in the setup.py template
sed -e "s|{{VERSION}}|${VERSION}|g" \
    -e "s|{{SH_FILES}}|${SRC_FILES_PY}|g" \
    -e "s|{{TEMPLATE_FILES}}|${TEMPLATE_FILES_PY}|g" \
    -e "s|{{DOCS_FILES}}|${DOCS_FILES_PY}|g" \
    build/pypi/setup.py > "${PIP_DIST_DIR}/setup.py"

# Copy README if present
#[ -f README.md ] && cp README.md "${PIP_BUILD_TEMP}/"



printf "PyPi build completed. Files are in %s\n" "${PIP_DIST_DIR}"