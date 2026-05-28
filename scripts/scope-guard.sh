#!/usr/bin/env bash
# =============================================================================
# scope-guard.sh <layer> [base-branch] — report changes outside a vertical layer.
#
# Makes the layer-locks in /ceo-subdomain enforceable instead of advisory.
# Layers: frontend | backend | db | security
#
# Advisory by default (exit 0, prints warnings). Set STRICT=1 to exit 1 when any
# changed file falls outside the layer — useful as a hard gate after an agent runs.
#
#   bash scripts/scope-guard.sh backend "$BASE_BRANCH"
#   STRICT=1 bash scripts/scope-guard.sh frontend
# =============================================================================
set -uo pipefail

LAYER="${1:-}"; BASE="${2:-}"
[ -z "$LAYER" ] && { echo "Usage: scope-guard.sh <frontend|backend|db|security> [base-branch]" >&2; exit 2; }

changed_files() {
  {
    [ -n "$BASE" ] && git diff --name-only "${BASE}...HEAD" 2>/dev/null
    git diff --name-only 2>/dev/null
    git diff --cached --name-only 2>/dev/null
  } | sort -u | grep -v '^$' || true
}

# Returns 0 (true) when $1 is OUT of scope for $LAYER.
is_violation() {
  local f="$1"
  case "$f" in
    docs/*|*.md) return 1 ;;   # docs are always allowed
  esac
  case "$LAYER" in
    frontend) echo "$f" | grep -Eq '\.(cs|sql)$|/[Mm]igrations/' && return 0 ;;
    backend)  echo "$f" | grep -Eq '\.(html|scss|css|vue)$|\.component\.ts$|/[Mm]igrations/' && return 0 ;;
    db)       echo "$f" | grep -Eqv '/[Mm]igrations/|\.sql$' && return 0 ;;
    security) return 1 ;;       # security touches cross-cutting files by design
    *) echo "Unknown layer: $LAYER" >&2; exit 2 ;;
  esac
  return 1
}

bad=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if is_violation "$f"; then echo "  ⚠️  out-of-scope ($LAYER): $f" >&2; bad=$((bad + 1)); fi
done < <(changed_files)

if [ "$bad" -gt 0 ]; then
  echo "scope-guard: $bad file(s) changed outside the '$LAYER' layer." >&2
  [ "${STRICT:-0}" = "1" ] && exit 1
else
  echo "scope-guard: all changes within the '$LAYER' layer ✅"
fi
exit 0
