#!/bin/bash
# Usage: ./scripts/update-jira-status.sh KEY-5 "In Progress"
set -e

# Tracker abstraction: when tracker.type is not "jira", delegate to track.sh.
if [ -z "${DEVPILOT_TRACKER_DIRECT:-}" ]; then
  _ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  _TRK=$(grep -A 3 '^tracker:' "$_ROOT/project.config.md" 2>/dev/null | grep -E '^[[:space:]]*type:' | head -1 | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  if [ -n "${_TRK:-}" ] && [ "$_TRK" != "jira" ]; then
    exec bash "$_ROOT/scripts/track.sh" status "$@"
  fi
fi

source "$(dirname "$0")/../.devpilot/config.sh"

KEY="$1"
STATUS="$2"

if [ -z "$KEY" ] || [ -z "$STATUS" ]; then
  echo "Usage: $0 <TICKET-KEY> \"In Progress|Done|To Do\""
  exit 1
fi

# Get transition ID for the requested status
TRANSITIONS=$(curl -s --request GET \
  --url "$JIRA_BASE_URL/rest/api/3/issue/$KEY/transitions" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json")

TRANSITION_ID=$(echo "$TRANSITIONS" | jq -r --arg STATUS "$STATUS" \
  '.transitions[] | select(.name == $STATUS) | .id')

if [ -z "$TRANSITION_ID" ] || [ "$TRANSITION_ID" = "null" ]; then
  echo "Status '$STATUS' not found for $KEY. Available:"
  echo "$TRANSITIONS" | jq '[.transitions[] | .name]'
  exit 1
fi

curl -s --request POST \
  --url "$JIRA_BASE_URL/rest/api/3/issue/$KEY/transitions" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{\"transition\": {\"id\": \"$TRANSITION_ID\"}}" > /dev/null

echo "$KEY → $STATUS"
