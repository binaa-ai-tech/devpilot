#!/usr/bin/env bash
# =============================================================================
# metrics.sh — summarize devpilot task history from docs/tasks/.
#
# Makes the token/throughput work measurable: how many tasks, by command,
# how many merged, and recent activity.
#
#   bash scripts/metrics.sh
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DIR="$ROOT/docs/tasks"
[ -d "$DIR" ] || { echo "No tasks recorded yet."; exit 0; }

field() { grep -E "^$2:" "$1" 2>/dev/null | head -1 | sed "s/^$2:[[:space:]]*//" | tr -d '"'; }

total=0; done_n=0; inprog=0
declare_cmds=""
shopt -s nullglob
files=("$DIR"/*.md)
[ ${#files[@]} -eq 0 ] && { echo "No tasks recorded yet."; exit 0; }
for f in "${files[@]}"; do
  case "$(basename "$f")" in *-checkpoint.md) continue;; esac
  total=$((total + 1))
  st=$(field "$f" status)
  [ "$st" = "in-progress" ] && inprog=$((inprog + 1))
  cmd=$(field "$f" command); cmd="${cmd:-unknown}"
  declare_cmds="$declare_cmds$cmd"$'\n'
done

# Merged tasks: result section / Done markers in the log body
done_n=$(grep -lsE 'merged into|→ Done|status: done' "$DIR"/*.md 2>/dev/null | grep -v checkpoint | wc -l | tr -d ' ')

echo "── devpilot metrics ──────────────────────────────────"
echo "  Total tasks      : $total"
echo "  In progress      : $inprog"
echo "  Merged / done    : ${done_n:-0}"
echo ""
echo "  By command:"
printf '%s' "$declare_cmds" | grep -v '^$' | sort | uniq -c | sort -rn | sed 's/^/    /'
echo ""
echo "  Recent (newest 5):"
for f in $(ls -t "${files[@]}" | grep -v checkpoint | head -5); do
  echo "    $(field "$f" key)  ·  $(field "$f" command)  ·  $(field "$f" status)"
done
echo "──────────────────────────────────────────────────────"
