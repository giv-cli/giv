#!/bin/bash
set -euo

VERSION="$1"
_CWD="$(dirname "$(readlink -f "$0")")"
cd "./dist/${VERSION}/flatpak/"
flatpak-builder build-dir flatpak.json --force-clean
cd "${_CWD}"