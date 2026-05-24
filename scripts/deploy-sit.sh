#!/usr/bin/env bash
# =============================================================================
# deploy-sit.sh — Manual SIT deploy re-trigger
#
# In the normal Git Flow, CI deploys SIT automatically when you push a
# release/* branch. Run this only to re-trigger without a new commit.
#
# Usage:  bash scripts/deploy-sit.sh
# Requires: DEPLOY_HOOK_SIT env var  (or set in .env.local — never commit it)
# =============================================================================
set -euo pipefail

source "$(dirname "$0")/../.aidev/config.sh" 2>/dev/null || true

HOOK="${DEPLOY_HOOK_SIT:-}"

if [ -z "$HOOK" ]; then
  echo "❌ DEPLOY_HOOK_SIT is not set."
  echo "   Export it first:  export DEPLOY_HOOK_SIT=<deploy-hook-url>"
  exit 1
fi

echo "▶ Triggering SIT deploy..."
curl -s -X POST "$HOOK" | head -c 200
echo ""
echo "✅ Deploy triggered."
echo "   Watch: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/actions"
echo "   Test:  ${SIT_FRONTEND_URL:-<set SIT_FRONTEND_URL in config.sh>}"
