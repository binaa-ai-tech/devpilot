#!/usr/bin/env bash
# =============================================================================
# deploy-prd.sh — Manual PRODUCTION deploy re-trigger (emergency use only)
#
# ⚠  PRODUCTION — real users, real data.
#
# Normal flow: merge release/* → main → CI → manual approval in GitHub Actions
# → production deploys automatically.
# Run this ONLY if the CI deploy failed and needs re-triggering.
#
# Usage:  bash scripts/deploy-prd.sh
# =============================================================================
set -euo pipefail

source "$(dirname "$0")/../.aidev/config.sh" 2>/dev/null || true

HOOK="${DEPLOY_HOOK_PRD:-}"

if [ -z "$HOOK" ]; then
  echo "❌ DEPLOY_HOOK_PRD is not set."
  echo "   Export it first:  export DEPLOY_HOOK_PRD=<deploy-hook-url>"
  exit 1
fi

echo ""
echo "⚠  You are about to deploy to PRODUCTION."
read -r -p "   Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "▶ Triggering PRODUCTION deploy..."
curl -s -X POST "$HOOK" | head -c 200
echo ""
echo "✅ Deploy triggered."
echo "   Watch: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/actions"
echo "   URL:   ${PRD_FRONTEND_URL:-<set PRD_FRONTEND_URL in config.sh>}"
