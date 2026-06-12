#!/bin/bash
# Usage: ./scripts/create-jira-ticket.sh "Summary" "Description" "Task|Epic|Bug" "label1,label2"
# Issue types: Task, Epic (no Story in Jira Cloud simple projects), Bug.
# Bug fallback: if the project has no "Bug" issue type, the ticket is created as
# a Task carrying a "bug" label so it stays filterable on any project type.
set -e

# Tracker abstraction: when tracker.type is not "jira", delegate to track.sh.
if [ -z "${DEVPILOT_TRACKER_DIRECT:-}" ]; then
  _ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  _TRK=$(grep -A 3 '^tracker:' "$_ROOT/project.config.md" 2>/dev/null | grep -E '^[[:space:]]*type:' | head -1 | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  if [ -n "${_TRK:-}" ] && [ "$_TRK" != "jira" ]; then
    exec bash "$_ROOT/scripts/track.sh" new-ticket "$@"
  fi
fi

source "$(dirname "$0")/../.devpilot/config.sh"

SUMMARY="$1"
DESCRIPTION="$2"
ISSUE_TYPE="${3:-Task}"
LABELS="${4:-}"   # comma-separated, optional

if [ -z "$SUMMARY" ]; then
  echo "Usage: $0 \"Summary\" \"Description\" \"Task|Epic|Bug\" \"label1,label2\""
  exit 1
fi

# Build the request body for a given issue type + label set. Labels are a
# comma-separated string → JSON array; empty string → no labels field.
build_body() {
  local itype="$1" labels="$2"
  jq -n \
    --arg project "$JIRA_PROJECT_KEY" \
    --arg summary "$SUMMARY" \
    --arg desc "$DESCRIPTION" \
    --arg issuetype "$itype" \
    --arg labels "$labels" \
    '{
      fields: ({
        project: { key: $project },
        summary: $summary,
        description: {
          type: "doc",
          version: 1,
          content: [{ type: "paragraph", content: [{ type: "text", text: $desc }] }]
        },
        issuetype: { name: $issuetype }
      } + (if ($labels | length) > 0
           then { labels: ($labels | split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))) }
           else {} end))
    }'
}

post_issue() {
  curl -s --request POST \
    --url "$JIRA_BASE_URL/rest/api/3/issue" \
    --user "$JIRA_EMAIL:$JIRA_API_TOKEN" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data "$1"
}

RESPONSE=$(post_issue "$(build_body "$ISSUE_TYPE" "$LABELS")")
KEY=$(echo "$RESPONSE" | jq -r '.key')

# Fallback: a project without a "Bug" issue type rejects it (error on .issuetype).
# Retry as a Task carrying a "bug" label so the defect stays filterable anywhere.
if { [ "$KEY" = "null" ] || [ -z "$KEY" ]; } && [ "$ISSUE_TYPE" = "Bug" ]; then
  if echo "$RESPONSE" | jq -e '.errors.issuetype // empty' >/dev/null 2>&1; then
    echo "ℹ️  Project has no 'Bug' issue type — creating as Task + 'bug' label." >&2
    FB_LABELS="bug"
    [ -n "$LABELS" ] && FB_LABELS="bug,$LABELS"
    RESPONSE=$(post_issue "$(build_body "Task" "$FB_LABELS")")
    KEY=$(echo "$RESPONSE" | jq -r '.key')
  fi
fi

if [ "$KEY" = "null" ] || [ -z "$KEY" ]; then
  echo "Failed to create ticket: $(echo "$RESPONSE" | jq .)" >&2
  exit 1
fi

echo "$KEY"
