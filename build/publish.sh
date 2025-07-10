#! /bin/bash

VERSION=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' ../giv/src/giv.sh)
ROOT_DIR=$(pwd)
./build/npm/publish.sh "${VERSION}" 
cd "$ROOT_DIR" || exit 1