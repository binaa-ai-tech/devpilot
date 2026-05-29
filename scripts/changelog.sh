#!/usr/bin/env bash
# =============================================================================
# changelog.sh — assemble a CHANGELOG.md section for a release.
#
# Collects conventional commits since the last tag, groups them by type, and
# prepends a new version section to CHANGELOG.md (created if missing).
#
#   bash scripts/changelog.sh 1.2.0
# =============================================================================
set -uo pipefail

VERSION="${1:-}"
[ -z "$VERSION" ] && { echo "Usage: changelog.sh <version>   (e.g. 1.2.0)" >&2; exit 1; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
OUT="$ROOT/CHANGELOG.md"
DATE=$(date '+%Y-%m-%d')

LAST_TAG=$(git tag --sort=-version:refname 2>/dev/null | head -1)
RANGE="HEAD"; [ -n "$LAST_TAG" ] && RANGE="${LAST_TAG}..HEAD"

section() {
  local type="$1" title="$2"
  local lines
  lines=$(git log "$RANGE" --no-merges --pretty='%s' 2>/dev/null \
    | grep -E "^${type}(\(.+\))?!?:" \
    | sed -E "s/^${type}(\(.+\))?!?:[[:space:]]*//" | sed 's/^/- /')
  [ -n "$lines" ] && printf '\n### %s\n%s\n' "$title" "$lines"
}

BODY=""
BODY+=$(section feat "Features")
BODY+=$(section fix "Fixes")
BODY+=$(section perf "Performance")
BODY+=$(section refactor "Refactors")
BODY+=$(section docs "Documentation")
[ -z "$BODY" ] && BODY=$'\n- (no conventional-commit entries since '"${LAST_TAG:-start}"')'

NEW=$(printf '## v%s — %s\n%s\n' "$VERSION" "$DATE" "$BODY")

if [ -f "$OUT" ]; then
  TMP=$(mktemp)
  { printf '# Changelog\n\n'; printf '%s\n\n' "$NEW"; tail -n +2 "$OUT" | sed '/^# Changelog/d'; } > "$TMP"
  mv "$TMP" "$OUT"
else
  { printf '# Changelog\n\n'; printf '%s\n' "$NEW"; } > "$OUT"
fi

echo "✅ CHANGELOG.md updated for v$VERSION (since ${LAST_TAG:-start})"
