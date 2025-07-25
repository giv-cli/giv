#!/bin/bash
set -euo pipefail

# Container run helper script
# Runs commands inside the giv-packages container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="giv-packages"
IMAGE_TAG="latest"
CONTAINER_NAME="giv-build-$$"

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Run commands inside the giv-packages container with the project mounted.

OPTIONS:
    -i, --interactive   Run in interactive mode (with TTY)
    -t, --tag TAG       Container tag to use (default: latest)
    -n, --name NAME     Container image name (default: giv-packages)
    -c, --container-name NAME  Container instance name (default: giv-build-PID)
    -w, --workdir DIR   Working directory inside container (default: /workspace)
    --rm                Remove container after execution (default: true)
    --no-rm             Don't remove container after execution
    -v, --volume SRC:DEST  Additional volume mount
    -e, --env VAR=VALUE Set environment variable
    -h, --help          Show this help message

ARGUMENTS:
    COMMAND             Command to run (default: /bin/bash)

EXAMPLES:
    $0                              # Interactive bash shell
    $0 ./build/build-packages.sh    # Run build script
    $0 -i                          # Interactive shell with TTY
    $0 ./build/validate-installs.sh # Run validation
    $0 -e "DEBUG=1" ./script.sh    # Set environment variable

NOTES:
    - Project directory is mounted at /workspace
    - Current user ID/GID are preserved for file permissions
    - Container is removed after execution by default

EOF
}

# Default values
INTERACTIVE=false
WORKDIR="/workspace"
REMOVE_CONTAINER=true
VOLUMES=()
ENV_VARS=()
COMMAND=("/bin/bash")

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -c|--container-name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -w|--workdir)
            WORKDIR="$2"
            shift 2
            ;;
        --rm)
            REMOVE_CONTAINER=true
            shift
            ;;
        --no-rm)
            REMOVE_CONTAINER=false
            shift
            ;;
        -v|--volume)
            VOLUMES+=("$2")
            shift 2
            ;;
        -e|--env)
            ENV_VARS+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            COMMAND=("$@")
            break
            ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            # First non-option argument starts the command
            COMMAND=("$@")
            break
            ;;
    esac
done

FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"

# Check if image exists
if ! docker image inspect "$FULL_IMAGE_NAME" >/dev/null 2>&1; then
    echo "ERROR: Container image not found: $FULL_IMAGE_NAME" >&2
    echo "Run './build/container-build.sh' to build the image first." >&2
    exit 1
fi

# Build docker run arguments
RUN_ARGS=()

# Basic container settings
if [[ "$REMOVE_CONTAINER" == "true" ]]; then
    RUN_ARGS+=("--rm")
fi

RUN_ARGS+=("--name" "$CONTAINER_NAME")
RUN_ARGS+=("--workdir" "$WORKDIR")

# Interactive mode
if [[ "$INTERACTIVE" == "true" ]]; then
    RUN_ARGS+=("-it")
fi

# Mount project directory
RUN_ARGS+=("-v" "$PROJECT_ROOT:$WORKDIR")

# Preserve user permissions (Linux/macOS)
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" ]]; then
    RUN_ARGS+=("-u" "$(id -u):$(id -g)")
fi

# Additional volume mounts
for volume in "${VOLUMES[@]}"; do
    RUN_ARGS+=("-v" "$volume")
done

# Environment variables
for env_var in "${ENV_VARS[@]}"; do
    RUN_ARGS+=("-e" "$env_var")
done

# Pass through some common environment variables if they exist
ENV_PASSTHROUGH=("HOME" "USER" "GIV_DEBUG" "CI" "GITHUB_TOKEN" "NPM_TOKEN" "PYPI_TOKEN" "DOCKER_HUB_PASSWORD")
for env_var in "${ENV_PASSTHROUGH[@]}"; do
    if [[ -n "${!env_var:-}" ]]; then
        RUN_ARGS+=("-e" "$env_var=${!env_var}")
    fi
done

# Image name
RUN_ARGS+=("$FULL_IMAGE_NAME")

# Command to run
RUN_ARGS+=("${COMMAND[@]}")

echo "Running container: $CONTAINER_NAME"
echo "Image: $FULL_IMAGE_NAME"
echo "Working directory: $WORKDIR"
echo "Command: ${COMMAND[*]}"
echo

# Run the container
exec docker run "${RUN_ARGS[@]}"