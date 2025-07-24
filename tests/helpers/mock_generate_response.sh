# This file is sourced by giv.sh in test mode to mock generate_response
mock_generate_response() {
    case "${1:-}" in
        *message*|*commit*)
            echo "feat: enhance project with new dependencies and documentation"
            ;;
        *changelog*)
            echo "## [1.2.1] - $(date +%Y-%m-%d)
### Added
- Express.js dependency for better server functionality
- Basic hello world implementation

### Fixed
- Project initialization and basic functionality"
            ;;
        *summary*)
            echo "## Summary of Changes

The recent commits include:
- Addition of Express.js dependency for server functionality  
- Updated project documentation with new features
- Implemented basic hello world functionality
- Fixed initial project setup issues"
            ;;
        *release*)
            echo "# Release Notes v1.2.1

This release introduces server capabilities and improves the project foundation.

## What's New
- **Server Framework**: Added Express.js for robust server functionality
- **Documentation**: Enhanced README with feature descriptions
- **Core Functionality**: Implemented hello world baseline

## Technical Details
- Dependencies updated to include Express ^4.18.0
- Basic server entry point established
- Project structure improved for scalability"
            ;;
        *)
            echo "Generated content for integration testing"
            ;;
    esac
}

generate_response() { mock_generate_response "$@"; }
