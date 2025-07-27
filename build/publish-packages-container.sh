#!/bin/bash
set -euo pipefail

# Container-internal publishing script
# This script runs inside the giv-packages container and performs actual publishing

# Parse environment variables
PUBLISH_PACKAGES="${PUBLISH_PACKAGES:-npm,pypi,docker,github}"
DRY_RUN="${DRY_RUN:-false}"
NO_BUILD="${NO_BUILD:-false}"

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

# Function to bump version (assumes __VERSION="X.Y.Z" or __VERSION="X.Y.Z-suffix")
bump_version() {
    local bump="$1"
    local suffix="$2"
    local version_file="src/giv.sh"
    
    # Extract base version (X.Y.Z) and ignore suffix for bumping
    old_version=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' "$version_file")
    
    if [[ -z "$old_version" ]]; then
        echo "ERROR: Could not extract version from $version_file" >&2
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
    if ! sed "s/^__VERSION=\"[^\"]*\"/__VERSION=\"$new_version\"/" "$version_file" > "$version_file.tmp"; then
        echo "ERROR: Failed to update version in $version_file" >&2
        rm -f "$version_file.tmp"
        exit 1
    fi
    
    if ! mv "$version_file.tmp" "$version_file"; then
        echo "ERROR: Failed to replace $version_file" >&2
        rm -f "$version_file.tmp"
        exit 1
    fi
    
    printf '%s %s\n' "$old_version" "$new_version"
}

# Parse arguments
if [[ $# -eq 1 ]]; then
    # Called with specific version
    VERSION="$1"
    echo "Publishing GIV CLI version $VERSION inside container..."
    validate_version_format "$VERSION"
elif [[ $# -eq 2 ]]; then
    # Called with bump type and suffix
    BUMP_TYPE="$1"
    VERSION_SUFFIX="$2"
    validate_bump_type "$BUMP_TYPE"
    
    echo "Publishing GIV CLI using version bump inside container..."
    echo "Bump type: $BUMP_TYPE"
    if [[ -n "$VERSION_SUFFIX" ]]; then
        echo "Version suffix: $VERSION_SUFFIX"
    fi
    
    # Run pre-publish checks
    echo "Running pre-publish checks..."
    if ! bats tests/*.bats >/dev/null 2>&1; then
        echo "ERROR: Tests failed. Aborting publish."
        exit 1
    fi
    
    # Bump version
    echo "Bumping version ($BUMP_TYPE$VERSION_SUFFIX)..."
    version_result=$(bump_version "$BUMP_TYPE" "$VERSION_SUFFIX")
    OLD_VERSION=$(echo "$version_result" | cut -d' ' -f1)
    VERSION=$(echo "$version_result" | cut -d' ' -f2)
    echo "Version bumped: $OLD_VERSION → $VERSION"
    
    # Commit version change
    git add src/giv.sh
    # Note: We don't automatically commit and tag in container
    # That should be done by the host after successful publishing
else
    echo "ERROR: Invalid arguments. Expected version or bump_type + suffix" >&2
    exit 1
fi

echo "Publishing packages: $PUBLISH_PACKAGES"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN MODE - No actual publishing will occur"
fi

# Build packages if not skipping build
if [[ "$NO_BUILD" != "true" ]]; then
    echo "Building packages for version $VERSION..."
    /workspace/build/build-packages-container.sh "$VERSION"
else
    echo "Skipping build step (using existing packages)"
fi

DIST_DIR="./dist/$VERSION"

# Verify required artifacts exist
echo "Verifying build artifacts..."
if [[ ! -d "$DIST_DIR" ]]; then
    echo "ERROR: Distribution directory not found: $DIST_DIR" >&2
    exit 1
fi

# Convert PUBLISH_PACKAGES to array
IFS=',' read -ra PACKAGES_ARRAY <<< "$PUBLISH_PACKAGES"

# Publish to each requested target
for package_type in "${PACKAGES_ARRAY[@]}"; do
    case "$package_type" in
        npm)
            echo "Publishing to npm..."
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "DRY RUN: Would publish npm package from $DIST_DIR/npm/"
            else
                if [[ -f "$DIST_DIR/npm/giv-$VERSION.tgz" ]]; then
                    if [[ -n "${NPM_TOKEN:-}" ]]; then
                        echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > ~/.npmrc
                    fi
                    npm publish "$DIST_DIR/npm/giv-$VERSION.tgz" || echo "WARNING: npm publish failed"
                else
                    echo "WARNING: npm package not found: $DIST_DIR/npm/giv-$VERSION.tgz"
                fi
            fi
            ;;
            
        pypi)
            echo "Publishing to PyPI..."
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "DRY RUN: Would publish PyPI package from $DIST_DIR/pypi/"
            else
                if [[ -d "$DIST_DIR/pypi" ]]; then
                    cd "$DIST_DIR/pypi"
                    if [[ -n "${PYPI_TOKEN:-}" ]]; then
                        python3 -m twine upload --username __token__ --password "$PYPI_TOKEN" dist/* || echo "WARNING: PyPI publish failed"
                    else
                        python3 -m twine upload dist/* || echo "WARNING: PyPI publish failed"
                    fi
                    cd /workspace
                else
                    echo "WARNING: PyPI package directory not found: $DIST_DIR/pypi"
                fi
            fi
            ;;
            
        docker)
            echo "Publishing Docker image..."
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "DRY RUN: Would publish Docker image itlackey/giv:$VERSION"
            else
                if docker image inspect "itlackey/giv:$VERSION" >/dev/null 2>&1; then
                    if [[ -n "${DOCKER_HUB_PASSWORD:-}" ]]; then
                        echo "$DOCKER_HUB_PASSWORD" | docker login -u itlackey --password-stdin
                    fi
                    docker push "itlackey/giv:$VERSION" || echo "WARNING: Docker push failed"
                    docker push "itlackey/giv:latest" || echo "WARNING: Docker push failed"
                else
                    echo "WARNING: Docker image not found: itlackey/giv:$VERSION"
                fi
            fi
            ;;
            
        github)
            echo "Creating GitHub release..."
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "DRY RUN: Would create GitHub release v$VERSION with artifacts"
            else
                # Find release artifacts
                DEB_FILE=$(find "$DIST_DIR" -type f -name '*.deb' | head -n1)
                RPM_FILE=$(find "$DIST_DIR" -type f -name '*.rpm' | head -n1)
                TAR_FILE=$(find "$DIST_DIR" -type f -name '*.tar.gz' | head -n1)
                
                RELEASE_TITLE="v${VERSION}"
                
                # Generate release notes if OLD_VERSION is available
                if [[ -n "${OLD_VERSION:-}" ]]; then
                    echo "Generating release notes..."
                    if ! RELEASE_BODY="$(./src/giv.sh release-notes "v${OLD_VERSION}".."v${VERSION}" --output-version "${VERSION}" 2>/dev/null)"; then
                        echo "WARNING: Failed to generate release notes, using default"
                        RELEASE_BODY="Release ${VERSION}

This release includes various improvements and bug fixes."
                    fi
                else
                    RELEASE_BODY="Release ${VERSION}

This release includes various improvements and bug fixes."
                fi
                
                # Validate release files exist
                echo "Checking release artifacts..."
                missing_files=()
                [[ -f "$DEB_FILE" ]] || missing_files+=("DEB")
                [[ -f "$RPM_FILE" ]] || missing_files+=("RPM") 
                [[ -f "$TAR_FILE" ]] || missing_files+=("TAR")
                
                if [[ ${#missing_files[@]} -gt 0 ]]; then
                    echo "WARNING: Missing release files: ${missing_files[*]}"
                fi
                
                # Create GitHub release
                echo "Creating GitHub release $RELEASE_TITLE..."
                release_args=("$RELEASE_TITLE" "--title" "$RELEASE_TITLE" "--notes" "$RELEASE_BODY")
                
                # Add attachments if they exist
                [[ -f "$DEB_FILE" ]] && release_args+=("--attach" "$DEB_FILE")
                [[ -f "$RPM_FILE" ]] && release_args+=("--attach" "$RPM_FILE")
                [[ -f "$TAR_FILE" ]] && release_args+=("--attach" "$TAR_FILE")
                
                if gh release create "${release_args[@]}"; then
                    echo "Successfully created GitHub release $RELEASE_TITLE"
                else
                    echo "WARNING: Failed to create GitHub release"
                fi
            fi
            ;;
            
        *)
            echo "WARNING: Unknown package type: $package_type"
            ;;
    esac
done

# Run individual package publisher scripts
echo "Running individual publisher scripts..."
for subdir in build/*; do
    if [ -d "$subdir" ] && [ -x "$subdir/publish.sh" ]; then
        package_name=$(basename "$subdir")
        if [[ " ${PACKAGES_ARRAY[*]} " =~ " $package_name " ]] || [[ "$PUBLISH_PACKAGES" == *"all"* ]]; then
            echo "Publishing with $subdir/publish.sh..."
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "DRY RUN: Would run $subdir/publish.sh $VERSION"
            else
                (cd "$subdir" && ./publish.sh "$VERSION") || echo "WARNING: $subdir/publish.sh failed"
            fi
        fi
    fi
done

if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN completed for version $VERSION"
else
    echo "Publish process completed successfully for version $VERSION"
fi