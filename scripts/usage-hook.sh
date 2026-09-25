#!/usr/bin/env bash
# =============================================================================
# usage-hook.sh — Claude Code Stop/SessionEnd hook: token usage per delivery.
#
# Reads the session transcript (+ subagent transcripts), counts every assistant
# message once (the transcript repeats a message per content block), and writes
#   .devpilot/logs/usage/<session>.json  {key, branch, models: [{model, messages,
#                                         input, output, cache_read, cache_write}]}
# The work item key comes from the branch (feature/ado-345-… → ADO-345), else the
# latest checkpoint, else "untracked". scripts/metrics.sh aggregates the files.
# Never blocks or prints: a hook failure must not interrupt the session.
# =============================================================================
set -uo pipefail
IN=$(cat 2>/dev/null) || exit 0
command -v jq >/dev/null 2>&1 || exit 0
TP=$(printf '%s' "$IN" | jq -r '.transcript_path // empty' 2>/dev/null)
SID=$(printf '%s' "$IN" | jq -r '.session_id // empty' 2>/dev/null)
EVT=$(printf '%s' "$IN" | jq -r '.hook_event_name // "Stop"' 2>/dev/null)
CWD=$(printf '%s' "$IN" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$TP" ] && [ -f "$TP" ] && [ -n "$SID" ] || exit 0
if [ -n "$CWD" ]; then cd "$CWD" 2>/dev/null || exit 0; fi
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUTD="$ROOT/.devpilot/logs/usage"; OUT="$OUTD/$SID.json"
mkdir -p "$OUTD" 2>/dev/null || exit 0

# Stop fires after every turn — recompute at most every 2 minutes (always on SessionEnd).
if [ "$EVT" != "SessionEnd" ] && [ -f "$OUT" ] && [ -z "$(find "$OUT" -mmin +2 2>/dev/null)" ]; then exit 0; fi

BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null)
KEY=$(printf '%s' "$BRANCH" | sed -nE 's#^(feature|hotfix|bugfix)/([a-zA-Z][a-zA-Z0-9_]*-[0-9]+).*#\2#p' | tr '[:lower:]' '[:upper:]')
[ -z "$KEY" ] && [ -f "$ROOT/scripts/checkpoint.sh" ] && KEY=$(cd "$ROOT" && bash scripts/checkpoint.sh latest 2>/dev/null | grep -oE '[A-Z][A-Z0-9_]*-[0-9]+' | head -1)
KEY="${KEY:-untracked}"

FILES=("$TP")
for f in "${TP%.jsonl}"/subagents/*.jsonl; do [ -f "$f" ] && FILES+=("$f"); done

jq -n --arg sid "$SID" --arg key "$KEY" --arg br "$BRANCH" --arg now "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" '
  [inputs | select(.type == "assistant" and .message.usage != null and .message.id != null)]
  | group_by(.message.id) | map(last)
  | group_by(.message.model)
  | map({ model: .[0].message.model, messages: length,
          input:       (map(.message.usage.input_tokens // 0) | add),
          output:      (map(.message.usage.output_tokens // 0) | add),
          cache_read:  (map(.message.usage.cache_read_input_tokens // 0) | add),
          cache_write: (map(.message.usage.cache_creation_input_tokens // 0) | add) })
  | { session: $sid, key: $key, branch: $br, updated: $now, models: . }' "${FILES[@]}" > "$OUT.tmp" 2>/dev/null \
  && mv "$OUT.tmp" "$OUT" || rm -f "$OUT.tmp"
exit 0
