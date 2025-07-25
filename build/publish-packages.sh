#!/bin/bash
set -euo pipefail

# Input validation functions
validate_version_format() {
    local version="$1"
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
        echo "ERROR: Invalid version format: $version" >&2
        echo "Expected format: X.Y.Z or X.Y.Z-suffix" >&2
        exit 1
    fi
}

validate_bump_type() {
    local bump="$1"
    case "$bump" in
        major|minor|patch) ;;
        *)
            echo "ERROR: Invalid bump type: $bump" >&2
            echo "Valid options: major, minor, patch" >&2
            exit 1
            ;;
    esac
}

# Validate inputs
BUMP_TYPE="${1:-patch}"              # patch, minor, or major
VERSION_SUFFIX="${2:-}"              # e.g., -beta or -rc1 (empty for none)

validate_bump_type "$BUMP_TYPE"

VERSION_FILE="src/giv.sh"

# Validate version file exists
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "ERROR: Version file not found: $VERSION_FILE" >&2
    exit 1
fi

# Function to bump version (assumes __VERSION="X.Y.Z" or __VERSION="X.Y.Z-suffix")
bump_version() {
    bump="$1"
    suffix="$2"
    # Extract base version (X.Y.Z) and ignore suffix for bumping
    old_version=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' "$VERSION_FILE")
    
    if [[ -z "$old_version" ]]; then
        echo "ERROR: Could not extract version from $VERSION_FILE" >&2
        exit 1
    fi
    
    validate_version_format "$old_version"
    
    base_version=$(printf '%s' "$old_version" | cut -d'-' -f1)
    IFS=.
    set -- $base_version
    
    # Validate version components are numeric
    if ! [[ "$1" =~ ^[0-9]+$ ]] || ! [[ "$2" =~ ^[0-9]+$ ]] || ! [[ "$3" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid version components in $old_version" >&2
        exit 1
    fi
    
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
    
    # Validate the new version format
    validate_version_format "$new_version"
    
    # Update version in file with better error handling
    if ! sed "s/^__VERSION=\"[^\"]*\"/__VERSION=\"$new_version\"/" "$VERSION_FILE" > "$VERSION_FILE.tmp"; then
        echo "ERROR: Failed to update version in $VERSION_FILE" >&2
        rm -f "$VERSION_FILE.tmp"
        exit 1
    fi
    
    if ! mv "$VERSION_FILE.tmp" "$VERSION_FILE"; then
        echo "ERROR: Failed to replace $VERSION_FILE" >&2
        rm -f "$VERSION_FILE.tmp"
        exit 1
    fi
    
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

# Generate release notes
echo "Generating release notes..."
if ! RELEASE_BODY="$(./src/giv.sh release-notes "v${OLD_VERSION}".."v${NEW_VERSION}" --output-version "${NEW_VERSION}" 2>/dev/null)"; then
    echo "WARNING: Failed to generate release notes, using default"
    RELEASE_BODY="Release ${NEW_VERSION}

This release includes various improvements and bug fixes."
fi

# Validate release files exist
printf "Checking release artifacts...\n"
missing_files=()
[[ -f "$DEB_FILE" ]] || missing_files+=("DEB")
[[ -f "$RPM_FILE" ]] || missing_files+=("RPM") 
[[ -f "$TAR_FILE" ]] || missing_files+=("TAR")

if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo "WARNING: Missing release files: ${missing_files[*]}"
fi

# Create GitHub release
printf "Creating GitHub release %s...\n" "$RELEASE_TITLE"
release_args=("$RELEASE_TITLE" "--title" "$RELEASE_TITLE" "--notes" "$RELEASE_BODY")

# Add attachments if they exist
[[ -f "$DEB_FILE" ]] && release_args+=("--attach" "$DEB_FILE")
[[ -f "$RPM_FILE" ]] && release_args+=("--attach" "$RPM_FILE")
[[ -f "$TAR_FILE" ]] && release_args+=("--attach" "$TAR_FILE")

if gh release create "${release_args[@]}"; then
    echo "Successfully created GitHub release $RELEASE_TITLE"
else
    echo "ERROR: Failed to create GitHub release" >&2
    exit 1
fi

# 6. Run each publish.sh under build/*/
for subdir in build/*; do
    if [ -d "$subdir" ] && [ -x "$subdir/publish.sh" ]; then
        printf "Publishing with %s/publish.sh...\n" "$subdir"
        (cd "$subdir" && ./publish.sh "$NEW_VERSION")
    fi
done

printf "Publish process complete for v%s.\n" "$NEW_VERSION"
