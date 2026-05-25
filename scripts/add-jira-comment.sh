#!/bin/bash
# Usage: ./scripts/add-jira-comment.sh KEY-5 "comment text"
set -e

source "$(dirname "$0")/../.devpilot/config.sh"

KEY="$1"
COMMENT="$2"

if [ -z "$KEY" ] || [ -z "$COMMENT" ]; then
  echo "Usage: $0 <TICKET-KEY> \"comment text\""
  exit 1
fi

curl -s --request POST \
  --url "$JIRA_BASE_URL/rest/api/3/issue/$KEY/comment" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "{
    \"body\": {
      \"type\": \"doc\",
      \"version\": 1,
      \"content\": [{
        \"type\": \"paragraph\",
        \"content\": [{ \"type\": \"text\", \"text\": \"$COMMENT\" }]
      }]
    }
  }" > /dev/null

echo "Comment added to $KEY"
