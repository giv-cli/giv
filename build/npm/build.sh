#! /bin/bash

VERSION="$1"
NPM_DIST_DIR="./dist/${VERSION}"
BUILD_TEMP="$2" #/npm/"

# npm build section
#mkdir -p "${NPM_BUILD_TEMP}"
#cp -r src templates "${NPM_BUILD_TEMP}/"
#sed "s/{{VERSION}}/${VERSION}/g" build/npm/package.json > "${NPM_BUILD_TEMP}/package.json"
#cp README.md "${NPM_BUILD_TEMP}/" 

# Copy BUILD_TEMP to DIST_DIR
mkdir -p "${NPM_DIST_DIR}"
rm -rf "${NPM_DIST_DIR}/npm"
cp -rf "${BUILD_TEMP}/package" "${NPM_DIST_DIR}/npm/"
sed "s/{{VERSION}}/${VERSION}/g" build/npm/package.json > "${NPM_DIST_DIR}/npm/package.json"

printf "npm build completed. Files are in %s\n" "${NPM_DIST_DIR}/npm"