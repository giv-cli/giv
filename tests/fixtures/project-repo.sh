#!/usr/bin/env sh
#
# Usage: project-repo.sh <target-dir>
#
# Creates a Git repo in $1 with two commits.
#
set -eu
TARGET="$1"
mkdir -p "$TARGET"
cd "$TARGET"
printf "GIV_TEST_MOCKS=%s\n" "$GIV_TEST_MOCKS" > .env
git init >/dev/null 2>&1
echo "First line" > file.txt
git add file.txt
git commit -m "chore: initial commit" >/dev/null 2>&1
echo "Second line" >> file.txt
git add file.txt
git commit -m "feat: add second line" >/dev/null 2>&1
