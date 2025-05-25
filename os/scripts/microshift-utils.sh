#!/bin/bash
# MicroShift Utility Functions
# Shared functions used across MicroShift scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Get version tag from MICROSHIFT_VERSION
# Usage: get_microshift_version_tag "$MICROSHIFT_VERSION" "$MICROSHIFT_REPO"
get_microshift_version_tag() {
    local microshift_version="${1:-main}"
    local microshift_repo="${2:-https://github.com/openshift/microshift.git}"
    local version_tag=""
    
    if [ "$microshift_version" = "main" ]; then
        local commit_hash
        commit_hash=$(git ls-remote "$microshift_repo" HEAD | cut -f1 | cut -c1-8 2>/dev/null || echo "")
        if [ -n "$commit_hash" ]; then
            version_tag="main-${commit_hash}"
        else
            version_tag="main"
        fi
    elif [[ "$microshift_version" =~ ^release- ]]; then
        # It's a release branch, get latest commit for that branch
        local commit_hash
        commit_hash=$(git ls-remote "$microshift_repo" "refs/heads/$microshift_version" | cut -f1 | cut -c1-8 2>/dev/null || echo "")
        if [ -n "$commit_hash" ]; then
            version_tag="${microshift_version}-${commit_hash}"
        else
            version_tag="$microshift_version"
        fi
    elif [[ "$microshift_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # It's already a version tag, use as-is
        version_tag="$microshift_version"
    else
        # Use as-is for other cases
        version_tag="$microshift_version"
    fi
    
    echo "$version_tag"
}

# Check if pre-built MicroShift image exists
# Usage: check_prebuilt_image "$version_tag" "$registry" "$repo_owner"
check_prebuilt_image() {
    local version_tag="$1"
    local registry="${2:-ghcr.io}"
    local repo_owner="${3:-ramaedge}"
    local microshift_image="${registry}/${repo_owner}/microshift-builder:${version_tag}"
    
    local container_cmd=""
    if command -v docker >/dev/null 2>&1; then
        container_cmd="docker"
    elif command -v podman >/dev/null 2>&1; then
        container_cmd="podman"
    else
        return 1
    fi
    
    if $container_cmd pull "$microshift_image" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get latest tags for a branch (sorted by version, latest first)
# Usage: get_branch_tags "$branch" "$microshift_repo"
get_branch_tags() {
    local branch="$1"
    local microshift_repo="${2:-https://github.com/openshift/microshift.git}"
    local branch_version=$(echo "$branch" | sed 's/release-//')
    
    # Get tags and sort them with proper priority: rc > ec, then by date
    local tags
    tags=$(git ls-remote --tags "$microshift_repo" | grep -v '\^{}' | grep "refs/tags/.*$branch_version" | sed 's/.*refs\/tags\///')
    
    if [ -z "$tags" ]; then
        return
    fi
    
    # Sort with priority: rc tags first, then ec tags, all sorted by date (newer first)
    {
        echo "$tags" | grep -- '-rc\.' | sort -t- -k3,3r 2>/dev/null || true
        echo "$tags" | grep -- '-ec\.' | sort -t- -k3,3r 2>/dev/null || true
        echo "$tags" | grep -v -- '-rc\.' | grep -v -- '-ec\.' | sort -V -r 2>/dev/null || true
    } | grep -v '^$'
}

# Get the latest tag for a specific branch
# Usage: get_latest_tag_for_branch "$branch" "$microshift_repo"
get_latest_tag_for_branch() {
    local branch="$1"
    local microshift_repo="${2:-https://github.com/openshift/microshift.git}"
    
    get_branch_tags "$branch" "$microshift_repo" | head -1
}

# Get all release branches
# Usage: get_release_branches "$microshift_repo"
get_release_branches() {
    local microshift_repo="${1:-https://github.com/openshift/microshift.git}"
    git ls-remote --heads "$microshift_repo" | grep 'refs/heads/release-' | sed 's/.*refs\/heads\///'
}

# Get latest overall tag (sorted by version, prioritizing recent releases)
# Usage: get_latest_tag "$microshift_repo"
get_latest_tag() {
    local microshift_repo="${1:-https://github.com/openshift/microshift.git}"
    
    # Get all tags and prioritize release candidates, then engineering candidates
    local all_tags
    all_tags=$(git ls-remote --tags "$microshift_repo" | grep -v '\^{}' | sed 's/.*refs\/tags\///')
    
    # Try RC tags first (most stable)
    local latest_tag
    latest_tag=$(echo "$all_tags" | grep -- '-rc\.' | sort -t- -k3,3r | head -1)
    
    if [ -z "$latest_tag" ]; then
        # Then try EC tags (engineering candidates)
        latest_tag=$(echo "$all_tags" | grep -- '-ec\.' | sort -t- -k3,3r | head -1)
    fi
    
    if [ -z "$latest_tag" ]; then
        # Fall back to version sort for all tags
        latest_tag=$(echo "$all_tags" | sort -V -r | head -1)
    fi
    
    echo "$latest_tag"
} 