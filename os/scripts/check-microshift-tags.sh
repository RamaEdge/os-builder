#!/bin/bash
# MicroShift Tag Checker
# Checks for available tags on specific MicroShift branches

set -euo pipefail

# Default values
MICROSHIFT_REPO="${MICROSHIFT_REPO:-https://github.com/openshift/microshift.git}"
BRANCH="${1:-}"
# If no branch specified but MICROSHIFT_VERSION is set to a release branch, use it
AUTO_DETECTED_BRANCH=""
if [ -z "$BRANCH" ] && [ -n "${MICROSHIFT_VERSION:-}" ] && [[ "${MICROSHIFT_VERSION}" =~ ^release- ]]; then
    BRANCH="$MICROSHIFT_VERSION"
    AUTO_DETECTED_BRANCH="true"
    echo "🎯 Using MICROSHIFT_VERSION as branch: $BRANCH"
    echo ""
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_usage() {
    echo -e "${BLUE}📋 MicroShift Tag Checker${NC}"
    echo "=========================="
    echo ""
    echo "Usage: $0 [BRANCH]"
    echo ""
    echo "Examples:"
    echo "  $0                    # Show all available versions"
    echo "  $0 release-4.17       # Show tags for release-4.17 branch"
    echo "  $0 release-4.16       # Show tags for release-4.16 branch"
    echo ""
    echo "Environment variables:"
    echo "  MICROSHIFT_REPO       # MicroShift repository URL"
    echo ""
}

echo -e "${BLUE}🔍 MicroShift Tag Discovery${NC}"
echo "================================"
echo ""

if [ "$BRANCH" = "--help" ] || [ "$BRANCH" = "-h" ]; then
    show_usage
    exit 0
fi

echo "📡 Repository: $MICROSHIFT_REPO"
echo ""

# If we have a specific branch (either provided or auto-detected), focus on it
if [ -n "$BRANCH" ]; then
    if [ -n "$AUTO_DETECTED_BRANCH" ]; then
        echo -e "${BLUE}🔍 Focusing on current MICROSHIFT_VERSION branch${NC}"
    else
        echo -e "${BLUE}🔍 Focusing on specified branch${NC}"
    fi
    echo ""
else
    # Show general information only if no specific branch
    # Get main branch info
    echo -e "${GREEN}🚀 Main Branch:${NC}"
    MAIN_COMMIT=$(git ls-remote "$MICROSHIFT_REPO" HEAD | cut -f1 | cut -c1-8)
    echo "  main (latest commit: $MAIN_COMMIT)"
    echo ""

    # Get all tags (latest 10, sorted by version)
    echo -e "${GREEN}📋 Latest Tags (All Branches):${NC}"
    git ls-remote --tags "$MICROSHIFT_REPO" | grep -v '\^{}' | sed 's/.*refs\/tags\///' | sort -V -r | head -10 | sed 's/^/  /'
    echo ""

    # Get release branches
    echo -e "${GREEN}🌿 Available Release Branches:${NC}"
    git ls-remote --heads "$MICROSHIFT_REPO" | grep 'refs/heads/release-' | sed 's/.*refs\/heads\///' | head -10 | sed 's/^/  /'
    echo ""
fi

# If specific branch requested
if [ -n "$BRANCH" ]; then
    echo -e "${GREEN}🔍 Tags for Branch: ${YELLOW}$BRANCH${NC}"
    echo "================================"
    
    # Extract version number from branch name
    BRANCH_VERSION=$(echo "$BRANCH" | sed 's/release-//')
    
    # Find tags related to this branch (sorted by version, latest first)
    BRANCH_TAGS=$(git ls-remote --tags "$MICROSHIFT_REPO" | grep -v '\^{}' | grep "refs/tags/.*$BRANCH_VERSION" | sed 's/.*refs\/tags\///' | sort -V -r)
    
    if [ -n "$BRANCH_TAGS" ]; then
        # Get the latest tag
        LATEST_TAG=$(echo "$BRANCH_TAGS" | head -1)
        echo ""
        echo -e "${GREEN}🎯 LATEST RECOMMENDED TAG: ${CYAN}$LATEST_TAG${NC}"
        echo ""
        echo "Available tags for $BRANCH (latest first):"
        echo "$BRANCH_TAGS" | head -10 | sed 's/^/  /'
        
        # Check if pre-built image exists
        echo ""
        echo -e "${BLUE}📦 Checking for pre-built binary...${NC}"
        IMAGE_REF="ghcr.io/ramaedge/microshift-builder:$LATEST_TAG"
        if command -v docker >/dev/null 2>&1; then
            if docker pull "$IMAGE_REF" >/dev/null 2>&1; then
                echo -e "  ${GREEN}✅ Pre-built binary available: $IMAGE_REF${NC}"
            else
                echo -e "  ${YELLOW}⚠️  Pre-built binary not available: $IMAGE_REF${NC}"
            fi
        elif command -v podman >/dev/null 2>&1; then
            if podman pull "$IMAGE_REF" >/dev/null 2>&1; then
                echo -e "  ${GREEN}✅ Pre-built binary available: $IMAGE_REF${NC}"
            else
                echo -e "  ${YELLOW}⚠️  Pre-built binary not available: $IMAGE_REF${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠️  No container runtime found to check for pre-built binary${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No tags found for branch: $BRANCH${NC}"
        echo ""
        echo "Available release branches:"
        git ls-remote --heads "$MICROSHIFT_REPO" | grep 'refs/heads/release-' | sed 's/.*refs\/heads\///' | head -10 | sed 's/^/  /'
    fi
    
            echo ""
        echo -e "${BLUE}🔧 Recommended Build Commands:${NC}"
        if [ -n "$BRANCH_TAGS" ]; then
            echo "# 🚀 RECOMMENDED: Build with latest tag (fastest if pre-built binary available)"
            echo "MICROSHIFT_VERSION=$LATEST_TAG make build-optimized"
            echo ""
            echo "# Alternative: Build from $BRANCH branch directly (latest commit)"
            echo "MICROSHIFT_VERSION=$BRANCH make build"
        echo ""
        echo "# Build MicroShift binary for this version"
        echo "gh workflow run microshift-builder.yaml -f microshift_version=$LATEST_TAG"
    else
        echo "# Build from $BRANCH branch"
        echo "MICROSHIFT_VERSION=$BRANCH make build"
        echo ""
        echo "# Build MicroShift binary for this branch"
        echo "gh workflow run microshift-builder.yaml -f microshift_version=$BRANCH"
    fi
else
    # Show general build commands
    LATEST_OVERALL_TAG=$(git ls-remote --tags "$MICROSHIFT_REPO" | grep -v '\^{}' | sed 's/.*refs\/tags\///' | sort -V -r | head -1)
    
    echo -e "${BLUE}🔧 Common Build Commands:${NC}"
    echo ""
    echo "# 🚀 RECOMMENDED: Build with latest tag"
    echo "MICROSHIFT_VERSION=$LATEST_OVERALL_TAG make build-optimized"
    echo ""
    echo "# Alternative: Build from main branch (latest commit)"
    echo "make build"
    echo ""
    echo "# Check specific branch tags"
    echo "$0 release-4.17"
    echo ""
    echo "# Discover and list all versions"
    echo "gh workflow run microshift-builder.yaml -f list_available_versions=true"
    echo ""
    echo "# Check tags for specific branch via GitHub Actions"
    echo "gh workflow run microshift-builder.yaml -f check_branch_tags=release-4.17 -f list_available_versions=true"
fi

# If auto-detected branch, show additional info
if [ -n "$AUTO_DETECTED_BRANCH" ]; then
    echo ""
    echo -e "${CYAN}💡 Other Options:${NC}"
    echo ""
    echo "# Check all available versions:"
    echo "make check-tags"
    echo ""
    echo "# Check different release branch:"
    echo "make check-tags BRANCH=release-4.17"
    echo ""
    echo "# See main branch and all tags:"
    echo "./scripts/check-microshift-tags.sh"
fi

echo ""
echo -e "${BLUE}📚 Documentation:${NC}"
echo "  • MicroShift Optimization: docs/MICROSHIFT_OPTIMIZATION.md"
echo "  • Workflow Documentation: .github/workflows/README.md" 