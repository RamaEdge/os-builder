#!/bin/bash
# Unified MicroShift Management Script
# Combines check strategy, tag checking, and version management

set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/microshift-utils.sh"

# Default values
MICROSHIFT_VERSION="${MICROSHIFT_VERSION:-release-4.19}"
MICROSHIFT_REPO="${MICROSHIFT_REPO:-https://github.com/openshift/microshift.git}"
REGISTRY="${REGISTRY:-ghcr.io}"
REPO_OWNER="${REPO_OWNER:-ramaedge}"

# Show usage
show_usage() {
    echo -e "${BLUE}🔧 MicroShift Management Tool${NC}"
    echo "============================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  check     - Check build strategy and recommendations"
    echo "  tags      - List available tags for current/specified branch"
    echo "  versions  - Show all available versions"
    echo "  status    - Show current configuration status"
    echo ""
    echo "Options:"
    echo "  --branch BRANCH   - Specify branch for tag operations"
    echo "  --version VERSION - Override MICROSHIFT_VERSION"
    echo "  --help, -h        - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 check                    # Check build strategy for current version"
    echo "  $0 tags                     # Show tags for current branch"
    echo "  $0 tags --branch release-4.17  # Show tags for specific branch"
    echo "  $0 versions                 # Show all available versions"
    echo "  $0 status                   # Show current configuration"
    echo ""
    echo "Environment variables:"
    echo "  MICROSHIFT_VERSION  = $MICROSHIFT_VERSION"
    echo "  MICROSHIFT_REPO     = $MICROSHIFT_REPO"
    echo "  REGISTRY            = $REGISTRY"
    echo "  REPO_OWNER          = $REPO_OWNER"
}

# Check build strategy
cmd_check() {
    echo -e "${BLUE}🔍 MicroShift Build Strategy Checker${NC}"
    echo "===================================="
    echo ""
    
    # Get version tag
    info "Determining MicroShift version tag..."
    local version_tag
    version_tag=$(get_microshift_version_tag "$MICROSHIFT_VERSION" "$MICROSHIFT_REPO")
    
    echo "🏷️  Target version: $version_tag"
    echo ""
    
    # Check for pre-built image
    local microshift_image="${REGISTRY}/${REPO_OWNER}/microshift-builder:${version_tag}"
    info "Checking for pre-built image: $microshift_image"
    
    if check_prebuilt_image "$version_tag" "$REGISTRY" "$REPO_OWNER"; then
        echo -e "${GREEN}✅ Pre-built MicroShift binary available!${NC}"
        echo ""
        echo -e "${GREEN}🚀 RECOMMENDED: Use optimized build${NC}"
        echo "   make build-optimized"
        echo ""
        echo "📊 Expected build time: ~5-8 minutes (85% faster)"
    else
        echo -e "${YELLOW}⚠️  Pre-built MicroShift binary not available${NC}"
        echo ""
        echo -e "${YELLOW}🔨 FALLBACK: Source build required${NC}"
        echo "   make build"
        echo ""
        echo "📊 Expected build time: ~15-25 minutes"
        echo ""
        echo -e "${BLUE}🚀 OPTIMIZATION OPPORTUNITY:${NC}"
        echo "   Build MicroShift separately for future reuse:"
        echo "   gh workflow run microshift-builder.yaml -f microshift_version=$version_tag"
    fi
    
    echo ""
    echo -e "${BLUE}📋 Build Information:${NC}"
    echo "   MicroShift Version: $version_tag"
    echo "   MicroShift Repo: $MICROSHIFT_REPO"
    echo "   Registry: $REGISTRY"
}

# Show tags for branch
cmd_tags() {
    local branch="$1"
    
    if [ -z "$branch" ] && [[ "$MICROSHIFT_VERSION" =~ ^release- ]]; then
        branch="$MICROSHIFT_VERSION"
        info "Using MICROSHIFT_VERSION as branch: $branch"
    fi
    
    echo -e "${BLUE}🔍 MicroShift Tag Discovery${NC}"
    echo "=============================="
    echo ""
    echo "📡 Repository: $MICROSHIFT_REPO"
    echo ""
    
    if [ -n "$branch" ]; then
        echo -e "${GREEN}🔍 Tags for Branch: ${YELLOW}$branch${NC}"
        echo "================================"
        
        local branch_tags
        branch_tags=$(get_branch_tags "$branch" "$MICROSHIFT_REPO")
        
                 if [ -n "$branch_tags" ]; then
             local latest_tag
             latest_tag=$(echo "$branch_tags" | head -1)
             echo ""
             echo -e "${GREEN}🎯 LATEST RECOMMENDED TAG: ${CYAN}$latest_tag${NC}"
             echo ""
             echo "Available tags for $branch (latest first):"
             echo "$branch_tags" | head -10 | sed 's/^/  /'
            
            echo ""
            echo -e "${BLUE}📦 Checking for pre-built binary...${NC}"
            if check_prebuilt_image "$latest_tag" "$REGISTRY" "$REPO_OWNER"; then
                echo -e "  ${GREEN}✅ Pre-built binary available${NC}"
            else
                echo -e "  ${YELLOW}⚠️  Pre-built binary not available${NC}"
            fi
            
                         echo ""
             echo -e "${BLUE}🔧 Recommended Build Commands:${NC}"
             echo "# 🚀 RECOMMENDED: Build with latest tag (fastest if pre-built binary available)"
             echo "MICROSHIFT_VERSION=$latest_tag make build-optimized"
                         echo ""
             echo "# Alternative: Build from $branch branch directly (latest commit)"
             echo "MICROSHIFT_VERSION=$branch make build"
        else
            echo -e "${YELLOW}⚠️  No tags found for branch: $branch${NC}"
        fi
    else
        # Show general information
        echo -e "${GREEN}🚀 Main Branch:${NC}"
        local main_commit
        main_commit=$(git ls-remote "$MICROSHIFT_REPO" HEAD | cut -f1 | cut -c1-8)
        echo "  main (latest commit: $main_commit)"
        echo ""
        
                 echo -e "${GREEN}📋 Latest Tags (All Branches):${NC}"
         git ls-remote --tags "$MICROSHIFT_REPO" | grep -v '\^{}' | sed 's/.*refs\/tags\///' | sort -V -r | head -10 | sed 's/^/  /'
        echo ""
        
        echo -e "${GREEN}🌿 Available Release Branches:${NC}"
        get_release_branches "$MICROSHIFT_REPO" | head -10 | sed 's/^/  /'
    fi
}

# Show all versions
cmd_versions() {
    echo -e "${BLUE}📋 All Available MicroShift Versions${NC}"
    echo "======================================"
    echo ""
    
    echo -e "${GREEN}🌿 Release Branches:${NC}"
    get_release_branches "$MICROSHIFT_REPO" | sed 's/^/  /'
    echo ""
    
    echo -e "${GREEN}📋 Latest Tags (sorted by version):${NC}"
    git ls-remote --tags "$MICROSHIFT_REPO" | grep -v '\^{}' | sed 's/.*refs\/tags\///' | sort -V -r | head -20 | sed 's/^/  /'
}

# Show status
cmd_status() {
    echo -e "${BLUE}📋 MicroShift Configuration Status${NC}"
    echo "===================================="
    echo ""
    
    local version_tag
    version_tag=$(get_microshift_version_tag "$MICROSHIFT_VERSION" "$MICROSHIFT_REPO")
    
    echo "📦 Current Configuration:"
    echo "   MICROSHIFT_VERSION  = $MICROSHIFT_VERSION"
    echo "   Resolved Version    = $version_tag"
    echo "   Repository          = $MICROSHIFT_REPO"
    echo "   Registry            = $REGISTRY"
    echo "   Repo Owner          = $REPO_OWNER"
    echo ""
    
    echo "🔍 Pre-built Binary Status:"
    if check_prebuilt_image "$version_tag" "$REGISTRY" "$REPO_OWNER"; then
        echo -e "   ${GREEN}✅ Available${NC} - Use 'make build-optimized' for fast builds"
    else
        echo -e "   ${YELLOW}❌ Not Available${NC} - Will build from source"
    fi
    echo ""
    
    echo "🔧 Recommended Actions:"
    if check_prebuilt_image "$version_tag" "$REGISTRY" "$REPO_OWNER"; then
        echo "   make build-optimized    # Fast build with pre-built binary"
    else
        echo "   make build              # Build from source"
        echo "   $0 tags                 # Check for alternative versions"
    fi
}

# Parse arguments
COMMAND=""
BRANCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        check|tags|versions|status)
            COMMAND="$1"
            shift
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --version)
            MICROSHIFT_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Execute command
case "$COMMAND" in
    check)
        cmd_check
        ;;
    tags)
        cmd_tags "$BRANCH"
        ;;
    versions)
        cmd_versions
        ;;
    status)
        cmd_status
        ;;
    "")
        warn "No command specified"
        show_usage
        exit 1
        ;;
    *)
        error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac 