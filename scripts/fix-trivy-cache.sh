#!/bin/bash
# Fix Trivy Cache - Remove problematic AWS/Cloud policy files
# This script resolves AWS EC2 AMI policy parsing errors

set -euo pipefail

echo "🔧 Fixing Trivy cache issues..."
echo "==============================================="

# Define cache directories to check
CACHE_DIRS=(
    "$HOME/.cache/trivy"
    "/home/ravi/actions-runner/_work/os-builder/os-builder/.cache/trivy"
    ".cache/trivy"
    "/tmp/trivy"
)

# Function to clean cache directory
clean_cache_dir() {
    local cache_dir="$1"
    
    if [ -d "$cache_dir" ]; then
        echo "📂 Cleaning cache directory: $cache_dir"
        
        # Remove cloud policy directories
        find "$cache_dir" -type d -name "*cloud*" -exec rm -rf {} + 2>/dev/null || true
        find "$cache_dir" -type d -name "*aws*" -exec rm -rf {} + 2>/dev/null || true
        find "$cache_dir" -type d -name "*gcp*" -exec rm -rf {} + 2>/dev/null || true
        find "$cache_dir" -type d -name "*azure*" -exec rm -rf {} + 2>/dev/null || true
        
        # Remove problematic .rego files
        find "$cache_dir" -name "*ami*.rego" -delete 2>/dev/null || true
        find "$cache_dir" -name "*ec2*.rego" -delete 2>/dev/null || true
        find "$cache_dir" -name "*s3*.rego" -delete 2>/dev/null || true
        find "$cache_dir" -name "*vpc*.rego" -delete 2>/dev/null || true
        find "$cache_dir" -path "*/cloud/*" -name "*.rego" -delete 2>/dev/null || true
        
        # Remove policy content that causes issues
        find "$cache_dir" -type d -path "*/policy/content/policies/cloud" -exec rm -rf {} + 2>/dev/null || true
        
        echo "✅ Cache directory cleaned: $cache_dir"
    else
        echo "⚠️  Cache directory not found: $cache_dir"
    fi
}

# Clean all potential cache directories
for cache_dir in "${CACHE_DIRS[@]}"; do
    clean_cache_dir "$cache_dir"
done

# Also clean GitHub Actions runner cache if we're in that environment
if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    echo "🐙 GitHub Actions environment detected"
    ACTIONS_CACHE="$GITHUB_WORKSPACE/.cache/trivy"
    clean_cache_dir "$ACTIONS_CACHE"
fi

echo ""
echo "🧹 Additional cleanup..."

# Remove any corrupted database files
find . -name "*.db" -path "*trivy*" -delete 2>/dev/null || true

# Clear environment variables that might interfere
unset TRIVY_CACHE_DIR 2>/dev/null || true
unset TRIVY_POLICY_BUNDLE_REPOSITORY 2>/dev/null || true

echo ""
echo "✅ Trivy cache cleanup completed!"
echo ""
echo "🔧 Next steps:"
echo "1. Run your security scan again"
echo "2. The updated .trivy.yaml will prevent future cloud policy issues"
echo "3. Environment variables in trivy-scan action will block policy loading"
echo ""
echo "📋 If issues persist, you can also run:"
echo "   export TRIVY_SKIP_CHECK_UPDATE=true" 