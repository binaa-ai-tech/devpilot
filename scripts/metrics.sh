#!/usr/bin/env bash
# =============================================================================
# metrics.sh — throughput and cost per delivery.
#
#   bash scripts/metrics.sh            tasks + token usage per work item
#   bash scripts/metrics.sh usage      only the usage table
#
# Tasks come from docs/tasks/. Token usage comes from .devpilot/logs/usage/*.json,
# written by the Claude Code hook scripts/usage-hook.sh (Stop / SessionEnd), per
# session and attributed to the branch's work item. Cost appears when
# project.config.md → pricing has "input/output" USD per million tokens for a model
# (cache reads at 10% of input, cache writes at 125% — approximate).
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DIR="$ROOT/docs/tasks"
USAGE="$ROOT/.devpilot/logs/usage"
MODE="${1:-all}"

field() { grep -E "^$2:" "$1" 2>/dev/null | head -1 | sed "s/^$2:[[:space:]]*//" | tr -d '"'; }

tasks() {
  shopt -s nullglob
  local files=() f total=0 inprog=0 done_n=0 cmds="" st
  for f in "$DIR"/*.md; do
    case "$(basename "$f")" in *-checkpoint.md|*-brief.md|*-scope.md|*-pr.md) continue ;; esac
    files+=("$f")
  done
  echo "── devpilot metrics ──────────────────────────────────"
  if [ ${#files[@]} -eq 0 ]; then echo "  No tasks recorded yet."; return 0; fi
  for f in "${files[@]}"; do
    total=$((total + 1))
    st=$(field "$f" status); [ -z "$st" ] && st=$(sed -n 's/^- Status:[[:space:]]*//p' "$f" | head -1)
    case "$st" in in-progress|"In Progress") inprog=$((inprog + 1)) ;; done|Done) done_n=$((done_n + 1)) ;; esac
    cmds="$cmds$(field "$f" command)"$'\n'
  done
  echo "  Work items       : $total"
  echo "  In progress      : $inprog"
  echo "  Done             : $done_n"
  if printf '%s' "$cmds" | grep -q .; then
    echo "  By command:"
    printf '%s' "$cmds" | grep -v '^$' | sort | uniq -c | sort -rn | sed 's/^/    /'
  fi
}

price_of() {  # price_of <model> → "in out" (USD / MTok) or empty
  awk -v m="$1" '
    /^pricing:/ { f = 1; next }
    f && /^[^[:space:]#]/ { f = 0 }
    f { line = $0; sub(/#.*/, "", line); gsub(/["[:space:]]/, "", line)
        split(line, kv, ":"); if (kv[1] == m && kv[2] ~ /\//) { split(kv[2], p, "/"); print p[1], p[2]; exit } }
  ' "$ROOT/project.config.md" 2>/dev/null
}

usage() {
  echo ""
  echo "── token usage per work item ─────────────────────────"
  shopt -s nullglob
  local files=("$USAGE"/*.json)
  if [ ${#files[@]} -eq 0 ] || ! command -v jq >/dev/null 2>&1; then
    echo "  No usage yet — recorded by the Claude Code hook scripts/usage-hook.sh (.claude/settings.json)."
    return 0
  fi
  local rows priced=0
  rows=$(jq -rs '[.[] | .key as $k | .models[] | . + {key: $k}]
    | group_by(.key + "|" + .model)
    | map({key: .[0].key, model: .[0].model, sessions: length,
           input: (map(.input) | add), output: (map(.output) | add),
           cache_read: (map(.cache_read) | add), cache_write: (map(.cache_write) | add)})
    | sort_by(.key)[] | [.key, .model, .input, .output, .cache_read, .cache_write] | @tsv' "${files[@]}")
  printf '  %-14s %-28s %12s %10s %12s %11s %9s\n' KEY MODEL INPUT OUTPUT CACHE-READ CACHE-WRITE COST
  while IFS="$(printf '\t')" read -r k m i o cr cw; do
    [ -z "$k" ] && continue
    local p cost="—"
    p=$(price_of "$m")
    if [ -n "$p" ]; then
      cost=$(awk -v i="$i" -v o="$o" -v cr="$cr" -v cw="$cw" -v pp="$p" 'BEGIN { split(pp, x, " ");
        printf "$%.2f", (i * x[1] + o * x[2] + cr * x[1] * 0.10 + cw * x[1] * 1.25) / 1000000 }')
      priced=1
    fi
    printf '  %-14s %-28s %12s %10s %12s %11s %9s\n' "$k" "$m" "$i" "$o" "$cr" "$cw" "$cost"
  done <<< "$rows"
  [ "$priced" = 0 ] && echo "  (cost: add prices to project.config.md → pricing, e.g.  claude-sonnet-5: \"<in>/<out>\")"
}

case "$MODE" in
  usage) usage ;;
  *)     tasks; usage ;;
esac
echo "──────────────────────────────────────────────────────"
