#!/usr/bin/env bash
# =============================================================================
# deploy-prd.sh — Manual PRODUCTION deploy trigger (emergency use only)
#
# ⚠  PRODUCTION — use with extreme care.
#
# Normal flow: merge release/* → main in GitHub → CI runs → manual approval
# in GitHub Actions → production deploys automatically.
#
# Run this script ONLY if the CI deploy failed and you need to re-trigger.
#
# Usage:  bash scripts/deploy-prd.sh
# Env var: DEPLOY_HOOK_PRD
# =============================================================================
set -euo pipefail

HOOK="${DEPLOY_HOOK_PRD:-}"

if [ -z "$HOOK" ]; then
  echo "❌ DEPLOY_HOOK_PRD is not set."
  echo "   Export it first:  export DEPLOY_HOOK_PRD=<deploy-hook-url>"
  exit 1
fi

echo ""
echo "⚠  You are about to deploy to PRODUCTION."
echo "   This affects real users and real data."
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
echo "   Watch:  https://github.com/<org>/<repo>/actions"
echo "   URL:    ${PRD_URL:-<your-prd-url>}"
