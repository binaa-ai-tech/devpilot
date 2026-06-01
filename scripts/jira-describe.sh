#!/bin/bash
# jira-describe.sh <KEY> <markdown-file>
#
# Sets a Jira issue's description from a markdown FILE, rendered as structured ADF
# (headings, lists, code) via md-to-adf.sh — so the ticket is a complete,
# self-contained implementation brief any session / opencode / AI tool can build
# from Jira alone. Use this instead of update-jira-description.sh for rich specs.
set -euo pipefail

DIR="$(dirname "$0")"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Tracker abstraction: for non-jira trackers, fall back to plain-text describe.
if [ -z "${DEVPILOT_TRACKER_DIRECT:-}" ]; then
  _TRK=$(grep -A 3 '^tracker:' "$ROOT/project.config.md" 2>/dev/null | grep -E '^[[:space:]]*type:' | head -1 | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  if [ -n "${_TRK:-}" ] && [ "$_TRK" != "jira" ]; then
    exec bash "$ROOT/scripts/track.sh" describe "$1" "$(cat "$2")"
  fi
fi

source "$DIR/../.devpilot/config.sh"

KEY="${1:?Usage: jira-describe.sh <KEY> <markdown-file>}"
FILE="${2:?markdown file required}"
[ -f "$FILE" ] || { echo "❌ File not found: $FILE" >&2; exit 1; }

ADF="$(bash "$DIR/md-to-adf.sh" "$FILE")"
BODY="$(jq -n --argjson desc "$ADF" '{ fields: { description: $desc } }')"

RESP="$(curl -s -o /dev/null -w '%{http_code}' --request PUT \
  --url "$JIRA_BASE_URL/rest/api/3/issue/$KEY" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "$BODY")"

if [ "$RESP" = "204" ] || [ "$RESP" = "200" ]; then
  echo "✅ Structured description set on $KEY (from $FILE)"
else
  echo "❌ Failed to set description on $KEY (HTTP $RESP)" >&2
  exit 1
fi
