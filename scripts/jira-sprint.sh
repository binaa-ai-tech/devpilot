#!/bin/bash
# jira-sprint.sh — sprint tooling for /dp-sprint and /dp-build.
#
# Auto-detects how "sprints" can be modeled in this Jira project:
#   - If a Scrum board exists → use real Jira Sprints (Agile API).
#   - Otherwise → model each sprint as a Fix Version (works on any project type).
#
# Subcommands:
#   mode                         → prints "scrum" or "version" (which model is active)
#   create  <name>               → create a sprint; prints its id (sprint id or version name)
#   assign  <sprint-id> <KEY...> → add issues to the sprint
#   active                       → prints the current active sprint id (empty if none)
#   list                         → list current sprints/versions
#
# Usage: bash scripts/jira-sprint.sh <subcommand> [args...]
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=/dev/null
source "$ROOT/.devpilot/config.sh"

AUTH="$JIRA_EMAIL:$JIRA_API_TOKEN"
API="$JIRA_BASE_URL/rest/api/3"
AGILE="$JIRA_BASE_URL/rest/agile/1.0"

_get()  { curl -s --user "$AUTH" --header "Accept: application/json" "$@"; }
_post() { curl -s --user "$AUTH" --header "Accept: application/json" --header "Content-Type: application/json" --request POST "$@"; }

# Find the first Scrum board for this project (empty if none / no agile access).
_board_id() {
  _get --url "$AGILE/board?projectKeyOrId=$JIRA_PROJECT_KEY&type=scrum" \
    | jq -r '.values[0].id // empty' 2>/dev/null || true
}

# Active model: scrum if a board exists, else version.
_mode() {
  local b; b="$(_board_id)"
  [ -n "$b" ] && echo "scrum" || echo "version"
}

cmd="${1:-mode}"; shift || true

case "$cmd" in
  mode)
    _mode
    ;;

  create)
    NAME="${1:?Usage: jira-sprint.sh create <name>}"
    if [ "$(_mode)" = "scrum" ]; then
      BOARD="$(_board_id)"
      RESP="$(_post --url "$AGILE/sprint" \
        --data "$(jq -n --arg name "$NAME" --argjson board "$BOARD" \
          '{name:$name, originBoardId:$board}')")"
      ID="$(echo "$RESP" | jq -r '.id // empty')"
      [ -z "$ID" ] && { echo "❌ Sprint create failed: $(echo "$RESP" | jq -c '.errorMessages // .')" >&2; exit 1; }
      echo "$ID"
    else
      RESP="$(_post --url "$API/version" \
        --data "$(jq -n --arg name "$NAME" --arg project "$JIRA_PROJECT_KEY" \
          '{name:$name, project:$project, released:false}')")"
      ID="$(echo "$RESP" | jq -r '.name // empty')"
      [ -z "$ID" ] && { echo "❌ Version create failed: $(echo "$RESP" | jq -c '.errors // .')" >&2; exit 1; }
      echo "$ID"
    fi
    ;;

  assign)
    SPRINT="${1:?Usage: jira-sprint.sh assign <sprint-id> <KEY...>}"; shift
    [ "$#" -gt 0 ] || { echo "❌ No issue keys given" >&2; exit 1; }
    if [ "$(_mode)" = "scrum" ]; then
      KEYS_JSON="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
      _post --url "$AGILE/sprint/$SPRINT/issue" \
        --data "$(jq -n --argjson issues "$KEYS_JSON" '{issues:$issues}')" >/dev/null
    else
      for KEY in "$@"; do
        curl -s --user "$AUTH" --header "Content-Type: application/json" --request PUT \
          --url "$API/issue/$KEY" \
          --data "$(jq -n --arg v "$SPRINT" '{update:{fixVersions:[{add:{name:$v}}]}}')" >/dev/null
      done
    fi
    echo "✅ Assigned $* → $SPRINT"
    ;;

  active)
    # The sprint a bug/quick fix should join instead of spawning a new one.
    # scrum  → the board's active sprint (most recent if several).
    # version→ the oldest unreleased Fix Version (the one in flight).
    if [ "$(_mode)" = "scrum" ]; then
      BOARD="$(_board_id)"
      _get --url "$AGILE/board/$BOARD/sprint?state=active" \
        | jq -r '.values | sort_by(.id) | last | .id // empty' 2>/dev/null || true
    else
      _get --url "$API/project/$JIRA_PROJECT_KEY/versions" \
        | jq -r '[.[] | select(.released==false)] | first | .name // empty' 2>/dev/null || true
    fi
    ;;

  list)
    if [ "$(_mode)" = "scrum" ]; then
      BOARD="$(_board_id)"
      _get --url "$AGILE/board/$BOARD/sprint?state=active,future" \
        | jq -r '.values[] | "\(.id)\t\(.state)\t\(.name)"'
    else
      _get --url "$API/project/$JIRA_PROJECT_KEY/versions" \
        | jq -r '.[] | select(.released==false) | "\(.name)\t\(if .released then "released" else "unreleased" end)"'
    fi
    ;;

  *)
    echo "Usage: jira-sprint.sh {mode|create <name>|assign <sprint-id> <KEY...>|active|list}" >&2
    exit 1
    ;;
esac
