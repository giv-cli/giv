#!/bin/sh
set -e

IMAGE=giv-build

echo "Building Docker image..."
docker build -t "$IMAGE" -f build/Dockerfile.packages .

echo "Building packages inside container..."
docker run --rm \
    -v "$(pwd)":/workspace "$IMAGE" /workspace/build/build-packages.sh

echo "Validating installs inside container..."
docker run --rm \
    -v "$(pwd)":/workspace "$IMAGE" /workspace/build/validate-installs.sh
