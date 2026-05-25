#!/usr/bin/env bash
# =============================================================================
# deploy-dev.sh — Manual DEV deploy trigger (local use)
#
# Normally CI deploys DEV automatically on every push to develop.
# Run this only to re-trigger without pushing a new commit.
#
# Usage:  bash scripts/deploy-dev.sh
# Env var: DEPLOY_HOOK_DEV
# =============================================================================
set -euo pipefail

HOOK="${DEPLOY_HOOK_DEV:-}"

if [ -z "$HOOK" ]; then
  echo "❌ DEPLOY_HOOK_DEV is not set."
  echo "   Export it first:  export DEPLOY_HOOK_DEV=<render-hook-url>"
  exit 1
fi

echo "▶ Triggering DEV deploy via Render hook..."
curl -s -X POST "$HOOK" | head -c 200
echo ""
echo "✅ Deploy triggered."
echo "   Watch:  https://github.com/<org>/<repo>/actions"
echo "   Test:   ${DEV_URL:-<your-dev-url>}"
