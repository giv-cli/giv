#! /bin/bash

VERSION="$1"
IMAGE="giv-cli/giv"

# 2) Login to Docker Hub
echo "$DOCKER_HUB_PASSWORD" | docker login \
  --username "$DOCKER_HUB_USERNAME" \
  --password-stdin

# 3) Push both tags
docker push "${IMAGE}:${VERSION}"
docker push "${IMAGE}:latest"