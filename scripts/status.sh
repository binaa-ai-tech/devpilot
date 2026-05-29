#!/usr/bin/env bash
# =============================================================================
# status.sh — devpilot task dashboard.
#
# Lists tasks recorded in docs/tasks/ with their status, branch, and command,
# newest first. Surfaces anything still in progress.
#
#   bash scripts/status.sh           (all tasks)
#   bash scripts/status.sh open      (only in-progress)
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DIR="$ROOT/docs/tasks"
FILTER="${1:-all}"

[ -d "$DIR" ] || { echo "No tasks yet (docs/tasks/ is empty)."; exit 0; }

field() { grep -E "^$2:" "$1" 2>/dev/null | head -1 | sed "s/^$2:[[:space:]]*//" | tr -d '"'; }

shopt -s nullglob
files=("$DIR"/*.md)
[ ${#files[@]} -eq 0 ] && { echo "No tasks yet (docs/tasks/ is empty)."; exit 0; }

rows=0
printf '%-22s %-12s %-12s %s\n' "KEY" "STATUS" "COMMAND" "BRANCH"
printf '%-22s %-12s %-12s %s\n' "----------------------" "------------" "------------" "----------------------"
# newest first by mtime (args are guaranteed non-empty, so ls -t is safe here)
for f in $(ls -t "${files[@]}"); do
  base=$(basename "$f" .md)
  case "$base" in *-checkpoint) continue;; esac
  key=$(field "$f" key);     key="${key:-$base}"
  status=$(field "$f" status); status="${status:-—}"
  cmd=$(field "$f" command); cmd="${cmd:-—}"
  branch=$(field "$f" branch); branch="${branch:-—}"
  if [ "$FILTER" = open ] && [ "$status" != "in-progress" ]; then continue; fi
  printf '%-22s %-12s %-12s %s\n' "$key" "$status" "$cmd" "$branch"
  rows=$((rows + 1))
done

echo ""
INPROG=$(grep -ls '^status: in-progress' "$DIR"/*.md 2>/dev/null | grep -v checkpoint | wc -l | tr -d ' ')
echo "$rows task(s) shown · ${INPROG:-0} in progress"
[ "${INPROG:-0}" != "0" ] && echo "Resume an interrupted task with: /ceo resume"
exit 0
