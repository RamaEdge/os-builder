#!/bin/bash
# Build script for Fedora bootc container image

set -euo pipefail

# Configuration
IMAGE_NAME="${IMAGE_NAME:-localhost/fedora-edge-os}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINERFILE="${CONTAINERFILE:-Containerfile.k3s}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"
MICROSHIFT_VERSION="${MICROSHIFT_VERSION:-release-4.19}"
MICROSHIFT_IMAGE_BASE="${MICROSHIFT_IMAGE_BASE:-ghcr.io/ramaedge/microshift-builder}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Get git metadata for labels
get_git_metadata() {
    local git_commit git_repo_url
    
    git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    # Get repository URL (simplified)
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git_repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "unknown")
        # Convert SSH to HTTPS if needed
        git_repo_url=${git_repo_url/#git@github.com:/https://github.com/}
        git_repo_url=${git_repo_url/.git/}
    else
        git_repo_url="unknown"
    fi
    
    echo "$git_commit|$git_repo_url"
}

# Build the container image
build_image() {
    info "Building: ${IMAGE_NAME}:${IMAGE_TAG}"
    info "Using: ${CONTAINER_RUNTIME}"
    
    cd "$(dirname "$0")"
    
    # Get metadata
    IFS='|' read -r git_commit git_repo_url <<< "$(get_git_metadata)"
    
    # Base build command
    BUILD_CMD="$CONTAINER_RUNTIME build"
    BUILD_CMD="$BUILD_CMD --tag ${IMAGE_NAME}:${IMAGE_TAG}"
    BUILD_CMD="$BUILD_CMD --file ${CONTAINERFILE}"
    BUILD_CMD="$BUILD_CMD --force-rm"
    
    # Add layers for podman
    [[ "$CONTAINER_RUNTIME" == "podman" ]] && BUILD_CMD="$BUILD_CMD --layers"
    
    # Build arguments (removed BUILD_DATE for better caching)
    BUILD_CMD="$BUILD_CMD --build-arg VCS_REF=${git_commit}"
    BUILD_CMD="$BUILD_CMD --build-arg VERSION=${IMAGE_TAG}"
    
    # Labels (removed created label to prevent cache invalidation)
    BUILD_CMD="$BUILD_CMD --label org.opencontainers.image.version=${IMAGE_TAG}"
    BUILD_CMD="$BUILD_CMD --label org.opencontainers.image.revision=${git_commit}"
    BUILD_CMD="$BUILD_CMD --label org.opencontainers.image.source=${git_repo_url}"
    
    # MicroShift-specific args
    if [[ "$CONTAINERFILE" == *"microshift"* ]] || [[ "$CONTAINERFILE" == *"fedora.optimized"* ]]; then
        BUILD_CMD="$BUILD_CMD --build-arg MICROSHIFT_VERSION=${MICROSHIFT_VERSION}"
        BUILD_CMD="$BUILD_CMD --build-arg MICROSHIFT_IMAGE_BASE=${MICROSHIFT_IMAGE_BASE}"
        BUILD_CMD="$BUILD_CMD --label microshift.version=${MICROSHIFT_VERSION}"
        info "MicroShift build: ${MICROSHIFT_VERSION}"
    else
        BUILD_CMD="$BUILD_CMD --label k3s.distribution=k3s"
        info "K3s build"
    fi
    
    BUILD_CMD="$BUILD_CMD ."
    
    # Execute build
    if eval "$BUILD_CMD"; then
        info "✅ Build successful: ${IMAGE_NAME}:${IMAGE_TAG}"
        
        # Show image info
        if command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
            info "Image size: $($CONTAINER_RUNTIME images ${IMAGE_NAME}:${IMAGE_TAG} --format '{{.Size}}' 2>/dev/null || echo 'unknown')"
        fi
    else
        error "❌ Build failed!"
        exit 1
    fi
}

# Main execution
main() {
    # Basic validation
    if ! command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
        error "Container runtime '${CONTAINER_RUNTIME}' not found!"
        exit 1
    fi
    
    if [[ ! -f "$CONTAINERFILE" ]]; then
        error "Containerfile not found: $CONTAINERFILE"
        exit 1
    fi
    
    build_image
    
    info "🎉 Build completed!"
    info "Next: $CONTAINER_RUNTIME run --rm -it ${IMAGE_NAME}:${IMAGE_TAG}"
}

# Handle help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Environment variables:"
    echo "  IMAGE_NAME        - Image name (default: localhost/fedora-edge-os)"
    echo "  IMAGE_TAG         - Image tag (default: latest)"
    echo "  CONTAINERFILE     - Containerfile path (default: Containerfile.k3s)"
    echo "  CONTAINER_RUNTIME - Runtime (default: podman)"
    echo "  MICROSHIFT_VERSION - MicroShift version (default: release-4.19)"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  IMAGE_TAG=v1.0.0 $0"
    exit 0
fi

main "$@" 