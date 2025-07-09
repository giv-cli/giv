#!/usr/bin/env sh

set -eu

# Repository and filenames
REPO="giv-cli/giv"
SCRIPT_NAME="giv.sh"
USER_BIN_DIR=""
APP_DIR=""
VERSION=""
USER_BIN_DIR_OVERRIDE=""

# 1. Remove existing giv binary or symlink
if command -v giv >/dev/null 2>&1; then
  OLD_PATH="$(command -v giv)"
  rm -f "$OLD_PATH"
fi

# 2. Parse args
while [ $# -gt 0 ]; do
  case "$1" in
  --version)
    VERSION="$2"
    shift 2
    ;;
  --install-dir)
    USER_BIN_DIR_OVERRIDE="$2"
    shift 2
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    exit 1
    ;;
  esac
  # no extra shift
  break
done

# 3. Determine USER_BIN_DIR
if [ -n "$USER_BIN_DIR_OVERRIDE" ]; then
  USER_BIN_DIR="$USER_BIN_DIR_OVERRIDE"
elif [ -w "/usr/local/bin" ]; then
  USER_BIN_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ]; then
  USER_BIN_DIR="$HOME/.local/bin"
else
  USER_BIN_DIR="$HOME/bin"
fi

# 4. Determine VERSION if not set
if [ -z "$VERSION" ]; then
  VERSION="$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | awk -F '"' '/"tag_name"/ {print $4; exit}')"
fi

# 5. Detect platform
detect_platform() {
  OS="$(uname -s)"
  case "$OS" in
  Linux*)
    if [ -f /etc/wsl.conf ] || grep -qi microsoft /proc/version 2>/dev/null; then
      printf 'windows'
    else
      printf 'linux'
    fi
    ;;
  Darwin*) printf 'macos' ;;
  CYGWIN* | MINGW* | MSYS*) printf 'windows' ;;
  *) printf 'unsupported' ;;
  esac
}
PLATFORM="$(detect_platform)"
if [ "$PLATFORM" = "unsupported" ]; then
  printf 'Error: Unsupported OS: %s\n' "$(uname -s)" >&2
  exit 1
fi

# 6. Compute APP_DIR based on PLATFORM
compute_app_dir() {
  case "$PLATFORM" in
  linux)
    printf '%s/giv' "${XDG_DATA_HOME:-$HOME/.local/share}"
    ;;
  windows)
    printf '%s/giv' "${LOCALAPPDATA:-$HOME/AppData/Local}"
    ;;
  macos)
    printf '%s/Library/Application Scripts/com.github.%s' "$HOME" "${REPO}"
    ;;
  *)
    printf 'Error: Unsupported platform: %s\n' "${PLATFORM}" >&2
    exit 1
    ;;
  esac
}
APP_DIR="$(compute_app_dir)"

# 8. Create necessary directories
mkdir -p "$USER_BIN_DIR" "$APP_DIR/templates"
mkdir -p "$USER_BIN_DIR" "$APP_DIR/src"

# 9. Check Git version for sparse-checkout
if ! command -v git >/dev/null 2>&1; then
  printf 'Error: git is required to use giv.\n' >&2
  exit 1
fi



# 10. Fetch repo
TMP="$(mktemp -d)"
printf 'Installing version %s\n' "$VERSION"
git -c advice.detachedHead=false clone -q --depth 1 --branch "$VERSION" "https://github.com/$REPO.git" "$TMP"
cp -Ri "$TMP/templates/*" "$APP_DIR/templates/"
cp -Ri "$TMP/src/*" "$APP_DIR/"
chmod +x "$APP_DIR/$SCRIPT_NAME"
printf 'Prompts → %s/%s\n' "$APP_DIR" "templates"
rm -rf "$TMP"

# 11. Install giv.sh and create symlink or fallback copy
if [ "$PLATFORM" = "windows" ]; then
  cp -f "$APP_DIR/$SCRIPT_NAME" "$USER_BIN_DIR/giv"
else
  ln -sf "$APP_DIR/$SCRIPT_NAME" "$USER_BIN_DIR/giv"
fi
printf 'giv.sh → %s/%s (symlink/copy) %s/giv\n' "$APP_DIR" "$SCRIPT_NAME" "$USER_BIN_DIR"


# 12. Final PATH check
case ":$PATH:" in
*":$USER_BIN_DIR:"*) ;;
*) printf 'Warning: %s is not in your PATH.\n' "$USER_BIN_DIR" ;;
esac
printf 'Installation complete!\n'
