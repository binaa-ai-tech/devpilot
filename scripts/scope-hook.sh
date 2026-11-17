#!/usr/bin/env bash
# =============================================================================
# scope-hook.sh — PreToolUse hook that enforces two locks in real time.
#
# 1. Rules guard — while /dp-build or /dp-deliver is building (scripts/rules-guard.sh lock),
#    edits to the checks that judge the change (skills, rules, gate scripts, CI workflows,
#    CLAUDE.md) are BLOCKED, unless the Story explicitly targets DevPilot tooling.
# 2. Layer lock — opt-in: write a layer (frontend | backend | db) to .devpilot/.scope-lock to
#    confine edits to that layer (e.g. while one agent works alone).
# This hook reads the Edit/Write target from the tool input on stdin. With neither lock
# present, everything is allowed.
#
# Wire it in .claude/settings.json:
#   "PreToolUse": [ { "matcher": "Edit|Write|MultiEdit",
#     "hooks": [ { "type": "command", "command": "bash scripts/scope-hook.sh" } ] } ]
# Exit 0 = allow · exit 2 = block (reason on stderr).
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOCK="$ROOT/.devpilot/.scope-lock"
RULES_LOCK="$ROOT/.devpilot/.rules-lock"
[ -f "$LOCK" ] || [ -f "$RULES_LOCK" ] || exit 0   # no active lock → allow

INPUT=$(cat)
# Extract the file path from the tool input (jq if available, else grep).
if command -v jq >/dev/null 2>&1; then
  FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
else
  FP=$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')
fi
[ -z "$FP" ] && exit 0                        # nothing to check
case "$FP" in "$ROOT"/*) FP="${FP#"$ROOT"/}" ;; esac   # hooks receive absolute paths

# Rules guard first: skills and rules are .md files, so this runs before the docs exemption.
if [ -f "$RULES_LOCK" ] && [ -f "$ROOT/scripts/rules-guard.sh" ]; then
  bash "$ROOT/scripts/rules-guard.sh" guard "$FP" || exit 2
fi

[ -f "$LOCK" ] || exit 0
LAYER=$(head -1 "$LOCK" | tr -d '[:space:]')
[ -z "$LAYER" ] && exit 0

case "$FP" in docs/*|*.md) exit 0 ;; esac     # docs always allowed

violation=0
case "$LAYER" in
  frontend) echo "$FP" | grep -Eq '\.(cs|sql)$|/[Mm]igrations/' && violation=1 ;;
  backend)  echo "$FP" | grep -Eq '\.(html|scss|css)$|\.component\.ts$' && violation=1 ;;   # team-dotnet owns EF migrations
  db)       echo "$FP" | grep -Eqv '/[Mm]igrations/|\.sql$' && violation=1 ;;
  security) violation=0 ;;
esac

if [ "$violation" = 1 ]; then
  echo "scope-hook: '$FP' is outside the active '$LAYER' layer lock — blocked. Remove .devpilot/.scope-lock to override." >&2
  exit 2
fi
exit 0
