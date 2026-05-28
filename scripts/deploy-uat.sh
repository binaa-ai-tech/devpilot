#!/usr/bin/env bash
# =============================================================================
# deploy-uat.sh — Manual UAT deploy trigger (local use)
#
# Normally CI deploys UAT after a manual approval gate in GitHub Actions.
# Run this only to re-trigger without going through the Actions UI.
#
# Usage:  bash scripts/deploy-uat.sh
# Env var: DEPLOY_HOOK_UAT
# =============================================================================
set -euo pipefail

HOOK="${DEPLOY_HOOK_UAT:-}"

if [ -z "$HOOK" ]; then
  echo "❌ DEPLOY_HOOK_UAT is not set."
  echo "   Export it first:  export DEPLOY_HOOK_UAT=<deploy-hook-url>"
  echo "   (Azure slot swap command or Render hook — see CI workflow for details)"
  exit 1
fi

echo "▶ Triggering UAT deploy..."
curl -s -X POST "$HOOK" | head -c 200
echo ""
echo "✅ Deploy triggered."
echo "   Watch:  https://github.com/<org>/<repo>/actions"
echo "   Test:   ${UAT_URL:-<your-uat-url>}"
