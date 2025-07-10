#! /bin/bash

VERSION="$1"
cd "./dist/${VERSION}/npm" || exit 1
npm publish --access public