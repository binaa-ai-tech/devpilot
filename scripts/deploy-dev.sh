#!/usr/bin/env bash
# =============================================================================
# deploy-dev.sh — Manual DEV deploy re-trigger
#
# CI deploys DEV automatically on every push to develop.
# Run this only to re-trigger without pushing a new commit.
#
# Usage:  bash scripts/deploy-dev.sh
# =============================================================================
set -euo pipefail

source "$(dirname "$0")/../.aidev/config.sh" 2>/dev/null || true

HOOK="${DEPLOY_HOOK_DEV:-}"

if [ -z "$HOOK" ]; then
  echo "❌ DEPLOY_HOOK_DEV is not set."
  echo "   Export it first:  export DEPLOY_HOOK_DEV=<deploy-hook-url>"
  exit 1
fi

echo "▶ Triggering DEV deploy..."
curl -s -X POST "$HOOK" | head -c 200
echo ""
echo "✅ Deploy triggered."
echo "   Watch: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/actions"
echo "   Test:  ${DEV_FRONTEND_URL:-<set DEV_FRONTEND_URL in config.sh>}"
