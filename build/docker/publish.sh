#!/bin/bash
set -euo pipefail

VERSION="$1"
IMAGE="itlackey/giv"

# Validate required environment variables
if [[ -z "${DOCKER_HUB_USERNAME:-}" ]]; then
    echo "ERROR: DOCKER_HUB_USERNAME environment variable not set" >&2
    exit 1
fi

if [[ -z "${DOCKER_HUB_PASSWORD:-}" ]]; then
    echo "ERROR: DOCKER_HUB_PASSWORD environment variable not set" >&2
    exit 1
fi

if [[ -z "${VERSION:-}" ]]; then
    echo "ERROR: VERSION parameter is required" >&2
    exit 1
fi

# Login to Docker Hub using heredoc to avoid password exposure
if ! docker login --username "$DOCKER_HUB_USERNAME" --password-stdin <<< "$DOCKER_HUB_PASSWORD"; then
    echo "ERROR: Failed to login to Docker Hub" >&2
    exit 1
fi

# Push version tag with error handling
if ! docker push "${IMAGE}:${VERSION}"; then
    echo "ERROR: Failed to push ${IMAGE}:${VERSION}" >&2
    exit 1
fi

# Push latest tag with error handling
if ! docker push "${IMAGE}:latest"; then
    echo "ERROR: Failed to push ${IMAGE}:latest" >&2
    exit 1
fi

echo "Successfully pushed ${IMAGE}:${VERSION} and ${IMAGE}:latest"