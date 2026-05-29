#!/usr/bin/env bash
# =============================================================================
# rollback.sh — prepare a production rollback to a previous release tag.
#
# Conservative by design: it shows the plan and (only with CONFIRM=1) creates a
# rollback branch at the target tag and pushes it. A human merges/deploys —
# devpilot never force-pushes or rewrites production history.
#
#   bash scripts/rollback.sh                 # roll back to the previous tag (plan only)
#   bash scripts/rollback.sh 1.3.0           # target a specific tag
#   CONFIRM=1 bash scripts/rollback.sh 1.3.0 # create + push the rollback branch
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

CURRENT=$(git tag --sort=-version:refname 2>/dev/null | head -1)
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  TARGET=$(git tag --sort=-version:refname 2>/dev/null | sed -n '2p')   # the one before current
fi

[ -z "$TARGET" ] && { echo "❌ No target tag found. Pass one explicitly: rollback.sh <version>" >&2; exit 1; }
TAG="$TARGET"; git rev-parse "v$TARGET" >/dev/null 2>&1 && TAG="v$TARGET"
git rev-parse "$TAG" >/dev/null 2>&1 || { echo "❌ tag '$TAG' not found" >&2; exit 1; }

BRANCH="rollback/${TARGET}"
echo "── rollback plan ─────────────────────────────────────"
echo "  current release : ${CURRENT:-<none>}"
echo "  roll back to     : $TAG"
echo "  rollback branch  : $BRANCH"
echo "──────────────────────────────────────────────────────"

if [ "${CONFIRM:-0}" != "1" ]; then
  echo "Dry run. To execute:  CONFIRM=1 bash scripts/rollback.sh ${TARGET}"
  echo "Then open a PR from $BRANCH into main and deploy via /binaa-prd $TARGET."
  exit 0
fi

git checkout -b "$BRANCH" "$TAG" || { echo "❌ could not create $BRANCH" >&2; exit 1; }
git push -u origin "$BRANCH" 2>/dev/null || echo "⚠️  push failed — push $BRANCH manually"
echo "✅ rollback branch $BRANCH created at $TAG."
echo "   Next: open a PR into main, get review, then redeploy that tag."
