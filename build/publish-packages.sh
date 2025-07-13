#!/bin/sh
set -eu

# snap install core && snap install snapcraft --classic

BUMP_TYPE="${1:-patch}"              # patch, minor, or major
VERSION_SUFFIX="${2:-}"              # e.g., -beta or -rc1 (empty for none)

VERSION_FILE="src/giv.sh"

# Function to bump version (assumes __VERSION="X.Y.Z" or __VERSION="X.Y.Z-suffix")
bump_version() {
    bump="$1"
    suffix="$2"
    # Extract base version (X.Y.Z) and ignore suffix for bumping
    old_version=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' "$VERSION_FILE")
    base_version=$(printf '%s' "$old_version" | cut -d'-' -f1)
    IFS=.
    set -- $base_version
    major=$1; minor=$2; patch=$3
    case "$bump" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            printf 'Unknown bump type: %s\n' "$bump" >&2
            exit 1
            ;;
    esac
    new_version="$major.$minor.$patch"
    if [ -n "$suffix" ]; then
        # Clean up suffix: only allow a leading hyphen and alphanumerics, no spaces
        clean_suffix=$(printf '%s' "$suffix" | sed 's/[^-A-Za-z0-9]//g')
        # Ensure it starts with hyphen
        case "$clean_suffix" in
            -*) ;;
            *) clean_suffix="-$clean_suffix" ;;
        esac
        new_version="$new_version$clean_suffix"
    fi
    # Update version in file
    sed "s/^__VERSION=\"[^\"]*\"/__VERSION=\"$new_version\"/" "$VERSION_FILE" > "$VERSION_FILE.tmp" && mv "$VERSION_FILE.tmp" "$VERSION_FILE"
    printf '%s %s\n' "$old_version" "$new_version"
}

# Function to check/install GitHub CLI (POSIX, Linux/macOS)
ensure_gh() {
    if command -v gh >/dev/null 2>&1; then
        return 0
    fi
    printf "GitHub CLI (gh) not found. Attempting to install...\n"

    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [ "$OS" = "linux" ]; then
        if command -v apt >/dev/null 2>&1; then
            sudo apt update
            sudo apt install -y gh
            return 0
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y gh
            return 0
        fi
    elif [ "$OS" = "darwin" ]; then
        if command -v brew >/dev/null 2>&1; then
            brew install gh
            return 0
        fi
    fi

    printf "Could not auto-install gh. Please install GitHub CLI manually from https://cli.github.com/ and re-run this script.\n" >&2
    exit 1
}


printf "Running pre-build checks...\n"
if ! bats tests/*.bats >/dev/null 2>&1; then
    echo "Tests failed. Aborting build."
    exit 1
fi

# 1. Ensure gh is installed
ensure_gh

# 2. Bump version
printf "Bumping version (%s%s)...\n" "$BUMP_TYPE" "$VERSION_SUFFIX"
set -- $(bump_version "$BUMP_TYPE" "$VERSION_SUFFIX")
OLD_VERSION=$1
NEW_VERSION=$2
printf "Version bumped: %s → %s\n" "$OLD_VERSION" "$NEW_VERSION"

# 3. Commit and tag
git add "$VERSION_FILE"
# git commit -m "Release v$NEW_VERSION"
# git tag "v$NEW_VERSION"

# 4. Build
./build/build.sh

DIST_DIR="./dist/$NEW_VERSION"
DEB_FILE=$(find "$DIST_DIR" -type f -name '*.deb' | head -n1)
RPM_FILE=$(find "$DIST_DIR" -type f -name '*.rpm' | head -n1)
TAR_FILE=$(find "$DIST_DIR" -type f -name '*.tar.gz' | head -n1)

# 5. Create GitHub release and upload artifacts
RELEASE_TITLE="v${NEW_VERSION}"
RELEASE_BODY="$(./src/giv.sh release-notes "v${OLD_VERSION}".."v${NEW_VERSION}" --output-version "${NEW_VERSION}")"

# printf "Creating GitHub release...\n"
# # shellcheck disable=SC2086
# gh release create "$RELEASE_TITLE" \
#     --title "$RELEASE_TITLE" \
#     --notes "$RELEASE_BODY" \
#     ${DEB_FILE:+--attach "$DEB_FILE"} \
#     ${RPM_FILE:+--attach "$RPM_FILE"} \
#     ${TAR_FILE:+--attach "$TAR_FILE"}

# 6. Run each publish.sh under build/*/
for subdir in build/*; do
    if [ -d "$subdir" ] && [ -x "$subdir/publish.sh" ]; then
        printf "Publishing with %s/publish.sh...\n" "$subdir"
        (cd "$subdir" && ./publish.sh "$NEW_VERSION")
    fi
done

printf "Publish process complete for v%s.\n" "$NEW_VERSION"
