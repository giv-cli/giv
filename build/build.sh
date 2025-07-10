#! /bin/bash

mkdir -p .tmp
BUILD_TEMP=$(mktemp -d -p .tmp)
VERSION=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' ../giv/src/giv.sh)
DIST_DIR="./dist/${VERSION}"

printf "Building GIV CLI version %s...\n" "${VERSION}"
mkdir -p "${BUILD_TEMP}/package"
cp -r src templates docs "${BUILD_TEMP}/package/"
cp README.md "${BUILD_TEMP}/package/"
mv "${BUILD_TEMP}/package/src/giv.sh" "${BUILD_TEMP}/package/src/giv"
printf "Using build temp directory: %s\n" "${BUILD_TEMP}"
./build/npm/build.sh "${VERSION}" "${BUILD_TEMP}"
./build/pypi/build.sh "${VERSION}" "${BUILD_TEMP}"
# ./build/snap/build.sh "${VERSION}" "${BUILD_TEMP}"
# ./build/linux/build.sh "${VERSION}" "${BUILD_TEMP}" "deb"
# ./build/linux/build.sh "${VERSION}" "${BUILD_TEMP}" "rpm"
# ./build/flatpak/build.sh "${VERSION}" "${BUILD_TEMP}"
# ./build/homebrew/build.sh "${VERSION}" "${BUILD_TEMP}"
#./build/scoop/build.sh "${VERSION}" "${BUILD_TEMP}"

#rm -rf "${BUILD_TEMP}"
printf "Build completed. Files are in %s\n" "${DIST_DIR}"