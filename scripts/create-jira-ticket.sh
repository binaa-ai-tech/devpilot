#!/bin/bash
# Usage: ./scripts/create-jira-ticket.sh "Add OTP retry limit" "User story text" "Task"
# Issue types available: Task, Epic (no Story in Jira Cloud simple projects)
set -e

# Tracker abstraction: when tracker.type is not "jira", delegate to track.sh.
if [ -z "${DEVPILOT_TRACKER_DIRECT:-}" ]; then
  _ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  _TRK=$(grep -A 3 '^tracker:' "$_ROOT/project.config.md" 2>/dev/null | grep -E '^[[:space:]]*type:' | head -1 | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  if [ -n "${_TRK:-}" ] && [ "$_TRK" != "jira" ]; then
    exec bash "$_ROOT/scripts/track.sh" new-ticket "$@"
  fi
fi

# Verify DEVPILOT_CONFIG_UPDATED_AT against current context to ensure fresh credentials
if [ -f "$(dirname "$0")/../.devpilot/config.sh" ]; then
  DISK_UPDATED_AT=$(grep 'DEVPILOT_CONFIG_UPDATED_AT=' "$(dirname "$0")/../.devpilot/config.sh" | head -1 | cut -d"'" -f2 || echo "")
  if [ -n "${DEVPILOT_CONFIG_UPDATED_AT:-}" ] && [ "$DISK_UPDATED_AT" != "$DEVPILOT_CONFIG_UPDATED_AT" ]; then
    echo "🔄 Config update detected (disk: $DISK_UPDATED_AT, context: $DEVPILOT_CONFIG_UPDATED_AT). Refreshing..." >&2
  fi
fi

source "$(dirname "$0")/../.devpilot/config.sh"

SUMMARY="$1"
DESCRIPTION="$2"
ISSUE_TYPE="${3:-Task}"

if [ -z "$SUMMARY" ]; then
  echo "Usage: $0 \"Summary\" \"Description\" \"Task|Epic\""
  exit 1
fi

# Build JSON safely using jq to prevent injection
BODY=$(jq -n \
  --arg project "$JIRA_PROJECT_KEY" \
  --arg summary "$SUMMARY" \
  --arg desc "$DESCRIPTION" \
  --arg issuetype "$ISSUE_TYPE" \
  '{
    fields: {
      project: { key: $project },
      summary: $summary,
      description: {
        type: "doc",
        version: 1,
        content: [{ type: "paragraph", content: [{ type: "text", text: $desc }] }]
      },
      issuetype: { name: $issuetype }
    }
  }')

RESPONSE=$(curl -s --request POST \
  --url "$JIRA_BASE_URL/rest/api/3/issue" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "$BODY")

KEY=$(echo "$RESPONSE" | jq -r '.key')

if [ "$KEY" = "null" ] || [ -z "$KEY" ]; then
  echo "Failed to create ticket: $(echo "$RESPONSE" | jq .)" >&2
  exit 1
fi

echo "$KEY"
