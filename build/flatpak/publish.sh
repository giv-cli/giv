#!/bin/bash
set -eu

VERSION="$1"

# Check if flatpak-builder is installed
if ! command -v flatpak-builder &> /dev/null; then
    echo "flatpak-builder not found. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y flatpak-builder
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y flatpak-builder
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sy --noconfirm flatpak-builder
    else
        echo "Package manager not supported. Please install flatpak-builder manually."
        exit 1
    fi
fi

cd "./dist/${VERSION}/flatpak/"
flatpak-builder build-dir flatpak.json --force-clean