#!/bin/bash
# Usage: ./scripts/create-jira-epic.sh "Epic summary" "Epic description" PARENT-EPIC-KEY
# Creates a Task linked as child of an Epic. If PARENT_EPIC_KEY is empty, creates the Epic itself.
set -e

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
