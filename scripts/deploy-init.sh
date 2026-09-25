#!/usr/bin/env bash
# =============================================================================
# deploy-init.sh — give the CD pipeline a deploy target in one command.
#
#   bash scripts/deploy-init.sh <appservice | iis | kubernetes | hook> [--force]
#
# Copies a ready template to deploy/deploy.sh (+ deploy/db.sh, which applies the
# release's db/migrations.sql with sqlcmd) and lists the settings to add per
# environment (dev · sit · uat · prd) as pipeline secrets/variables:
#   appservice  Azure App Service — API + Angular, optional slot swap (zero downtime)
#   iis         IIS on Windows Server over SSH — app pool stop → robocopy /MIR → start
#   kubernetes  AKS / any cluster — images built once per version, rollout + auto-undo
#   hook        no file: set a DEPLOY_HOOK secret per environment (webhook deploy)
# Edit deploy/deploy.sh freely afterwards — it is your project's file.
# =============================================================================
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
T="${1:-}"; FORCE="${2:-}"
TPL="$ROOT/.devpilot/templates/deploy"

case "$T" in
  appservice|iis|kubernetes) ;;
  hook)
    echo "Webhook deploy: add a DEPLOY_HOOK secret to each environment (dev · sit · uat · prd)."
    echo "scripts/deploy.sh POSTs {environment, version, commit} to it, then smoke-tests."
    exit 0 ;;
  *) sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
[ -f "$TPL/$T.sh" ] || { echo "❌ template $TPL/$T.sh missing — run: bash install.sh --update" >&2; exit 1; }
if [ -f deploy/deploy.sh ] && [ "$FORCE" != "--force" ]; then
  echo "ℹ️  deploy/deploy.sh already exists — keep it, or replace with: bash scripts/deploy-init.sh $T --force"
  exit 0
fi

mkdir -p deploy
cp "$TPL/$T.sh" deploy/deploy.sh && cp "$TPL/db.sh" deploy/db.sh && chmod +x deploy/deploy.sh deploy/db.sh
echo "✅ deploy/deploy.sh ($T) + deploy/db.sh — commit them."
echo ""
echo "Add these per environment — GitHub: Settings → Environments → <env> → secrets/variables"
echo "with these names · Azure: pipeline variables prefixed by the stage (DEV_ SIT_ UAT_ PRD_,"
echo "e.g. PRD_API_APP, PRD_SQL_PASSWORD as a secret):"
awk '/^# need:/ { f = 1 } f && !/^#/ { exit } f { sub(/^# ?/, "  "); print }' deploy/deploy.sh
echo ""
echo "Test from a terminal (non-production): bash scripts/deploy.sh dev out   (after a build into out/)"
