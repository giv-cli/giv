#! /bin/bash

VERSION="$1"
IMAGE="itlackey/giv"

docker build -f build/docker/Dockerfile \
    -t "${IMAGE}:$VERSION" \
    -t "${IMAGE}:latest" \
    .
