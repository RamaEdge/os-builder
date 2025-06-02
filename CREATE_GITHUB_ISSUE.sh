#!/bin/bash
# GitHub Issue Creation Script for AI Integration Proposal

echo "🎯 CREATING GITHUB ISSUE FOR AI INTEGRATION ROADMAP"
echo "=================================================="
echo ""

# Check if authenticated
if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    echo "Then re-run this script"
    exit 1
fi

echo "✅ GitHub CLI authenticated"
echo ""

# Create the issue
echo "🚀 Creating GitHub issue..."

gh issue create \
  --title "🤖 AI Integration Roadmap for Enhanced Build Performance and Intelligence" \
  --body-file AI_INTEGRATION_PROPOSAL.md \
  --label "enhancement,ai-integration,performance,security,automation,roadmap" \
  --repo RamaEdge/os-builder

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! GitHub issue created successfully!"
    echo ""
    echo "🔗 View the issue at: https://github.com/RamaEdge/os-builder/issues"
    echo ""
    echo "📋 Issue includes:"
    echo "   • 12 strategic AI integration opportunities"
    echo "   • 3-phase implementation plan (16 weeks)"
    echo "   • Clear ROI projections and success metrics"
    echo "   • Specific integration points with existing infrastructure"
    echo ""
else
    echo "❌ Failed to create issue. Please check authentication and try again."
    exit 1
fi 