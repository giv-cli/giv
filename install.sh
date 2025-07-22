#!/usr/bin/env sh
set -eu

# --- Configuration ---
REPO="giv-cli/giv"
SCRIPT_NAME="giv.sh"
VERSION=""

# --- 1. Parse args (only --version now) ---
while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="$2"; shift 2;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1;;
  esac
done

# --- 2. Determine USER_BIN_DIR ---
if [ -w "/usr/local/bin" ]; then
  USER_BIN_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ]; then
  USER_BIN_DIR="$HOME/.local/bin"
else
  USER_BIN_DIR="$HOME/bin"
fi

# --- 3. Fetch latest version if unset ---
if [ -z "$VERSION" ]; then
  VERSION="$(curl -s "https://api.github.com/repos/$REPO/releases/latest" \
    | awk -F '"' '/"tag_name"/ {print $4; exit}')"
  if [ -z "$VERSION" ]; then
    printf 'Warning: Could not determine latest release version, defaulting to "main".\n' >&2
    VERSION="main"
  fi
fi

# --- 4. Detect platform ---
detect_platform() {
  OS="$(uname -s)"
  case "$OS" in
    Linux*)
      if [ -f /etc/wsl.conf ] || grep -qi microsoft /proc/version 2>/dev/null; then
        printf 'windows'
      else
        printf 'linux'
      fi;;
    Darwin*)  printf 'macos';;
    CYGWIN*|MINGW*|MSYS*) printf 'windows';;
    *)         printf 'unsupported';;
  esac
}
PLATFORM="$(detect_platform)"
if [ "$PLATFORM" = "unsupported" ]; then
  printf 'Error: Unsupported OS: %s\n' "$(uname -s)" >&2
  exit 1
fi

# --- 5. Compute APP_DIR ---
compute_app_dir() {
  case "$PLATFORM" in
    linux)
      printf '%s/giv' "${XDG_DATA_HOME:-$HOME/.local/share}";;
    windows)
      printf '%s/giv' "${LOCALAPPDATA:-$HOME/AppData/Local}";;
    macos)
      printf '%s/Library/Application Scripts/com.github.%s' "$HOME" "${REPO}";;
  esac
}
APP_DIR="$(compute_app_dir)"

# --- 6. Prepare directories ---
mkdir -p "$USER_BIN_DIR" \
         "$APP_DIR/lib/giv" \
         "$APP_DIR/templates" \
         "$APP_DIR/docs"

# --- 7. Create temp dir and ensure cleanup ---
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- 8. Acquire release source (prefer tarball) ---
SRCDIR=""
if [ "$VERSION" != "main" ]; then
  if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    printf 'Downloading %s tarball…\n' "$VERSION"
    if curl -fsSL "https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz" \
        | tar -xz -C "$TMP"; then
      SRCDIR="$TMP/$(basename "$REPO")-$VERSION"
    else
      printf 'Tarball fetch failed, will fall back to git clone…\n'
    fi
  fi
fi

if [ -z "$SRCDIR" ]; then
  if ! command -v git >/dev/null 2>&1; then
    printf 'Error: git is required if tarball download fails.\n' >&2
    exit 1
  fi
  printf 'Cloning %s at branch %s…\n' "$REPO" "$VERSION"
  git -c advice.detachedHead=false clone -q --depth 1 \
    --branch "$VERSION" "https://github.com/$REPO.git" "$TMP"
  SRCDIR="$TMP"
fi

# --- 9. Install files ---
# Copy library scripts into lib/giv
cp -R "$SRCDIR/src/"*        "$APP_DIR/lib/giv/"
# Copy templates and docs to top-level dirs
cp -R "$SRCDIR/templates/"*  "$APP_DIR/templates/"
cp -R "$SRCDIR/docs/"*       "$APP_DIR/docs/"

# --- 10. Link or copy the main script ---
if [ "$PLATFORM" = "windows" ]; then
  cp -f "$APP_DIR/lib/giv/$SCRIPT_NAME" "$USER_BIN_DIR/giv"
else
  ln -sf "$APP_DIR/lib/giv/$SCRIPT_NAME" "$USER_BIN_DIR/giv"
fi

# --- 11. Warn if PATH isn’t set ---
case ":$PATH:" in
  *":$USER_BIN_DIR:"*) ;;
  *)
    printf 'Warning: %s is not in your PATH.\n' "$USER_BIN_DIR";;
esac

printf 'Installed giv %s → %s\n' "$VERSION" "$USER_BIN_DIR/giv"
printf 'Installed templates to %s\n' "$APP_DIR/templates"
printf 'Installed docs to %s\n' "$APP_DIR/docs"
printf 'Run "giv --help" to get started.\n'
