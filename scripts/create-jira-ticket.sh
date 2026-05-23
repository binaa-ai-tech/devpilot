#!/bin/bash
# Usage: ./scripts/create-jira-ticket.sh "Summary" "Description" "Story|Bug|Task"
set -e

source "$(dirname "$0")/../.aidev/config.sh"

SUMMARY="$1"
DESCRIPTION="$2"
ISSUE_TYPE="${3:-Story}"

if [ -z "$SUMMARY" ]; then
  echo "Usage: $0 \"Summary\" \"Description\" \"Story|Bug|Task\""
  exit 1
fi

RESPONSE=$(curl -s --request POST \
  --url "$JIRA_BASE_URL/rest/api/3/issue" \
  --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "{
    \"fields\": {
      \"project\": { \"key\": \"$JIRA_PROJECT_KEY\" },
      \"summary\": \"$SUMMARY\",
      \"description\": {
        \"type\": \"doc\",
        \"version\": 1,
        \"content\": [{
          \"type\": \"paragraph\",
          \"content\": [{ \"type\": \"text\", \"text\": \"$DESCRIPTION\" }]
        }]
      },
      \"issuetype\": { \"name\": \"$ISSUE_TYPE\" }
    }
  }")

KEY=$(echo "$RESPONSE" | jq -r '.key')

if [ "$KEY" = "null" ] || [ -z "$KEY" ]; then
  echo "Failed to create ticket:"
  echo "$RESPONSE" | jq .
  exit 1
fi

echo "$KEY"
echo "Created: $JIRA_BASE_URL/browse/$KEY"
