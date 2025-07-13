#! /bin/bash

VERSION="$1"
IMAGE="giv-cli/giv"

docker build -f build/docker/Dockerfile \
    -t "${IMAGE}:$VERSION" \
    -t "${IMAGE}:latest" \
    .
