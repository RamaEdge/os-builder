#!/bin/bash
# Build script for Fedora bootc container image

set -euo pipefail

# Configuration
IMAGE_NAME="${IMAGE_NAME:-localhost/fedora-edge-os}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINERFILE="${CONTAINERFILE:-Containerfile.microshift}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

# Version configuration (passed from Makefile via environment variables)
OTEL_VERSION="${OTEL_VERSION}"
FEDORA_VERSION="${FEDORA_VERSION}"
MICROSHIFT_VERSION="${MICROSHIFT_VERSION}"

info() { echo "[INFO] $*"; }
error() { echo "[ERROR] $*" >&2; }

# Get git metadata for labels
get_git_metadata() {
    local git_commit git_repo_url

    git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    if git rev-parse --git-dir >/dev/null 2>&1; then
        git_repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "unknown")
        git_repo_url=${git_repo_url/#git@github.com:/https://github.com/}
        git_repo_url=${git_repo_url/.git/}
    else
        git_repo_url="unknown"
    fi

    echo "$git_commit|$git_repo_url"
}

build_image() {
    info "Building: ${IMAGE_NAME}:${IMAGE_TAG}"
    info "Using: ${CONTAINER_RUNTIME}"
    info "Versions: OTEL=${OTEL_VERSION}, Fedora=${FEDORA_VERSION}, MicroShift=${MICROSHIFT_VERSION}"

    cd "$(dirname "$0")"

    # Generate image list from versions.json
    local versions_file="../versions.json"
    if [[ -f "$versions_file" ]]; then
        info "Generating image list from versions.json"
        jq -r '.images | to_entries[] | .value | to_entries[] | .value' "$versions_file" \
            > configs/edgeworks-images.txt
    fi

    IFS='|' read -r git_commit git_repo_url <<< "$(get_git_metadata)"

    local cmd=(
        "$CONTAINER_RUNTIME" build
        --tag "${IMAGE_NAME}:${IMAGE_TAG}"
        --file "${CONTAINERFILE}"
        --force-rm
        --build-arg "VCS_REF=${git_commit}"
        --build-arg "VERSION=${IMAGE_TAG}"
        --build-arg "OTEL_VERSION=${OTEL_VERSION}"
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}"
        --build-arg "MICROSHIFT_VERSION=${MICROSHIFT_VERSION}"
        --label "org.opencontainers.image.version=${IMAGE_TAG}"
        --label "org.opencontainers.image.revision=${git_commit}"
        --label "org.opencontainers.image.source=${git_repo_url}"
    )

    [[ "$CONTAINER_RUNTIME" == "podman" ]] && cmd+=(--layers)

    # Pass registry auth as build secret for private registry pulls
    # Copy auth into .build/ so podman temp files stay contained
    local build_dir
    build_dir="$(git rev-parse --show-toplevel 2>/dev/null || echo "..")/.build"
    mkdir -p "${build_dir}"

    local auth_file=""
    for f in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/containers/auth.json" \
             "${HOME}/.config/containers/auth.json" \
             "${HOME}/.docker/config.json"; do
        if [[ -f "$f" ]]; then
            auth_file="$f"
            break
        fi
    done

    if [[ -n "$auth_file" ]]; then
        cp "$auth_file" "${build_dir}/registry-auth.json"
        info "Using registry auth from ${auth_file}"
        cmd+=(--secret "id=registry-auth,src=${build_dir}/registry-auth.json")
    else
        info "No registry auth file found, private registry pulls may fail"
    fi

    cmd+=(.)

    if "${cmd[@]}"; then
        info "Build successful: ${IMAGE_NAME}:${IMAGE_TAG}"
        info "Image size: $($CONTAINER_RUNTIME images "${IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Size}}' 2>/dev/null || echo 'unknown')"
    else
        error "Build failed!"
        exit 1
    fi
}

main() {
    if ! command -v "$CONTAINER_RUNTIME" >/dev/null 2>&1; then
        error "Container runtime '${CONTAINER_RUNTIME}' not found!"
        exit 1
    fi

    if [[ ! -f "$CONTAINERFILE" ]]; then
        error "Containerfile not found: $CONTAINERFILE"
        exit 1
    fi

    build_image
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Environment variables:"
    echo "  IMAGE_NAME         - Image name (default: localhost/fedora-edge-os)"
    echo "  IMAGE_TAG          - Image tag (default: latest)"
    echo "  CONTAINERFILE      - Containerfile path (default: Containerfile.microshift)"
    echo "  CONTAINER_RUNTIME  - Runtime (default: podman)"
    echo ""
    echo "Version variables (from versions.txt):"
    echo "  OTEL_VERSION       - OpenTelemetry version"
    echo "  FEDORA_VERSION     - Fedora version"
    exit 0
fi

main "$@"
