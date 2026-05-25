#!/bin/bash
# Usage: ./scripts/update-jira-description.sh KEY-5 "Full user story and AC text"
set -e

source "$(dirname "$0")/../.devpilot/config.sh"

KEY="$1"
CONTENT="$2"

if [ -z "$KEY" ] || [ -z "$CONTENT" ]; then
  echo "Usage: $0 <TICKET-KEY> \"description text\"" >&2
  exit 1
fi

BODY=$(jq -n --arg text "$CONTENT" '{
  fields: {
    description: {
      type: "doc",
      version: 1,
      content: [{ type: "paragraph", content: [{ type: "text", text: $text }] }]
    }
  }
}')

curl -s --request PUT \
  --url "$JIRA_BASE_URL/rest/api/3/issue/$KEY" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "$BODY" > /dev/null

echo "Description updated on $KEY"
