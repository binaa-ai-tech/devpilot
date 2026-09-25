#!/usr/bin/env bash
# =============================================================================
# jira.sh — Jira Cloud backend for scripts/tracker.sh (REST v3 + Agile 1.0).
# Call it through tracker.sh; the interface is shared by every backend.
#
#   ping                                   verify credentials + project
#   new <Epic|Story|Bug|Task> <summary> <body-file|text> [parent] [labels,csv]  → KEY
#   show <KEY>                             details + child items
#   search <text>                          TSV candidates (dedup)
#   list                                   TSV of the whole project (backlog index)
#   status <KEY> <To Do|In Progress|Done>  transition by status category
#   comment <KEY> <text>
#   describe <KEY> <markdown-file|text>    rich ADF description (md-to-adf.sh)
#   link <KEY> <duplicate|relates> <KEY2>
#   url <KEY> · ref <KEY>
#   sprint-create <name> · sprint-assign <id> <KEY...> · sprint-start <id>
#   sprint-active · sprint-close <id> · sprint-list
#
# TSV rows: KEY  TYPE  STATE  CATEGORY(todo|doing|done)  PARENT  TITLE
# Sprints: real Jira Sprints when the project has a Scrum board, else Fix Versions.
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=devpilot-lib.sh
. "$DIR/devpilot-lib.sh"
dp_load_secrets

API="$JIRA_BASE_URL/rest/api/3"
AGILE="$JIRA_BASE_URL/rest/agile/1.0"
AUTH="$JIRA_EMAIL:$JIRA_API_TOKEN"

die() { echo "❌ jira: $*" >&2; exit 1; }

# _req <METHOD> <url> [json] → body on stdout; non-2xx → body on stderr, rc 1
_req() {
  local method="$1" url="$2" data="${3:-}" tmp code
  tmp=$(mktemp)
  if [ -n "$data" ]; then
    code=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 30 -X "$method" --user "$AUTH" \
      -H 'Accept: application/json' -H 'Content-Type: application/json' --data "$data" "$url" 2>/dev/null)
  else
    code=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 30 -X "$method" --user "$AUTH" \
      -H 'Accept: application/json' "$url" 2>/dev/null)
  fi
  if [ "${code:-000}" -ge 200 ] 2>/dev/null && [ "$code" -lt 300 ]; then
    cat "$tmp"; rm -f "$tmp"; return 0
  fi
  echo "jira HTTP ${code:-000} $method ${url#"$JIRA_BASE_URL"}: $(head -c 400 "$tmp")" >&2
  rm -f "$tmp"; return 1
}

_text_or_file() { if [ -f "$1" ]; then cat "$1"; else printf '%s' "$1"; fi; }
_adf() { _text_or_file "$1" | bash "$DIR/md-to-adf.sh"; }

# JQL search → TSV. Uses /search/jql (2025+) with a fallback to the legacy endpoint.
_jql_tsv() {
  local jql="$1" max="${2:-50}" body resp
  body=$(jq -n --arg jql "$jql" --argjson max "$max" \
    '{jql:$jql, maxResults:$max, fields:["summary","issuetype","status","parent"]}')
  resp=$(_req POST "$API/search/jql" "$body" 2>/dev/null) || resp=$(_req POST "$API/search" "$body") || return 1
  echo "$resp" | jq -r '.issues[]? | [ .key, (.fields.issuetype.name // "-"), (.fields.status.name // "-"),
      ({"new":"todo","indeterminate":"doing","done":"done"}[.fields.status.statusCategory.key // "new"] // "todo"),
      (.fields.parent.key // "-"), ((.fields.summary // "-") | gsub("[\t\n]"; " ")) ] | @tsv'
}

_board_id() {
  _req GET "$AGILE/board?projectKeyOrId=$JIRA_PROJECT_KEY&type=scrum" 2>/dev/null \
    | jq -r '.values[0].id // empty' 2>/dev/null
}

_version_id() {
  _req GET "$API/project/$JIRA_PROJECT_KEY/versions" \
    | jq -r --arg n "$1" '.[] | select(.name == $n) | .id' | head -1
}

cmd="${1:-}"; shift || true
case "$cmd" in
  ping)
    _req GET "$API/myself" >/dev/null || die "cannot authenticate to $JIRA_BASE_URL (check JIRA_EMAIL / JIRA_API_TOKEN)"
    _req GET "$API/project/$JIRA_PROJECT_KEY" >/dev/null || die "project '$JIRA_PROJECT_KEY' not found or not visible"
    echo "✅ Jira reachable — project $JIRA_PROJECT_KEY"
    ;;

  new)
    TYPE="${1:?type}"; SUMMARY="${2:?summary}"; BODY="${3:-}"; PARENT="${4:-}"; LABELS="${5:-}"
    ADF=$(_adf "${BODY:- }")
    mk() {  # mk <issuetype> <labels>
      jq -n --arg p "$JIRA_PROJECT_KEY" --arg s "$SUMMARY" --arg t "$1" --arg l "$2" \
            --arg parent "$PARENT" --argjson d "$ADF" '
        { fields: ({ project:{key:$p}, summary:$s, description:$d, issuetype:{name:$t} }
          + (if $parent != "" then {parent:{key:$parent}} else {} end)
          + (if $l != "" then {labels:($l|split(",")|map(gsub("^\\s+|\\s+$";""))|map(select(length>0)))} else {} end)) }'
    }
    # Preferred type first; fall back to Task (+ a label) on projects without it.
    case "$TYPE" in
      Story) TRY="Story Task" ;;
      Bug)   TRY="Bug Task" ;;
      Epic)  TRY="Epic" ;;
      *)     TRY="Task" ;;
    esac
    KEY=""
    for T in $TRY; do
      L="$LABELS"
      [ "$T" != "$TYPE" ] && L=$(printf '%s' "$(echo "$TYPE" | tr '[:upper:]' '[:lower:]')${LABELS:+,$LABELS}")
      if RESP=$(_req POST "$API/issue" "$(mk "$T" "$L")" 2>/dev/null); then
        KEY=$(echo "$RESP" | jq -r '.key // empty'); [ -n "$KEY" ] && break
      fi
    done
    [ -n "$KEY" ] || { _req POST "$API/issue" "$(mk "$TYPE" "$LABELS")" >/dev/null; die "could not create $TYPE '$SUMMARY'"; }
    echo "$KEY"
    ;;

  show)
    KEY="${1:?KEY}"
    R=$(_req GET "$API/issue/$KEY?fields=summary,status,issuetype,parent,description") || exit 1
    echo "$R" | jq -r '"Key:    \(.key)", "Type:   \(.fields.issuetype.name)", "State:  \(.fields.status.name)",
      "Parent: \(.fields.parent.key // "-")", "Title:  \(.fields.summary)",
      "Description:", ([.fields.description | .. | .text? // empty] | join(" ") | .[0:1500])'
    echo "Children:"
    _jql_tsv "parent = $KEY ORDER BY created ASC" 100 | sed 's/^/  /'
    ;;

  search)
    TEXT="${1:?text}"
    Q=$(printf '%s' "$TEXT" | tr -c '[:alnum:] ' ' ' | tr -s ' ')
    _jql_tsv "project = $JIRA_PROJECT_KEY AND text ~ \"$Q\" ORDER BY updated DESC" 25
    ;;

  list)
    _jql_tsv "project = $JIRA_PROJECT_KEY ORDER BY created ASC" 500
    ;;

  status)
    KEY="${1:?KEY}"; WANT="${2:?status}"
    case "$(echo "$WANT" | tr '[:upper:]' '[:lower:]')" in
      done|closed|resolved) CAT="done" ;;
      "in progress"|doing|active) CAT="indeterminate" ;;
      *) CAT="new" ;;
    esac
    TR=$(_req GET "$API/issue/$KEY/transitions") || exit 1
    # Exact name match first, then the first transition into the wanted status category.
    ID=$(echo "$TR" | jq -r --arg w "$WANT" --arg c "$CAT" '
      ([.transitions[] | select((.name|ascii_downcase) == ($w|ascii_downcase) or (.to.name|ascii_downcase) == ($w|ascii_downcase))]
       + [.transitions[] | select(.to.statusCategory.key == $c)]) | first | .id // empty')
    if [ -z "$ID" ]; then
      CUR=$(_req GET "$API/issue/$KEY?fields=status" | jq -r '.fields.status.statusCategory.key')
      [ "$CUR" = "$CAT" ] && { echo "$KEY already $WANT" >&2; exit 0; }
      die "no transition to '$WANT' for $KEY (available: $(echo "$TR" | jq -r '[.transitions[].name]|join(", ")'))"
    fi
    _req POST "$API/issue/$KEY/transitions" "{\"transition\":{\"id\":\"$ID\"}}" >/dev/null || exit 1
    echo "$KEY → $WANT" >&2
    ;;

  comment)
    KEY="${1:?KEY}"; TEXT="${2:?text}"
    _req POST "$API/issue/$KEY/comment" "$(jq -n --argjson b "$(_adf "$TEXT")" '{body:$b}')" >/dev/null || exit 1
    echo "💬 comment → $KEY" >&2
    ;;

  describe)
    KEY="${1:?KEY}"; SRC="${2:?file or text}"
    _req PUT "$API/issue/$KEY" "$(jq -n --argjson d "$(_adf "$SRC")" '{fields:{description:$d}}')" >/dev/null || exit 1
    echo "📝 description → $KEY" >&2
    ;;

  link)
    FROM="${1:?KEY}"; KIND="${2:?duplicate|relates}"; TO="${3:?KEY2}"
    case "$KIND" in duplicate|Duplicate) LT="Duplicate" ;; *) LT="Relates" ;; esac
    _req POST "$API/issueLink" "$(jq -n --arg t "$LT" --arg f "$FROM" --arg to "$TO" \
      '{type:{name:$t}, inwardIssue:{key:$to}, outwardIssue:{key:$f}}')" >/dev/null || exit 1
    echo "🔗 $FROM $LT → $TO" >&2
    ;;

  url) echo "$JIRA_BASE_URL/browse/${1:?KEY}" ;;
  ref) echo "${1:?KEY}" ;;

  sprint-create)
    NAME="${1:?name}"; BOARD=$(_board_id)
    if [ -n "$BOARD" ]; then
      _req POST "$AGILE/sprint" "$(jq -n --arg n "$NAME" --argjson b "$BOARD" '{name:$n, originBoardId:$b}')" | jq -r '.id'
    else
      _req POST "$API/version" "$(jq -n --arg n "$NAME" --arg p "$JIRA_PROJECT_KEY" '{name:$n, project:$p, released:false}')" \
        | jq -r '.name'
    fi
    ;;

  sprint-assign)
    SPRINT="${1:?sprint}"; shift; [ "$#" -gt 0 ] || die "no issue keys"
    if [ -n "$(_board_id)" ]; then
      _req POST "$AGILE/sprint/$SPRINT/issue" "$(printf '%s\n' "$@" | jq -R . | jq -s '{issues:.}')" >/dev/null || exit 1
    else
      for K in "$@"; do
        _req PUT "$API/issue/$K" "$(jq -n --arg v "$SPRINT" '{update:{fixVersions:[{add:{name:$v}}]}}')" >/dev/null || exit 1
      done
    fi
    echo "🗂 $* → sprint $SPRINT" >&2
    ;;

  sprint-start)
    SPRINT="${1:?sprint}"
    [ -z "$(_board_id)" ] && exit 0   # Fix Versions have no start
    STATE=$(_req GET "$AGILE/sprint/$SPRINT" | jq -r '.state')
    [ "$STATE" = "future" ] || exit 0
    _req POST "$AGILE/sprint/$SPRINT" "$(jq -n --arg s "$(dp_today)T00:00:00.000Z" --arg e "$(dp_date_plus 14)T00:00:00.000Z" \
      '{state:"active", startDate:$s, endDate:$e}')" >/dev/null \
      || echo "⚠️  could not start sprint $SPRINT (parallel sprints disabled?) — it stays planned" >&2
    ;;

  sprint-active)
    BOARD=$(_board_id)
    if [ -n "$BOARD" ]; then
      _req GET "$AGILE/board/$BOARD/sprint?state=active" | jq -r '.values | sort_by(.id) | last | .id // empty'
    else
      _req GET "$API/project/$JIRA_PROJECT_KEY/versions" | jq -r '[.[] | select(.released == false)] | first | .name // empty'
    fi
    ;;

  sprint-close)
    SPRINT="${1:?sprint}"
    if [ -n "$(_board_id)" ]; then
      OPEN=$(_jql_tsv "sprint = $SPRINT AND statusCategory != Done" 100 | grep -c . || true)
      [ "$OPEN" -gt 0 ] && { echo "open:$OPEN"; exit 4; }
      STATE=$(_req GET "$AGILE/sprint/$SPRINT" | jq -r '.state')
      [ "$STATE" = "closed" ] && { echo "closed"; exit 0; }
      [ "$STATE" = "future" ] && bash "$0" sprint-start "$SPRINT"
      _req POST "$AGILE/sprint/$SPRINT" '{"state":"closed"}' >/dev/null || { echo "open:0"; exit 4; }
    else
      OPEN=$(_jql_tsv "project = $JIRA_PROJECT_KEY AND fixVersion = \"$SPRINT\" AND statusCategory != Done" 100 | grep -c . || true)
      [ "$OPEN" -gt 0 ] && { echo "open:$OPEN"; exit 4; }
      VID=$(_version_id "$SPRINT"); [ -n "$VID" ] || die "fix version '$SPRINT' not found"
      _req PUT "$API/version/$VID" "$(jq -n --arg d "$(dp_today)" '{released:true, releaseDate:$d}')" >/dev/null || exit 1
    fi
    echo "closed"
    ;;

  sprint-list)
    BOARD=$(_board_id)
    if [ -n "$BOARD" ]; then
      _req GET "$AGILE/board/$BOARD/sprint?state=active,future" | jq -r '.values[] | [.id, .state, .name] | @tsv'
    else
      _req GET "$API/project/$JIRA_PROJECT_KEY/versions" \
        | jq -r '.[] | select(.released == false) | [.name, "unreleased", .name] | @tsv'
    fi
    ;;

  *) echo "Usage: jira.sh <ping|new|show|search|list|status|comment|describe|link|url|ref|sprint-*> …" >&2; exit 2 ;;
esac
