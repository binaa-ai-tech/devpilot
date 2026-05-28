#!/usr/bin/env bash
# =============================================================================
# scope-hook.sh — PreToolUse hook that enforces an active layer lock in real time.
#
# When /ceo-subdomain (or /ceo-issue) is running layer-locked, it writes the
# active layer to .devpilot/.scope-lock. This hook reads the Edit/Write target
# from the tool input on stdin and BLOCKS the write if it falls outside the
# locked layer. With no lock file present, everything is allowed.
#
# Wire it in .claude/settings.json:
#   "PreToolUse": [ { "matcher": "Edit|Write|MultiEdit",
#     "hooks": [ { "type": "command", "command": "bash scripts/scope-hook.sh" } ] } ]
# Exit 0 = allow · exit 2 = block (reason on stderr).
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOCK="$ROOT/.devpilot/.scope-lock"
[ -f "$LOCK" ] || exit 0                      # no active lock → allow

LAYER=$(head -1 "$LOCK" | tr -d '[:space:]')
[ -z "$LAYER" ] && exit 0

INPUT=$(cat)
# Extract the file path from the tool input (jq if available, else grep).
if command -v jq >/dev/null 2>&1; then
  FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
else
  FP=$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')
fi
[ -z "$FP" ] && exit 0                        # nothing to check

case "$FP" in docs/*|*.md) exit 0 ;; esac     # docs always allowed

violation=0
case "$LAYER" in
  frontend) echo "$FP" | grep -Eq '\.(cs|sql)$|/[Mm]igrations/' && violation=1 ;;
  backend)  echo "$FP" | grep -Eq '\.(html|scss|css|vue)$|\.component\.ts$|/[Mm]igrations/' && violation=1 ;;
  db)       echo "$FP" | grep -Eqv '/[Mm]igrations/|\.sql$' && violation=1 ;;
  security) violation=0 ;;
esac

if [ "$violation" = 1 ]; then
  echo "scope-hook: '$FP' is outside the active '$LAYER' layer lock — blocked. Remove .devpilot/.scope-lock to override." >&2
  exit 2
fi
exit 0
