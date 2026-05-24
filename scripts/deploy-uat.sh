#!/usr/bin/env bash
# =============================================================================
# deploy-uat.sh — Manual UAT deploy re-trigger
#
# Normally CI deploys UAT after a manual approval gate in GitHub Actions.
# Run this only to re-trigger without going through the Actions UI.
#
# Usage:  bash scripts/deploy-uat.sh
# =============================================================================
set -euo pipefail

source "$(dirname "$0")/../.aidev/config.sh" 2>/dev/null || true

HOOK="${DEPLOY_HOOK_UAT:-}"

if [ -z "$HOOK" ]; then
  echo "❌ DEPLOY_HOOK_UAT is not set."
  echo "   Export it first:  export DEPLOY_HOOK_UAT=<deploy-hook-url>"
  exit 1
fi

echo "▶ Triggering UAT deploy..."
curl -s -X POST "$HOOK" | head -c 200
echo ""
echo "✅ Deploy triggered."
echo "   Watch: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/actions"
echo "   Test:  ${UAT_FRONTEND_URL:-<set UAT_FRONTEND_URL in config.sh>}"
