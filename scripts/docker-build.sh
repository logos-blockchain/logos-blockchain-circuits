#!/usr/bin/env bash
#
# Docker Build Script for Logos Blockchain Circuits
# This script builds and runs the circuit compilation in a Docker container
# to avoid polluting your host system.
#
# Usage:
#   ./docker-build.sh [OPTIONS]
#
# Options:
#   All options are passed directly to build-local.sh inside the container.
#   See ./build-local.sh --help for available options.
#
# Examples:
#   ./docker-build.sh                    # Full build
#   ./docker-build.sh --help             # Show build-local.sh help
#   ./docker-build.sh --circuit pol      # Build only PoL circuit
#   ./docker-build.sh --clean            # Clean  and rebuild
#   ./docker-build.sh --skip-ptau        # Skip Powers of Tau download (if already exists)
#
# Advanced Options:
#   DOCKER_BUILD=0 ./docker-build.sh     # Skip rebuilding the Docker image
#   DOCKER_NOCACHE=1 ./docker-build.sh   # Force rebuild Docker image without cache
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
IMAGE_NAME="logos-circuits-builder"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/..
DOCKER_BUILD="${DOCKER_BUILD:-1}"
DOCKER_NOCACHE="${DOCKER_NOCACHE:-0}"
SKIP_INSTALL=${SKIP_INSTALL:-false}

cd "$SCRIPT_DIR"


# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running. Please start Docker first."
    exit 1
fi

# Build the Docker image if needed
if [[ "$DOCKER_BUILD" == "1" ]]; then
    log_info "Building Docker image: $IMAGE_NAME"
    
    BUILD_ARGS=""
    if [[ "$DOCKER_NOCACHE" == "1" ]]; then
        BUILD_ARGS="--no-cache"
    fi

    ls 
    docker build $BUILD_ARGS -t "$IMAGE_NAME" -f ./scripts/Dockerfile .
    log_success "Docker image built successfully"
else
    log_info "Skipping Docker image build (DOCKER_BUILD=0)"
fi

# Run the build in Docker
log_info "Running build in Docker container..."
log_info "Arguments: $*"

# Use interactive mode if terminal is available, for better output
DOCKER_FLAGS="-it"
if [[ ! -t 0 ]]; then
    DOCKER_FLAGS=""
fi

# Run the container with the workspace mounted
# --rm: Remove container after exit
# -v: Mount current directory to /workspace
# -v for ptau: Persist the Powers of Tau file to avoid re-downloading
docker run --rm $DOCKER_FLAGS \
    -v "$SCRIPT_DIR:/workspace" \
    -v "$SCRIPT_DIR/.docker-cache:/root/.cache" \
    -e "TERM=${TERM:-xterm}" \
    "$IMAGE_NAME" "$@"

log_success "Docker build completed!"

if [[ $SKIP_INSTALL == false ]]; then
    log_info "Remember to install the built artifacts if needed."
    exit 0
fi

DEFAULT_INSTALL_DIR="$HOME/.nomos-circuits"

log_info "Installing built artifacts to $DEFAULT_INSTALL_DIR"
mkdir -p "$DEFAULT_INSTALL_DIR"

# Default configuration
VERSION="v0.0.0-local"
OS="linux"
# Auto-detect architecture
MACHINE_ARCH="$(uname -m)"
case "$MACHINE_ARCH" in
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        ARCH="$MACHINE_ARCH"
        ;;
esac
cp -r ./nomos-circuits-$VERSION-$OS-$ARCH/* "$DEFAULT_INSTALL_DIR/"