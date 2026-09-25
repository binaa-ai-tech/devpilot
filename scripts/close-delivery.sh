#!/usr/bin/env bash
# =============================================================================
# close-delivery.sh — everything after a CONFIRMED merge, in one step.
#
#   close-delivery.sh --pr <url> [--version X.Y.Z] [--sprint <id>] KEY [KEY...]
#
#   1. each item   → comment (PR + version) and Done
#   2. each parent → Done when all its children are done (Epic closes with its last Story)
#   3. the sprint  → closed when nothing in it is still open (else reported, left open)
#   4. git         → back on base_branch, pulled, merged work branch deleted locally
#
# Never call it before the merge is confirmed (gh exit 0, MCP merged:true, or
# azdo.sh pr-complete → merged). Tracker failures are reported, never fatal.
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=devpilot-lib.sh
. "$DIR/devpilot-lib.sh"

PR=""; VERSION=""; SPRINT=""; KEYS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --pr)      PR="${2:-}"; shift 2 ;;
    --version) VERSION="${2:-}"; shift 2 ;;
    --sprint)  SPRINT="${2:-}"; shift 2 ;;
    *)         KEYS+=("$1"); shift ;;
  esac
done
[ "${#KEYS[@]}" -gt 0 ] || { echo "Usage: close-delivery.sh --pr <url> [--version X.Y.Z] [--sprint <id>] KEY..." >&2; exit 1; }

BASE=$(dp_cfg base_branch); BASE="${BASE:-develop}"
T="bash $DIR/tracker.sh"
NOW=$(date '+%Y-%m-%d %H:%M')

CLOSED=0; FAILED=0; PARENTS=""
for K in "${KEYS[@]}"; do
  $T comment "$K" "✅ Merged into $BASE${VERSION:+ as v$VERSION} [$NOW] · PR: ${PR:-n/a}" 2>/dev/null || true
  if $T close "$K" 2>/dev/null; then CLOSED=$((CLOSED + 1)); else FAILED=$((FAILED + 1)); echo "⚠️  could not close $K" >&2; fi
  P=$($T show "$K" 2>/dev/null | sed -n 's/^Parent:[[:space:]]*//p' | head -1)
  case "$P" in ""|-) ;; *) case " $PARENTS " in *" $P "*) ;; *) PARENTS="$PARENTS $P" ;; esac ;; esac
done

for P in $PARENTS; do $T close-parent "$P" 2>&1 | sed 's/^/  /' >&2 || true; done

SPRINT_STATE="-"
if [ -n "$SPRINT" ]; then
  SPRINT_STATE=$($T sprint close "$SPRINT" 2>/dev/null); RC=$?
  case "$RC:$SPRINT_STATE" in
    0:*)       SPRINT_STATE="closed" ;;
    4:open:*)  SPRINT_STATE="open (${SPRINT_STATE#open:} item(s) still in progress)" ;;
    *)         SPRINT_STATE="not closed (tracker error)" ;;
  esac
fi

WORK=$(git branch --show-current 2>/dev/null)
if [ -n "$WORK" ] && [ "$WORK" != "$BASE" ]; then
  git fetch origin "$BASE" >/dev/null 2>&1 || true
  if git checkout "$BASE" >/dev/null 2>&1; then
    git pull --ff-only origin "$BASE" >/dev/null 2>&1 || echo "⚠️  $BASE could not fast-forward — pull it by hand" >&2
    git branch -D "$WORK" >/dev/null 2>&1 || true   # squash-merged: -D is expected
  else
    echo "⚠️  could not switch to $BASE (uncommitted changes?)" >&2
  fi
fi

echo "🏁 Closed $CLOSED item(s)${FAILED:+$( [ "$FAILED" -gt 0 ] && echo " · $FAILED failed")} · parents checked:${PARENTS:- none} · sprint: $SPRINT_STATE · now on $(git branch --show-current 2>/dev/null)"
[ "$FAILED" -eq 0 ]
