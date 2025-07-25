# How to Build, Validate, and Publish GIV CLI

This guide explains how to use the **containerized build system** to build, validate, and publish the `giv` CLI tool across multiple package managers and platforms.

## Overview

The build system is now **fully containerized** and supports the following package formats:
- **npm** - Node.js package manager
- **PyPI** - Python package index  
- **Debian** - .deb packages for Ubuntu/Debian
- **RPM** - .rpm packages for Fedora/RHEL/CentOS
- **Docker** - Container images
- **Snap** - Universal Linux packages
- **Flatpak** - Linux application sandboxing
- **Homebrew** - macOS package manager
- **Scoop** - Windows package manager

## Containerized Architecture

All build, validation, and publishing operations now run inside a dedicated Docker container (`giv-packages:latest`) that includes all necessary tools and dependencies. This ensures:

- **Consistent Environment**: Same build environment across all machines
- **Isolated Dependencies**: No need to install build tools on host system
- **Reproducible Builds**: Identical results regardless of host OS
- **Easy Setup**: Only Docker is required on the host

## Prerequisites

### Required Tools
- **Docker** - The only requirement for building, validating, and publishing
- **Git** - Version control (already available)

### Authentication Setup
Set environment variables for publishing credentials:

```bash
# npm
export NPM_TOKEN="your-npm-token"

# PyPI  
export PYPI_TOKEN="your-pypi-token"

# Docker Hub
export DOCKER_HUB_PASSWORD="your-dockerhub-password"

# GitHub (for releases)
export GITHUB_TOKEN="your-github-token"
```

**Note**: The container automatically passes through these environment variables when publishing.

## Quick Start

### 1. Build Container and Packages
```bash
# Build the container and all packages for current version
./build/build-packages.sh
```

### 2. Validate All Packages  
```bash
# Validate packages using containerized testing
./build/validate-installs.sh

# Generate validation report
./build/validate-installs.sh -r validation-report.json

# Test specific packages only
./build/validate-installs.sh -p deb,pypi,npm
```

### 3. Publish All Packages
```bash
# Publish to all configured package managers
./build/publish-packages.sh

# Publish specific packages only
./build/publish-packages.sh -p npm,pypi

# Dry run to see what would be published
./build/publish-packages.sh --dry-run
```

## Container Helper Scripts

The containerized build system provides these helper scripts:

### Container Management
```bash
# Build the giv-packages container
./build/container-build.sh

# Force rebuild container (no cache)
./build/container-build.sh -f

# Run interactive shell in container
./build/container-run.sh

# Run specific command in container
./build/container-run.sh ./src/giv.sh --version
```

## Detailed Workflow

### Step 1: Container Setup

The container is automatically built when needed, but you can build it manually:
```bash
# Build container with all build tools
./build/container-build.sh
```

The container includes:
- All package managers (npm, pip, gem, etc.)
- Build tools (fpm, docker, etc.)
- Testing frameworks (bats)
- Publishing tools (twine, gh CLI)

### Step 2: Building Packages

#### Build All Packages
```bash
# Build container and all packages
./build/build-packages.sh

# Build for specific version
./build/build-packages.sh -v 1.2.3

# Force rebuild container first
./build/build-packages.sh -f

# Clean dist directory before build
./build/build-packages.sh -c
```

#### Manual Container Commands
```bash
# Run individual build steps in container
./build/container-run.sh /workspace/build/build-packages-container.sh 1.2.3

# Interactive debugging
./build/container-run.sh -i
```

Built packages are stored in `./dist/{version}/` organized by package type.

### Step 3: Package Validation

The validation framework runs inside the same containerized environment to test package installation and functionality.

#### Validate All Packages
```bash
# Validate default packages (deb, pypi, npm, homebrew)
./build/validate-installs.sh

# Validate with JSON report
./build/validate-installs.sh -r validation-report.json

# Force rebuild container first
./build/validate-installs.sh -f
```

#### Validate Specific Packages
```bash
# Test only specific package types
./build/validate-installs.sh -p deb,pypi

# Test for specific version
./build/validate-installs.sh -v 1.2.3
```

#### Validation Options
```bash
./build/validate-installs.sh [OPTIONS]

Options:
  -v, --version VERSION   Override version detection
  -p, --packages LIST     Comma-separated list of packages to test
                         (deb,rpm,pypi,npm,homebrew,snap)
  -f, --force-build       Force rebuild of container
  -r, --report FILE       Generate validation report
  -h, --help              Show help message
```

#### Understanding Validation Results
```bash
========================================
VALIDATION SUMMARY  
========================================
Total tests: 4
Failures: 0
Success rate: 100%
Report saved to: validation-report.json

All validations passed!
```

**Note**: Some package types (RPM, Snap) may be skipped depending on container base image capabilities.

### Step 4: Publishing Packages

#### Publish All Packages
```bash
# Publish with patch version bump
./build/publish-packages.sh

# Publish with minor version bump
./build/publish-packages.sh minor

# Publish with major version bump and beta suffix
./build/publish-packages.sh major -beta

# Publish specific version
./build/publish-packages.sh -v 1.2.3

# Dry run to see what would be published
./build/publish-packages.sh --dry-run
```

#### Publish to Specific Package Managers
```bash
# Publish only to npm and PyPI
./build/publish-packages.sh -p npm,pypi

# Skip build step (use existing packages)
./build/publish-packages.sh -n

# Force rebuild container first
./build/publish-packages.sh -f
```

#### Publishing Options
```bash
./build/publish-packages.sh [OPTIONS] [BUMP_TYPE] [VERSION_SUFFIX]

Arguments:
  BUMP_TYPE           Version bump type: major, minor, patch (default: patch)
  VERSION_SUFFIX      Version suffix like -beta, -rc1 (optional)

Options:
  -v, --version VERSION   Use specific version instead of bumping
  -p, --packages LIST     Comma-separated list of packages to publish
                         (npm,pypi,docker,github)
  -f, --force-build       Force rebuild of container
  -n, --no-build          Skip build step (use existing packages)
  --dry-run               Show what would be published without doing it
  -h, --help              Show help message
```

### Step 5: Verification

After publishing, verify packages are available:

```bash
# Test npm installation
npm install -g giv
giv --version

# Test PyPI installation  
pip install giv
giv --version

# Test Docker image
docker run itlackey/giv:0.3.0-beta giv --version
```

## Package-Specific Details

### npm Package
- **Build**: Creates tarball in `./dist/{version}/npm/`
- **Validation**: Tests installation via `npm install -g`
- **Publish**: Uploads to npmjs.com registry
- **Installation**: `npm install -g giv`

### PyPI Package  
- **Build**: Creates wheel in `./dist/{version}/pypi/`
- **Validation**: Tests installation via `pip install`
- **Publish**: Uploads to pypi.org using twine
- **Installation**: `pip install giv`

### Debian Package
- **Build**: Creates .deb in `./dist/{version}/`
- **Validation**: Tests installation via `dpkg -i` on Ubuntu/Debian
- **Publish**: Upload to package repository or GitHub releases
- **Installation**: `sudo dpkg -i giv_*.deb`

### RPM Package
- **Build**: Creates .rpm in `./dist/{version}/`  
- **Validation**: Tests installation via `dnf install` on Fedora
- **Publish**: Upload to package repository or GitHub releases
- **Installation**: `sudo dnf install giv-*.rpm`

### Docker Image
- **Build**: Creates multi-architecture image
- **Validation**: Tests container execution and giv functionality
- **Publish**: Pushes to Docker Hub as `itlackey/giv`
- **Usage**: `docker run itlackey/giv giv --help`

## Troubleshooting

### Build Failures
```bash
# Check build logs (verbose)
./build/build-packages.sh 2>&1 | tee build.log

# Debug inside container
./build/container-run.sh -i

# Test specific build steps
./build/container-run.sh /workspace/build/build-packages-container.sh 1.2.3
```

### Validation Failures
```bash
# Run validation with verbose output
./build/validate-installs.sh 2>&1 | tee validation.log

# Debug validation in container
./build/container-run.sh -i
./workspace/build/validate-installs-container.sh 1.2.3
```

### Publish Failures
```bash
# Test publishing in dry-run mode
./build/publish-packages.sh --dry-run

# Check authentication inside container
./build/container-run.sh bash -c "npm whoami; docker info"

# Debug individual publishers
./build/container-run.sh -i
```

### Container Issues
```bash
# Rebuild container from scratch
./build/container-build.sh -f

# Check container exists
docker images giv-packages

# Remove corrupted container
docker rmi giv-packages:latest
```

### Common Issues

1. **Docker not running**: Start Docker daemon
2. **Container build failures**: Check Dockerfile.packages and rebuild with `-f`
3. **Authentication failures**: Ensure environment variables are set correctly
4. **Version conflicts**: Check if version already published
5. **Permission errors**: Ensure Docker user permissions and file ownership
6. **Missing container**: Run `./build/container-build.sh` first

## CI/CD Integration

The containerized build system is ideal for CI/CD pipelines since it only requires Docker:

```yaml
# GitHub Actions example
name: Build and Publish
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build packages
      run: ./build/build-packages.sh
    
    - name: Validate packages
      run: ./build/validate-installs.sh -r validation-report.json
    
    - name: Upload validation report
      uses: actions/upload-artifact@v3
      with:
        name: validation-report
        path: validation-report.json

  publish:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    
    - name: Publish packages
      run: ./build/publish-packages.sh
      env:
        NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
        PYPI_TOKEN: ${{ secrets.PYPI_TOKEN }}
        DOCKER_HUB_PASSWORD: ${{ secrets.DOCKER_HUB_PASSWORD }}
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Benefits for CI/CD:**
- No complex dependency installation steps
- Consistent environment across different CI providers
- Isolated build process
- Easy debugging with container access

## Directory Structure

```
build/
├── Dockerfile.packages                 # Container with all build tools
├── container-build.sh                  # Build giv-packages container
├── container-run.sh                    # Run commands in container
├── build-packages.sh                   # Host: orchestrate containerized build
├── build-packages-container.sh         # Container: actual build logic
├── validate-installs.sh                # Host: orchestrate containerized validation
├── validate-installs-container.sh      # Container: actual validation logic
├── publish-packages.sh                 # Host: orchestrate containerized publishing
├── publish-packages-container.sh       # Container: actual publishing logic
├── config.sh                          # Shared configuration
├── npm/                               # npm package build/publish scripts
├── pypi/                              # PyPI package build/publish scripts
├── docker/                            # Docker image build/publish scripts
├── linux/                             # Debian/RPM package build scripts
├── homebrew/                          # Homebrew formula scripts
├── scoop/                             # Scoop manifest scripts
├── snap/                              # Snap package scripts
└── flatpak/                           # Flatpak package scripts

dist/{version}/                        # Built packages
├── npm/
├── pypi/  
├── deb/
├── rpm/
├── homebrew/
├── scoop/
├── snap/
├── flatpak/
└── docker/
```

**Key Changes:**
- **Container-first approach**: All build/validation/publishing logic runs in containers
- **Host orchestration**: Host scripts manage containers and pass parameters
- **Simplified dependencies**: Only Docker required on host system
- **Consistent environment**: Same tools and versions across all platforms

## Best Practices

1. **Always validate before publishing**: Use `./build/validate-installs.sh` to catch issues early
2. **Use dry-run mode**: Test publishing with `--dry-run` flag first
3. **Use semantic versioning**: Follow semver for version numbers  
4. **Keep authentication secure**: Use environment variables for tokens/passwords
5. **Container management**: Regularly rebuild containers with `-f` to get latest tools
6. **Document changes**: Update changelogs and release notes
7. **Monitor package repositories**: Verify successful publication
8. **Automate in CI/CD**: Leverage containerized approach for consistent CI/CD
9. **Debug in containers**: Use interactive mode (`-i`) for troubleshooting
10. **Version control**: Commit version changes after successful publishing

## Support

For build system issues:
- Review build logs and validation reports
- Use interactive container mode for debugging: `./build/container-run.sh -i`
- Verify Docker is running and container builds successfully
- Check authentication environment variables are set
- Rebuild container if encountering tool issues: `./build/container-build.sh -f`
- Test individual components in dry-run mode
- Consult package manager documentation for publishing issues