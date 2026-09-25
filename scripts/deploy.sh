#!/usr/bin/env bash
# =============================================================================
# deploy.sh — deploy ONE already-built artifact to ONE environment, then smoke-test it.
# Called by the generated CD pipeline (devpilot-cd) for dev → sit → uat → prd, so the
# same build is promoted everywhere. Also runnable by hand to re-deploy.
#
#   bash scripts/deploy.sh <dev|sit|uat|prd> [artifact-dir=out]
#
# How it deploys (first match wins):
#   1. deploy/deploy.sh <env> <artifact-dir> <version>   — your project's own deploy
#      (App Service, IIS, Kubernetes, …). The artifact has web/ (Angular dist),
#      api/ (dotnet publish) and db/migrations.sql when EF migrations exist.
#   2. a deploy webhook: DEPLOY_HOOK (environment-scoped secret) or DEPLOY_HOOK_<ENV>
#   Neither → exit 1 (a deploy never "succeeds" without doing anything).
#
# Then scripts/smoke.sh <env>. Production from a terminal needs CONFIRM=1; in a
# pipeline the environment's approval is the gate.
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

ENVN=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')
ART="${2:-out}"
case "$ENVN" in dev|sit|uat|prd) ;; *) echo "Usage: deploy.sh <dev|sit|uat|prd> [artifact-dir]" >&2; exit 2 ;; esac
UP=$(printf '%s' "$ENVN" | tr '[:lower:]' '[:upper:]')
# The version stamped into the artifact at build time is the one being promoted.
if [ -f "$ART/VERSION" ]; then VERSION=$(tr -d '[:space:]' < "$ART/VERSION")
else VERSION=$(bash "$DIR/version.sh" current 2>/dev/null || echo 0.0.0); fi
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
IN_CI="${CI:-${TF_BUILD:-}}"

if [ "$ENVN" = "prd" ] && [ -z "$IN_CI" ] && [ "${CONFIRM:-0}" != "1" ]; then
  echo "⚠️  Production deploy of v$VERSION from a terminal — re-run with CONFIRM=1 to proceed." >&2
  exit 1
fi

echo "▶ deploy v$VERSION ($SHA) → $UP"
if [ -f deploy/deploy.sh ]; then
  bash deploy/deploy.sh "$ENVN" "$ART" "$VERSION" || { echo "❌ deploy/deploy.sh failed for $UP" >&2; exit 1; }
else
  HOOK_VAR="DEPLOY_HOOK_$UP"; HOOK="${DEPLOY_HOOK:-${!HOOK_VAR:-}}"
  case "$HOOK" in '$('*) HOOK="" ;; esac   # Azure leaves undefined $(VAR) as literal text
  if [ -z "$HOOK" ]; then
    echo "❌ No deploy target for $UP." >&2
    echo "   Add deploy/deploy.sh (receives: env, artifact dir, version), or set the secret" >&2
    echo "   DEPLOY_HOOK on the '$ENVN' environment (or DEPLOY_HOOK_$UP)." >&2
    exit 1
  fi
  CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 60 -X POST -H 'Content-Type: application/json' \
    --data "{\"environment\":\"$ENVN\",\"version\":\"$VERSION\",\"commit\":\"$SHA\"}" "$HOOK" 2>/dev/null)
  case "$CODE" in 2*) echo "  ✅ deploy hook accepted (HTTP $CODE)" ;; *) echo "❌ deploy hook failed (HTTP ${CODE:-000})" >&2; exit 1 ;; esac
fi

bash "$DIR/smoke.sh" "$ENVN" || { echo "❌ smoke test failed on $UP — do not promote v$VERSION" >&2; exit 1; }
echo "✅ v$VERSION live on $UP"
