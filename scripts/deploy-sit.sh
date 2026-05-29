#!/usr/bin/env bash
# =============================================================================
# deploy-sit.sh — Manual SIT deploy trigger (local use / legacy)
#
# In the normal Git Flow the CI pipeline deploys SIT automatically when you
# push a release/* branch.  Run this script only if you need to re-trigger
# a SIT deploy without pushing a new commit.
#
# Usage:  bash scripts/deploy-sit.sh
# Env var: DEPLOY_HOOK_SIT  (or set in .env.local — never commit it)
# =============================================================================
set -euo pipefail

HOOK="${DEPLOY_HOOK_SIT:-}"

if [ -z "$HOOK" ]; then
  echo "❌ DEPLOY_HOOK_SIT is not set."
  echo "   Export it first:  export DEPLOY_HOOK_SIT=<render-hook-url>"
  exit 1
fi

echo "▶ Triggering SIT deploy via Render hook..."
curl -s -X POST "$HOOK" | head -c 200
echo ""
echo "✅ Deploy triggered."
echo "   Watch:  https://github.com/<org>/<repo>/actions"
echo "   Test:   ${SIT_URL:-<your-sit-url>}"
