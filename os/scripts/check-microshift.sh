#!/bin/bash
# MicroShift Build Strategy Helper
# Checks for pre-built MicroShift binaries and suggests optimal build strategy

set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/microshift-utils.sh"

# Default values
MICROSHIFT_VERSION="${MICROSHIFT_VERSION:-main}"
MICROSHIFT_REPO="${MICROSHIFT_REPO:-https://github.com/openshift/microshift.git}"
REGISTRY="${REGISTRY:-ghcr.io}"
REPO_OWNER="${REPO_OWNER:-ramaedge}"

echo -e "${BLUE}🔍 MicroShift Build Strategy Checker${NC}"
echo "=================================="

# Determine version tag using shared utility
echo "📡 Determining MicroShift version tag..."
VERSION_TAG=$(get_microshift_version_tag "$MICROSHIFT_VERSION" "$MICROSHIFT_REPO")
echo "🏷️  Target version: $VERSION_TAG"

# Check for pre-built image
MICROSHIFT_IMAGE="${REGISTRY}/${REPO_OWNER}/microshift-builder:${VERSION_TAG}"
echo "🔍 Checking for pre-built image: $MICROSHIFT_IMAGE"

if check_prebuilt_image "$VERSION_TAG" "$REGISTRY" "$REPO_OWNER"; then
    echo -e "${GREEN}✅ Pre-built MicroShift binary available!${NC}"
    echo ""
    echo -e "${GREEN}🚀 RECOMMENDED: Use optimized build${NC}"
    echo "   make build CONTAINERFILE=Containerfile.fedora.optimized"
    echo ""
    echo "📊 Expected build time: ~5-8 minutes (85% faster)"
    echo "💡 This will use the pre-built MicroShift binary"
    echo ""
    echo "🔧 Available build commands:"
    echo "   # Optimized build (recommended)"
    echo "   make build CONTAINERFILE=Containerfile.fedora.optimized"
    echo ""
    echo "   # Standard build (if needed)"
    echo "   make build CONTAINERFILE=Containerfile.fedora"
else
    echo -e "${YELLOW}⚠️  Pre-built MicroShift binary not available${NC}"
    echo ""
    echo -e "${YELLOW}🔨 FALLBACK: Source build required${NC}"
    echo "   make build CONTAINERFILE=Containerfile.fedora"
    echo ""
    echo "📊 Expected build time: ~15-25 minutes"
    echo "💡 This will build MicroShift from source"
    echo ""
    echo -e "${BLUE}🚀 OPTIMIZATION OPPORTUNITY:${NC}"
    echo "   Build MicroShift separately for future reuse:"
    echo "   1. Run the MicroShift Builder workflow in GitHub Actions"
    echo "   2. Or build locally and push to registry:"
    echo "      cd .github/workflows"
    echo "      # Extract the MicroShift build steps and run them"
    echo ""
    echo "🔧 Current build command:"
    echo "   make build  # Uses Containerfile.fedora by default"
fi

echo ""
echo -e "${BLUE}📋 Build Information:${NC}"
echo "   MicroShift Version: $VERSION_TAG"
echo "   MicroShift Repo: $MICROSHIFT_REPO"
echo "   Registry: $REGISTRY"
echo "   Container Tool: $(command -v docker >/dev/null 2>&1 && echo "docker" || echo "podman")"
echo ""
echo -e "${BLUE}🔗 Related Workflows:${NC}"
echo "   • MicroShift Builder: .github/workflows/microshift-builder.yaml"
echo "   • Main Build: .github/workflows/build-and-security-scan.yaml" 