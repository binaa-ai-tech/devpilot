#!/bin/bash
# Usage: ./scripts/add-jira-comment.sh KEY-5 "comment text"
set -e

# Verify DEVPILOT_CONFIG_UPDATED_AT against current context to ensure fresh credentials
if [ -f "$(dirname "$0")/../.devpilot/config.sh" ]; then
  DISK_UPDATED_AT=$(grep 'DEVPILOT_CONFIG_UPDATED_AT=' "$(dirname "$0")/../.devpilot/config.sh" | head -1 | cut -d"'" -f2 || echo "")
  if [ -n "${DEVPILOT_CONFIG_UPDATED_AT:-}" ] && [ "$DISK_UPDATED_AT" != "$DEVPILOT_CONFIG_UPDATED_AT" ]; then
    echo "🔄 Config update detected (disk: $DISK_UPDATED_AT, context: $DEVPILOT_CONFIG_UPDATED_AT). Refreshing..." >&2
  fi
fi

source "$(dirname "$0")/../.devpilot/config.sh"

KEY="$1"
COMMENT="$2"

if [ -z "$KEY" ] || [ -z "$COMMENT" ]; then
  echo "Usage: $0 <TICKET-KEY> \"comment text\""
  exit 1
fi

BODY=$(jq -n --arg comment "$COMMENT" '{
  body: {
    type: "doc",
    version: 1,
    content: [{ type: "paragraph", content: [{ type: "text", text: $comment }] }]
  }
}')

curl -s --request POST \
  --url "$JIRA_BASE_URL/rest/api/3/issue/$KEY/comment" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "$BODY" > /dev/null

echo "Comment added to $KEY"
