#!/usr/bin/env bash

# shellcheck disable=SC3040
set -euo pipefail


VERSION="$1"
PIP_DIST_DIR="./dist/${VERSION}/pypi"
PIP_BUILD_TEMP="$2"

# TEMP_SRC="${PIP_BUILD_TEMP}/src"
# TEMP_TEMPLATES="${PIP_BUILD_TEMP}/templates"

# # Create temporary directories for source and templates
# mkdir -p "${TEMP_SRC}" "${TEMP_TEMPLATES}"

# # Copy all .sh sources to src/ (rename giv.sh to giv)
# cp src/giv.sh "${TEMP_SRC}/giv"
# chmod +x "${TEMP_SRC}/giv"
# find src -type f -name '*.sh' ! -name 'giv.sh' -exec cp {} "${TEMP_SRC}/" \;

# # Copy templates folder
# cp -r templates/* "${TEMP_TEMPLATES}/"

# Collect file lists for setup.py
SH_FILES=$(find "${PIP_BUILD_TEMP}/package/src" -type f -name '*.sh' -print0 | xargs -0 -I{} bash -c 'printf "src/%s " "$(basename "{}")"')
TEMPLATE_FILES=$(find "${PIP_BUILD_TEMP}/package/templates" -type f -print0 | xargs -0 -I{} bash -c 'printf "templates/%s " "$(basename "{}")"')

# Copy built files to output directory
rm -rf "${PIP_DIST_DIR}"
# Create the output directory
mkdir -p "${PIP_DIST_DIR}"
cp -r "${PIP_BUILD_TEMP}/package/"* "${PIP_DIST_DIR}"

# Fill in the setup.py template
sed -e "s|{{VERSION}}|${VERSION}|g" \
    -e "s|{{SH_FILES}}|${SH_FILES}|g" \
    -e "s|{{TEMPLATE_FILES}}|${TEMPLATE_FILES}|g" \
    build/pypi/setup.py > "${PIP_DIST_DIR}/setup.py"

# Copy README if present
#[ -f README.md ] && cp README.md "${PIP_BUILD_TEMP}/"



printf "PyPi build completed. Files are in %s\n" "${PIP_DIST_DIR}"