#!/usr/bin/env bash
# Called after each test. Cleans up temp project repo.
set -euo pipefail
if [ -d "$PROJECT_DIR" ]; then
  rm -rf "$PROJECT_DIR"
fi
