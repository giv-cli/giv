#! /bin/bash

mkdir -p .tmp
BUILD_TEMP=$(mktemp -d -p .tmp)
VERSION=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' ../giv/src/giv.sh)
DIST_DIR="./dist/${VERSION}"

printf "Building GIV CLI version %s...\n" "${VERSION}"

./build/npm/build.sh "${VERSION}" "${BUILD_TEMP}"
./build/pypi/build.sh "${VERSION}" "${BUILD_TEMP}"

rm -rf "${BUILD_TEMP}"
printf "Build completed. Files are in %s\n" "${DIST_DIR}/pypi"