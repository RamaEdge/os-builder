#!/bin/bash
# Build script for Fedora bootc container image

set -euo pipefail

# Configuration
IMAGE_NAME="${IMAGE_NAME:-localhost/fedora-edge-os}"
IMAGE_TAG="${IMAGE_TAG:-}"
CONTAINERFILE="${CONTAINERFILE:-Containerfile.fedora}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
MICROSHIFT_VERSION="${MICROSHIFT_VERSION:-main}"
MICROSHIFT_REPO="${MICROSHIFT_REPO:-https://github.com/openshift/microshift.git}"
REGISTRY="${REGISTRY:-ghcr.io}"
REPO_OWNER="${REPO_OWNER:-ramaedge}"

# GitVersion integration
get_version() {
    local version=""
    
    # First try to get version from GitVersion if available
    if command -v dotnet &> /dev/null; then
        # Check if we're in a git repository
        if git rev-parse --git-dir > /dev/null 2>&1; then
            # Check if GitVersion tool is available
            if dotnet tool list -g | grep -q "gitversion.tool"; then
                version=$(dotnet gitversion -showvariable SemVer 2>/dev/null || echo "")
                if [ -n "$version" ]; then
                    echo "GitVersion detected: $version" >&2
                    echo "$version"
                    return
                fi
            fi
        fi
    fi
    
    # Fallback to git describe if in a git repository
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

# Check for MicroShift optimization opportunity
check_microshift_optimization() {
    if [[ "$CONTAINERFILE" == "Containerfile.fedora" ]]; then
        info "Checking for MicroShift optimization opportunity..."
        
        # Get version tag for checking - handle different version types
        local version_tag="$MICROSHIFT_VERSION"
        if [ "$MICROSHIFT_VERSION" = "main" ]; then
            local commit_hash
            commit_hash=$(git ls-remote "$MICROSHIFT_REPO" HEAD | cut -f1 | cut -c1-8 2>/dev/null || echo "")
            if [ -n "$commit_hash" ]; then
                version_tag="main-${commit_hash}"
            fi
        elif [[ "$MICROSHIFT_VERSION" =~ ^release- ]]; then
            # It's a release branch, get latest commit for that branch
            local commit_hash
            commit_hash=$(git ls-remote "$MICROSHIFT_REPO" "refs/heads/$MICROSHIFT_VERSION" | cut -f1 | cut -c1-8 2>/dev/null || echo "")
            if [ -n "$commit_hash" ]; then
                version_tag="${MICROSHIFT_VERSION}-${commit_hash}"
            fi
        elif [[ "$MICROSHIFT_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            # It's already a version tag, use as-is
            version_tag="$MICROSHIFT_VERSION"
        fi
        
        # Check if pre-built MicroShift image exists
        local microshift_image="${REGISTRY}/${REPO_OWNER}/microshift-builder:${version_tag}"
        if $CONTAINER_RUNTIME pull "$microshift_image" >/dev/null 2>&1; then
            warn "🚀 OPTIMIZATION AVAILABLE: Pre-built MicroShift found!"
            warn "   For 85% faster builds, use: make build-optimized"
            warn "   Or manually: CONTAINERFILE=Containerfile.fedora.optimized make build"
            warn "   Using optimized build can reduce build time from ~20 minutes to ~3 minutes"
        fi
    fi
}

# Build the container image
build_image() {
    info "Building Fedora bootc container image..."
    info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    info "Containerfile: ${CONTAINERFILE}"
    info "Container runtime: ${CONTAINER_RUNTIME}"
    
    # Check for optimization if using standard build
    check_microshift_optimization
    
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
    
    # Common build arguments and labels
    local COMMON_BUILD_ARGS=(
        --tag "${IMAGE_NAME}:${IMAGE_TAG}"
        --file "${CONTAINERFILE}"
        --force-rm
        --build-arg "MICROSHIFT_VERSION=${MICROSHIFT_VERSION}"
        --build-arg "MICROSHIFT_REPO=${MICROSHIFT_REPO}"
    )
    
    local COMMON_LABELS=(
        --label "org.opencontainers.image.version=${IMAGE_TAG}"
        --label "org.opencontainers.image.created=${build_date}"
        --label "org.opencontainers.image.revision=${git_commit}"
        --label "org.opencontainers.image.source=${git_repo_url}"
        --label "org.opencontainers.image.branch=${git_branch}"
        --label "microshift.version=${MICROSHIFT_VERSION}"
        --label "microshift.source=${MICROSHIFT_REPO}"
    )
    
    # Build arguments based on container runtime
    if [[ "$CONTAINER_RUNTIME" == "docker" ]]; then
        BUILD_ARGS=(
            "${COMMON_BUILD_ARGS[@]}"
            "${COMMON_LABELS[@]}"
            .
        )
    else
        BUILD_ARGS=(
            "${COMMON_BUILD_ARGS[@]}"
            --layers
            "${COMMON_LABELS[@]}"
            .
        )
    fi
    
    # Build the image
    info "Running: $CONTAINER_RUNTIME build [build args]"
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
    echo "Build Fedora bootc container image for edge deployment"
    echo ""
    echo "Environment variables:"
    echo "  IMAGE_NAME        - Container image name (default: localhost/fedora-edge-os)"
    echo "  IMAGE_TAG         - Container image tag (default: auto-detected via GitVersion/git)"
    echo "  CONTAINERFILE     - Containerfile to use (default: Containerfile.fedora)"
    echo "  CONTAINER_RUNTIME - Container runtime to use (auto-detected: docker on macOS, podman on Linux)"
    echo "  MICROSHIFT_VERSION - MicroShift version/branch to build (default: main)"
    echo "  MICROSHIFT_REPO   - MicroShift repository URL (default: https://github.com/openshift/microshift.git)"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  IMAGE_NAME=my-registry/edge-os IMAGE_TAG=v1.0.0 $0"
    echo "  MICROSHIFT_VERSION=release-4.17 $0"
    echo "  MICROSHIFT_VERSION=v4.17.1 MICROSHIFT_REPO=https://github.com/openshift/microshift.git $0"
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