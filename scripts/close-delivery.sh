#!/usr/bin/env bash
# =============================================================================
# close-delivery.sh — everything after a CONFIRMED merge, in one step.
#
#   close-delivery.sh --pr <url> [--version X.Y.Z] [--sprint <id>] KEY [KEY...]
#   close-delivery.sh --prepare [--version X.Y.Z] [--sprint <id>] KEY [KEY...]
#
# Local tracker: the items ARE files in git, and develop only changes through PRs —
# so they are closed INSIDE the PR (--prepare, before open-pr.sh) and become Done
# exactly when it merges. After the merge only the git step runs. External trackers
# (Jira / Azure DevOps / GitHub) are closed after the merge; --prepare is a no-op.
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

PR=""; VERSION=""; SPRINT=""; KEYS=(); PREPARE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prepare) PREPARE=1; shift ;;
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
LOCAL=0; [ "$($T type 2>/dev/null)" = "local" ] && LOCAL=1

if [ "$PREPARE" = 1 ] && [ "$LOCAL" = 0 ]; then
  echo "ℹ️  $($T type) tracker — items close after the merge (close-delivery.sh --pr …)"; exit 0
fi

CLOSED=0; FAILED=0; PARENTS=""; SPRINT_STATE="-"
if [ "$PREPARE" = 0 ] && [ "$LOCAL" = 1 ]; then
  SKIP_TRACKER=1   # closed inside the PR (--prepare); nothing to change on develop
else
  SKIP_TRACKER=0
fi
[ "$SKIP_TRACKER" = 1 ] && KEYS_TO_CLOSE=() || KEYS_TO_CLOSE=("${KEYS[@]}")
for K in ${KEYS_TO_CLOSE[@]+"${KEYS_TO_CLOSE[@]}"}; do
  if [ "$PREPARE" = 1 ]; then $T comment "$K" "✅ Delivered in v${VERSION:-?} — Done when its PR merges into $BASE [$NOW]" 2>/dev/null || true
  else $T comment "$K" "✅ Merged into $BASE${VERSION:+ as v$VERSION} [$NOW] · PR: ${PR:-n/a}" 2>/dev/null || true; fi
  if $T close "$K" 2>/dev/null; then CLOSED=$((CLOSED + 1)); else FAILED=$((FAILED + 1)); echo "⚠️  could not close $K" >&2; fi
  P=$($T show "$K" 2>/dev/null | sed -n 's/^Parent:[[:space:]]*//p' | head -1)
  case "$P" in ""|-) ;; *) case " $PARENTS " in *" $P "*) ;; *) PARENTS="$PARENTS $P" ;; esac ;; esac
done

for P in $PARENTS; do $T close-parent "$P" 2>&1 | sed 's/^/  /' >&2 || true; done

if [ -n "$SPRINT" ] && [ "$SKIP_TRACKER" = 0 ]; then
  SPRINT_STATE=$($T sprint close "$SPRINT" 2>/dev/null); RC=$?
  case "$RC:$SPRINT_STATE" in
    0:*)       SPRINT_STATE="closed" ;;
    4:open:*)  SPRINT_STATE="open (${SPRINT_STATE#open:} item(s) still in progress)" ;;
    *)         SPRINT_STATE="not closed (tracker error)" ;;
  esac
fi

if [ "$PREPARE" = 1 ]; then
  git -C "$DP_ROOT" add docs/tasks docs/sprints 2>/dev/null || true
  echo "🏁 Prepared $CLOSED item(s) as Done in this PR · sprint: $SPRINT_STATE — commit with the PR; they close when it merges"
  [ "$FAILED" -eq 0 ]; exit $?
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

[ "$SKIP_TRACKER" = 1 ] && echo "ℹ️  local tracker: items were closed inside the merged PR"
echo "🏁 Closed $CLOSED item(s)${FAILED:+$( [ "$FAILED" -gt 0 ] && echo " · $FAILED failed")} · parents checked:${PARENTS:- none} · sprint: $SPRINT_STATE · now on $(git branch --show-current 2>/dev/null)"
[ "$FAILED" -eq 0 ]
