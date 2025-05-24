#!/bin/bash
# GitVersion Demo Script
# Demonstrates GitVersion integration and versioning capabilities

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

header() {
    echo -e "${BLUE}[DEMO]${NC} $*"
}

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not in a git repository!"
        exit 1
    fi
}

# Check GitVersion installation
check_gitversion() {
    if command -v dotnet >/dev/null 2>&1; then
        if dotnet tool list -g | grep -q "gitversion.tool"; then
            info "✅ GitVersion tool is installed"
            return 0
        else
            warn "⚠️  GitVersion tool not installed"
            echo "Install with: dotnet tool install --global GitVersion.Tool"
            return 1
        fi
    else
        warn "⚠️  .NET SDK not found"
        echo "Install .NET SDK first, then: dotnet tool install --global GitVersion.Tool"
        return 1
    fi
}

# Show current version information
show_version_info() {
    header "Current Version Information"
    echo "================================"
    
    # Git information
    echo "Git Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
    echo "Git Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    echo "Git Status: $(git diff --quiet && echo 'clean' || echo 'dirty')"
    echo ""
    
    # GitVersion information (if available)
    if check_gitversion; then
        echo "GitVersion Information:"
        echo "  SemVer:     $(dotnet gitversion -showvariable SemVer 2>/dev/null || echo 'N/A')"
        echo "  Major:      $(dotnet gitversion -showvariable Major 2>/dev/null || echo 'N/A')"
        echo "  Minor:      $(dotnet gitversion -showvariable Minor 2>/dev/null || echo 'N/A')"
        echo "  Patch:      $(dotnet gitversion -showvariable Patch 2>/dev/null || echo 'N/A')"
        echo "  PreRelease: $(dotnet gitversion -showvariable PreReleaseTag 2>/dev/null || echo 'N/A')"
        echo "  Build:      $(dotnet gitversion -showvariable CommitsSinceVersionSource 2>/dev/null || echo 'N/A')"
    else
        echo "Fallback version: $(git describe --tags --always --dirty 2>/dev/null || echo 'latest')"
    fi
    echo ""
}

# Demonstrate branch-based versioning
demo_branch_versioning() {
    header "Branch-Based Versioning Demo"
    echo "============================="
    
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "Current branch: $current_branch"
    
    case "$current_branch" in
        main|master)
            echo "📋 Main branch versioning:"
            echo "  - Mode: ContinuousDelivery"
            echo "  - Increment: Patch"
            echo "  - Example: 1.0.1, 1.0.2, 1.0.3"
            ;;
        feature/*)
            echo "🚀 Feature branch versioning:"
            echo "  - Mode: ContinuousDelivery"
            echo "  - Tag: Beta"
            echo "  - Example: 1.0.1-beta.1, 1.0.1-beta.2"
            ;;
        release/*)
            echo "🎯 Release branch versioning:"
            echo "  - Mode: ContinuousDelivery"
            echo "  - Tag: prod"
            echo "  - Example: 1.1.0-prod.1, 1.1.0-prod.2"
            ;;
        *)
            echo "🔧 Other branch versioning:"
            echo "  - Uses default GitVersion rules"
            echo "  - May include branch name in version"
            ;;
    esac
    echo ""
}

# Show commit message conventions
demo_commit_conventions() {
    header "Commit Message Conventions"
    echo "=========================="
    echo "Control version increments with commit messages:"
    echo ""
    echo "🔴 Major version bump (breaking changes):"
    echo "   git commit -m \"feat: new API +semver: major\""
    echo "   1.0.0 → 2.0.0"
    echo ""
    echo "🟡 Minor version bump (new features):"
    echo "   git commit -m \"feat: add new feature +semver: minor\""
    echo "   1.0.0 → 1.1.0"
    echo ""
    echo "🟢 Patch version bump (bug fixes):"
    echo "   git commit -m \"fix: resolve issue +semver: patch\""
    echo "   1.0.0 → 1.0.1"
    echo ""
}

# Show build integration
demo_build_integration() {
    header "Build Integration Demo"
    echo "====================="
    echo "GitVersion is integrated into the build process:"
    echo ""
    echo "📦 Container Image Building:"
    echo "   make build                    # Uses GitVersion for tagging"
    echo "   make build IMAGE_TAG=v1.2.3   # Override with specific tag"
    echo ""
    echo "🔍 Version Information:"
    echo "   make version                  # Show all version details"
    echo "   dotnet gitversion             # Show GitVersion output"
    echo ""
    echo "🏷️  Container Labels:"
    echo "   Built images include OCI labels with version info:"
    echo "   - org.opencontainers.image.version"
    echo "   - org.opencontainers.image.created"
    echo "   - org.opencontainers.image.revision"
    echo "   - org.opencontainers.image.source"
    echo "   - org.opencontainers.image.branch"
    echo ""
}

# Show GitHub Actions integration
demo_github_actions() {
    header "GitHub Actions Integration"
    echo "=========================="
    echo "GitVersion is used in CI/CD workflows:"
    echo ""
    echo "🔄 Automatic Versioning:"
    echo "   - Version calculated on every build"
    echo "   - Multiple tags generated (semver, major.minor, latest)"
    echo "   - Artifacts named with version"
    echo ""
    echo "📋 Workflow Jobs:"
    echo "   1. gitversion    - Calculate version"
    echo "   2. build-and-scan - Build with version tags"
    echo "   3. build-iso     - Create ISOs with versioned images"
    echo ""
    echo "🏷️  Generated Tags:"
    echo "   - 1.0.1 (semantic version)"
    echo "   - 1.0 (major.minor)"
    echo "   - 1 (major)"
    echo "   - main-abc123-1234567890 (branch-commit-timestamp)"
    echo "   - latest (for main branch)"
    echo ""
}

# Main demo function
main() {
    echo "🎯 GitVersion Integration Demo"
    echo "=============================="
    echo ""
    
    check_git_repo
    
    show_version_info
    demo_branch_versioning
    demo_commit_conventions
    demo_build_integration
    demo_github_actions
    
    echo "📚 For more information:"
    echo "   - Documentation: docs/GITVERSION.md"
    echo "   - GitVersion docs: https://gitversion.net/"
    echo "   - Semantic versioning: https://semver.org/"
    echo ""
    
    info "Demo completed! 🎉"
}

# Run the demo
main "$@" 