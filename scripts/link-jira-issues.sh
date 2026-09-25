#!/bin/bash
# link-jira-issues.sh — create a reversible link between two Jira issues.
# Used by /dp-plan's merge mechanics (DUPLICATE / FOLD-IN) so nothing is ever
# silently deleted — merges are auditable and undoable.
#
# Usage: bash scripts/link-jira-issues.sh <FROM-KEY> <type> <TO-KEY>
#   type: "Duplicate" | "Relates"  (Jira's standard link type names)
#   For Duplicate: FROM "duplicates" TO.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=/dev/null
source "$ROOT/.devpilot/config.sh"

FROM="${1:?Usage: link-jira-issues.sh <FROM-KEY> <Duplicate|Relates> <TO-KEY>}"
TYPE="${2:?type required: Duplicate|Relates}"
TO="${3:?TO-KEY required}"

RESP="$(curl -s --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  --header "Accept: application/json" --header "Content-Type: application/json" \
  --request POST --url "$JIRA_BASE_URL/rest/api/3/issueLink" \
  --data "$(jq -n --arg type "$TYPE" --arg from "$FROM" --arg to "$TO" \
    '{type:{name:$type}, inwardIssue:{key:$to}, outwardIssue:{key:$from}}')")"

# A successful link returns empty body (204). Any body usually means an error.
if [ -n "$RESP" ] && [ "$(echo "$RESP" | jq -r 'has("errorMessages") // false' 2>/dev/null)" = "true" ]; then
  echo "❌ Link failed: $(echo "$RESP" | jq -c '.errorMessages')" >&2
  exit 1
fi
echo "🔗 $FROM $TYPE → $TO"
