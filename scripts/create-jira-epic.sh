#!/bin/bash
# Usage: ./scripts/create-jira-epic.sh "Epic summary" "Epic description" PARENT-EPIC-KEY
# Creates a Task linked as child of an Epic. If PARENT_EPIC_KEY is empty, creates the Epic itself.
set -e

# Tracker abstraction: when tracker.type is not "jira", delegate to track.sh.
if [ -z "${DEVPILOT_TRACKER_DIRECT:-}" ]; then
  _ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  _TRK=$(grep -A 3 '^tracker:' "$_ROOT/project.config.md" 2>/dev/null | grep -E '^[[:space:]]*type:' | head -1 | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  if [ -n "${_TRK:-}" ] && [ "$_TRK" != "jira" ]; then
    exec bash "$_ROOT/scripts/track.sh" new-epic "$@"
  fi
fi

source "$(dirname "$0")/../.devpilot/config.sh"

SUMMARY="$1"
DESCRIPTION="$2"
PARENT_EPIC_KEY="$3"

if [ -z "$SUMMARY" ]; then
  echo "Usage: $0 \"Summary\" \"Description\" [PARENT-EPIC-KEY]" >&2
  exit 1
fi

if [ -z "$PARENT_EPIC_KEY" ]; then
  # Create the Epic itself
  BODY=$(jq -n \
    --arg project "$JIRA_PROJECT_KEY" \
    --arg summary "$SUMMARY" \
    --arg desc "$DESCRIPTION" \
    '{
      fields: {
        project: { key: $project },
        summary: $summary,
        description: {
          type: "doc",
          version: 1,
          content: [{ type: "paragraph", content: [{ type: "text", text: $desc }] }]
        },
        issuetype: { name: "Epic" }
      }
    }')
else
  # Create a Task as child of the Epic
  BODY=$(jq -n \
    --arg project "$JIRA_PROJECT_KEY" \
    --arg summary "$SUMMARY" \
    --arg desc "$DESCRIPTION" \
    --arg parent "$PARENT_EPIC_KEY" \
    '{
      fields: {
        project: { key: $project },
        summary: $summary,
        description: {
          type: "doc",
          version: 1,
          content: [{ type: "paragraph", content: [{ type: "text", text: $desc }] }]
        },
        issuetype: { name: "Task" },
        parent: { key: $parent }
      }
    }')
fi

RESPONSE=$(curl -s --request POST \
  --url "$JIRA_BASE_URL/rest/api/3/issue" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "$BODY")

KEY=$(echo "$RESPONSE" | jq -r '.key')

if [ "$KEY" = "null" ] || [ -z "$KEY" ]; then
  echo "Failed to create issue: $(echo "$RESPONSE" | jq .)" >&2
  exit 1
fi

echo "$KEY"
