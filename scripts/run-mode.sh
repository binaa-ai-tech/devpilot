#!/usr/bin/env bash
# =============================================================================
# run-mode.sh — resolve the /ceo engine-mode flag from a task string.
#
# Modes (pick the model FAMILY; the model itself is chosen per-task by
# resolve-engine.sh, balancing power vs token):
#   --claude   | -c   → all phases + all coding on Claude models
#   --opencode | -o   → Claude orchestrates; opencode (GitHub Copilot) writes code
#
# Usage (inside a command file):
#   eval "$(bash scripts/run-mode.sh "$ARGUMENTS")"
#   # now $RUN_MODE (claude|opencode) and $TASK (flag stripped) are set
#
# No flag → falls back to engines.coding in project.config.md, then "claude".
# =============================================================================
set -uo pipefail

RAW="${*:-}"
MODE=""

# Strip a single leading mode flag (long or short form).
case "$RAW" in
  --claude|--claude\ *)     MODE="claude";   RAW="${RAW#--claude}"   ;;
  --opencode|--opencode\ *) MODE="opencode"; RAW="${RAW#--opencode}" ;;
  -c|-c\ *)                 MODE="claude";   RAW="${RAW#-c}"         ;;
  -o|-o\ *)                 MODE="opencode"; RAW="${RAW#-o}"         ;;
esac

# Trim leading whitespace from the remaining task text.
RAW="${RAW#"${RAW%%[![:space:]]*}"}"

# No flag → fall back to the project's configured coding engine.
if [ -z "$MODE" ]; then
  if [ -f project.config.md ]; then
    MODE=$(grep -A 8 '^engines:' project.config.md 2>/dev/null \
      | grep -E '^[[:space:]]*coding:' | head -1 \
      | sed 's/.*coding:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  fi
  [ -z "${MODE:-}" ] && MODE="claude"
fi

# Normalise anything unexpected to a safe default.
case "$MODE" in
  claude|opencode|antigravity) ;;   # antigravity = allowed single-engine value from config
  *) MODE="claude" ;;
esac

printf 'RUN_MODE=%q\n' "$MODE"
printf 'TASK=%q\n'     "$RAW"
