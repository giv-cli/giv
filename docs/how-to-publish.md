# How to Build, Validate, and Publish GIV CLI

This guide explains how to use the build system to build, validate, and publish the `giv` CLI tool across multiple package managers and platforms.

## Overview

The build system supports the following package formats:
- **npm** - Node.js package manager
- **PyPI** - Python package index  
- **Debian** - .deb packages for Ubuntu/Debian
- **RPM** - .rpm packages for Fedora/RHEL/CentOS
- **Docker** - Container images
- **Snap** - Universal Linux packages
- **Flatpak** - Linux application sandboxing
- **Homebrew** - macOS package manager
- **Scoop** - Windows package manager

## Prerequisites

### Required Tools
- **Docker** - For building packages and running validation tests
- **Git** - Version control (already available)
- **jq** - JSON processing (for validation reports)

### Authentication Setup
Before publishing, set up authentication for each target:

```bash
# npm
npm login

# PyPI  
pip install twine
# Configure ~/.pypirc with credentials

# Docker Hub
docker login

# GitHub (for releases)
gh auth login
```

## Quick Start

### 1. Build All Packages
```bash
# Build all packages for current version
./build/build-packages.sh
```

### 2. Validate All Packages  
```bash
# Validate all packages across default platforms (Ubuntu, Fedora)
./build/test/validation/package-validator.sh -b -c

# Generate validation report
./build/test/validation/package-validator.sh -b -c -r validation-report.json
```

### 3. Publish All Packages
```bash
# Publish to all configured package managers
./build/publish-packages.sh
```

## Detailed Workflow

### Step 1: Version Management

The version is automatically detected from `src/lib/system.sh`:
```bash
export __VERSION="0.3.0-beta"
```

Check current version:
```bash
source build/config.sh && get_version
```

### Step 2: Building Packages

#### Build All Packages
```bash
./build/build-packages.sh
```

#### Build Specific Package Types
```bash
# Build only npm package
./build/npm/build.sh

# Build only Debian package  
./build/linux/build-deb.sh

# Build only Docker image
./build/docker/build.sh
```

Built packages are stored in `./dist/{version}/` organized by package type.

### Step 3: Package Validation

The validation framework uses Docker containers to test package installation and functionality across different Linux distributions.

#### Validate All Packages
```bash
# Quick validation (default platforms and packages)
./build/test/validation/package-validator.sh

# Full validation with build and cleanup
./build/test/validation/package-validator.sh -b -c

# Validation with detailed reporting
./build/test/validation/package-validator.sh -b -c -r validation-report.json
```

#### Validate Specific Combinations
```bash
# Test npm and deb packages on Ubuntu only
./build/test/validation/package-validator.sh -p ubuntu -k npm,deb

# Test all packages on Fedora and Alpine
./build/test/validation/package-validator.sh -p fedora,alpine -k npm,pypi,deb,rpm,docker
```

#### Validation Options
```bash
./build/test/validation/package-validator.sh [OPTIONS]

Options:
  -p, --platforms PLATFORMS    Comma-separated platforms (ubuntu,debian,fedora,alpine)
  -k, --packages PACKAGES      Comma-separated packages (npm,pypi,deb,rpm,docker)  
  -v, --version VERSION        Version to test (default: auto-detect)
  -r, --report FILE           Generate JSON validation report
  -c, --clean                 Clean up containers after testing
  -b, --build                 Build packages before testing
  -h, --help                  Show help message
```

#### Understanding Validation Results
```bash
========================================
VALIDATION SUMMARY  
========================================
Total tests: 8
Failures: 0
Success rate: 100%
Report saved to: validation-report.json

All validations passed!
```

### Step 4: Publishing Packages

#### Publish All Packages
```bash
./build/publish-packages.sh
```

#### Publish to Specific Package Managers
```bash
# Publish to npm only
./build/npm/publish.sh

# Publish to PyPI only  
./build/pypi/publish.sh

# Publish Docker image only
./build/docker/publish.sh
```

#### GitHub Release
```bash
# Create GitHub release with all artifacts
gh release create v0.3.0-beta ./dist/0.3.0-beta/*
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
# Check build logs
./build/build-packages.sh 2>&1 | tee build.log

# Test individual package builds
./build/npm/build.sh
```

### Validation Failures
```bash
# Run validation with verbose output
./build/test/validation/package-validator.sh -b -c 2>&1 | tee validation.log

# Test specific validator manually
./build/test/validation/npm-validator.sh ubuntu 0.3.0-beta
```

### Publish Failures
```bash
# Check authentication
npm whoami
docker info | grep Username

# Test individual publishers
./build/npm/publish.sh
```

### Common Issues

1. **Docker not running**: Start Docker daemon
2. **Authentication failures**: Re-run login commands
3. **Version conflicts**: Check if version already published
4. **Missing dependencies**: Install required build tools
5. **Permission errors**: Ensure Docker user permissions

## CI/CD Integration

For automated publishing in CI/CD pipelines:

```bash
# GitHub Actions example
- name: Build and validate packages
  run: |
    ./build/build-packages.sh
    ./build/test/validation/package-validator.sh -c -r validation-report.json

- name: Publish packages  
  if: github.ref == 'refs/heads/main'
  run: ./build/publish-packages.sh
  env:
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
    PYPI_TOKEN: ${{ secrets.PYPI_TOKEN }}
    DOCKER_HUB_PASSWORD: ${{ secrets.DOCKER_HUB_PASSWORD }}
```

## Directory Structure

```
build/
├── build-packages.sh           # Build all packages
├── publish-packages.sh         # Publish all packages  
├── config.sh                   # Centralized configuration
├── lib/                        # Shared build utilities
├── npm/                        # npm package build/publish
├── pypi/                       # PyPI package build/publish
├── docker/                     # Docker image build/publish
├── linux/                      # Debian/RPM package builds
└── test/
    ├── validation/             # Validation framework
    │   ├── package-validator.sh    # Main validator
    │   ├── npm-validator.sh        # npm-specific tests
    │   ├── pypi-validator.sh       # PyPI-specific tests
    │   ├── deb-validator.sh        # Debian-specific tests
    │   ├── rpm-validator.sh        # RPM-specific tests
    │   ├── docker-validator.sh     # Docker-specific tests
    │   └── common.sh              # Shared test functions
    └── docker/                 # Test environments
        ├── ubuntu/
        ├── debian/  
        ├── fedora/
        ├── alpine/
        └── arch/

dist/{version}/                 # Built packages
├── npm/
├── pypi/  
├── giv_*.deb
├── giv-*.rpm
└── docker-image.tar
```

## Best Practices

1. **Always validate before publishing**: Run the validation framework to catch issues early
2. **Use semantic versioning**: Follow semver for version numbers  
3. **Test on multiple platforms**: Ensure compatibility across distributions
4. **Keep authentication secure**: Use environment variables or secret management
5. **Document changes**: Update changelogs and release notes
6. **Monitor package repositories**: Verify successful publication
7. **Automate in CI/CD**: Reduce manual errors with automation

## Support

For build system issues:
- Review build logs and validation reports
- Check individual package validator outputs  
- Verify authentication and permissions
- Test Docker environment locally
- Consult package manager documentation