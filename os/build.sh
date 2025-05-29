#!/bin/bash
# Build script for Fedora bootc container image

set -euo pipefail

# Configuration
IMAGE_NAME="${IMAGE_NAME:-localhost/fedora-edge-os}"
IMAGE_TAG="${IMAGE_TAG:-}"
CONTAINERFILE="${CONTAINERFILE:-Containerfile.k3s}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
REGISTRY="${REGISTRY:-ghcr.io}"
REPO_OWNER="${REPO_OWNER:-ramaedge}"
MICROSHIFT_VERSION="${MICROSHIFT_VERSION:-release-4.19}"

# GitVersion integration
get_version() {
    local version=""
    
    # Use git describe if in a git repository
    if git rev-parse --git-dir > /dev/null 2>&1; then
        version=$(git describe --tags --always --dirty 2>/dev/null || echo "")
        if [ -n "$version" ]; then
            echo "Git version detected: $version" >&2
            echo "$version"
            return
        fi
    fi
    
    # Final fallback to latest
    echo "latest"
}

# Set IMAGE_TAG if not provided
if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG=$(get_version)
fi

# Detect OS and set container runtime
detect_runtime() {
    if [ -z "$CONTAINER_RUNTIME" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - prefer Docker
            if command -v docker &> /dev/null; then
                CONTAINER_RUNTIME="docker"
            elif command -v podman &> /dev/null; then
                CONTAINER_RUNTIME="podman"
            fi
        else
            # Linux - prefer Podman
            if command -v podman &> /dev/null; then
                CONTAINER_RUNTIME="podman"
            elif command -v docker &> /dev/null; then
                CONTAINER_RUNTIME="docker"
            fi
        fi
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."
    
    detect_runtime
    
    if [ -z "$CONTAINER_RUNTIME" ]; then
        error "No container runtime found. Please install docker or podman."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            error "On macOS, install Docker Desktop: brew install --cask docker"
            error "Or install Podman: brew install podman"
        else
            error "On Linux, install podman: sudo dnf install podman (Fedora/RHEL) or sudo apt install podman (Ubuntu/Debian)"
        fi
        exit 1
    fi
    
    info "Using container runtime: $CONTAINER_RUNTIME"
    
    if [[ "$CONTAINER_RUNTIME" == "podman" ]] && ! command -v buildah &> /dev/null; then
        warn "buildah is not installed. Consider installing buildah for better build performance."
    fi
    
    info "Dependencies check completed."
}

# Build the container image
build_image() {
    info "Building Fedora bootc container image with K3s..."
    info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    info "Containerfile: ${CONTAINERFILE}"
    info "Container runtime: ${CONTAINER_RUNTIME}"
    
    # Change to the script directory
    cd "$(dirname "$0")"
    
    # Get additional version information for labels
    local build_date
    build_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local git_commit
    git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local git_branch
    git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local git_repo_url=""
    
    # Try to get the remote repository URL
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git_repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "unknown")
        # Convert SSH URL to HTTPS if needed
        if [[ "$git_repo_url" =~ git@github\.com:(.+)\.git ]]; then
            git_repo_url="https://github.com/${BASH_REMATCH[1]}"
        elif [[ "$git_repo_url" =~ git@github\.com:(.+) ]]; then
            git_repo_url="https://github.com/${BASH_REMATCH[1]}"
        fi
    else
        git_repo_url="unknown"
    fi
    
    # Common build arguments and labels (enhanced with build metadata)
    local COMMON_BUILD_ARGS=(
        --tag "${IMAGE_NAME}:${IMAGE_TAG}"
        --file "${CONTAINERFILE}"
        --force-rm
        --build-arg "BUILD_DATE=${build_date}"
        --build-arg "VCS_REF=${git_commit}"
        --build-arg "VERSION=${IMAGE_TAG}"
    )
    
    local COMMON_LABELS=(
        --label "org.opencontainers.image.version=${IMAGE_TAG}"
        --label "org.opencontainers.image.created=${build_date}"
        --label "org.opencontainers.image.revision=${git_commit}"
        --label "org.opencontainers.image.source=${git_repo_url}"
        --label "org.opencontainers.image.branch=${git_branch}"
    )
    
    # Add build args for MicroShift builds
    local BUILD_ARGS_EXTRA=()
    if [[ "$CONTAINERFILE" == *"microshift"* ]] || [[ "$CONTAINERFILE" == *"fedora.optimized"* ]]; then
        BUILD_ARGS_EXTRA+=(--build-arg "MICROSHIFT_VERSION=${MICROSHIFT_VERSION}")
        COMMON_LABELS+=(--label "microshift.version=${MICROSHIFT_VERSION}")
        info "Building with MicroShift version: ${MICROSHIFT_VERSION}"
    else
        COMMON_LABELS+=(--label "k3s.distribution=k3s")
        info "Building with K3s distribution"
    fi
    
    # Build arguments based on container runtime
    if [[ "$CONTAINER_RUNTIME" == "docker" ]]; then
        BUILD_ARGS=(
            "${COMMON_BUILD_ARGS[@]}"
            "${COMMON_LABELS[@]}"
            "${BUILD_ARGS_EXTRA[@]+"${BUILD_ARGS_EXTRA[@]}"}"
            .
        )
    else
        BUILD_ARGS=(
            "${COMMON_BUILD_ARGS[@]}"
            --layers
            "${COMMON_LABELS[@]}"
            "${BUILD_ARGS_EXTRA[@]+"${BUILD_ARGS_EXTRA[@]}"}"
            .
        )
    fi
    
    # Build the image
    info "Running: $CONTAINER_RUNTIME build [build args]"
    info "🔧 Build arguments:"
    info "  BUILD_DATE=${build_date}"
    info "  VCS_REF=${git_commit}"
    info "  VERSION=${IMAGE_TAG}"
    if [[ "$CONTAINERFILE" == *"microshift"* ]] || [[ "$CONTAINERFILE" == *"fedora.optimized"* ]]; then
        info "  MICROSHIFT_VERSION=${MICROSHIFT_VERSION}"
    fi
    
    if "$CONTAINER_RUNTIME" build "${BUILD_ARGS[@]}"; then
        info "✅ Build completed successfully!"
        info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    else
        error "❌ Build failed!"
        exit 1
    fi
}

# Show image information
show_image_info() {
    info "Image information:"
    if [[ "$CONTAINER_RUNTIME" == "docker" ]]; then
        "$CONTAINER_RUNTIME" images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
    else
        "$CONTAINER_RUNTIME" images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Created}}\t{{.Size}}"
    fi
}

# Main function
main() {
    info "Starting Fedora bootc container image build..."
    
    check_dependencies
    build_image
    show_image_info
    
    info "🎉 Build process completed!"
    info ""
    info "Next steps:"
    info "1. Test the image: ${CONTAINER_RUNTIME} run --rm -it ${IMAGE_NAME}:${IMAGE_TAG}"
    info "2. Convert to disk image: Use bootc-image-builder or similar tools"
    info "3. Deploy to edge devices"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build Fedora bootc container image for edge deployment with K3s"
    echo ""
    echo "Environment variables:"
    echo "  IMAGE_NAME        - Container image name (default: localhost/fedora-edge-os)"
    echo "  IMAGE_TAG         - Container image tag (default: auto-detected via git)"
    echo "  CONTAINERFILE     - Containerfile to use (default: Containerfile.k3s)"
    echo "  CONTAINER_RUNTIME - Container runtime to use (auto-detected: docker on macOS, podman on Linux)"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  IMAGE_NAME=my-registry/edge-os IMAGE_TAG=v1.0.0 $0"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Run main function
main 