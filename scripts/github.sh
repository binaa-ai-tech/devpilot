#!/usr/bin/env bash
# =============================================================================
# github.sh — GitHub Issues backend for scripts/tracker.sh (same interface as
# jira.sh / azdo.sh). Milestones model sprints; sub-issues model Epic → Story.
#
# Transport: the gh CLI when authenticated, else the REST API with GITHUB_TOKEN
# (or GH_TOKEN) — so it also works where gh is not installed.
# Repo: GITHUB_ORG/GITHUB_REPO from .devpilot/config.sh, else the origin remote.
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=devpilot-lib.sh
. "$DIR/devpilot-lib.sh"
dp_load_secrets

die() { echo "❌ github: $*" >&2; exit 1; }

if [ -n "${GITHUB_ORG:-}" ] && [ -n "${GITHUB_REPO:-}" ]; then
  SLUG="$GITHUB_ORG/$GITHUB_REPO"
else
  SLUG=$(dp_remote_url | sed -nE 's#.*github\.com[:/]([^/]+/[^/]+)$#\1#p' | sed 's/\.git$//')
fi

gh_ok() { command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; }

# _api <METHOD> <path> [json] → body; HTTP errors → stderr + rc 1
_api() {
  local method="$1" path="$2" data="${3:-}" tmp code
  [ -n "$SLUG" ] || die "no GitHub repo (set GITHUB_ORG / GITHUB_REPO or add a github.com origin)"
  if gh_ok; then
    if [ -n "$data" ]; then printf '%s' "$data" | gh api -X "$method" "$path" --input -
    else gh api -X "$method" "$path"; fi
    return $?
  fi
  [ -n "${GITHUB_TOKEN:-}" ] || die "gh is not authenticated and GITHUB_TOKEN is not set"
  tmp=$(mktemp)
  code=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 30 -X "$method" \
    -H "Authorization: Bearer $GITHUB_TOKEN" -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' ${data:+--data "$data"} "https://api.github.com/$path" 2>/dev/null)
  if [ "${code:-000}" -ge 200 ] 2>/dev/null && [ "$code" -lt 300 ]; then cat "$tmp"; rm -f "$tmp"; return 0; fi
  echo "github HTTP ${code:-000} $method $path: $(head -c 300 "$tmp")" >&2
  rm -f "$tmp"; return 1
}

_n() { printf '%s' "$1" | grep -oE '[0-9]+' | tail -1; }
_text_or_file() { if [ -f "$1" ]; then cat "$1"; else printf '%s' "$1"; fi; }

ROW='def row: ([.labels[]?.name | ascii_downcase]) as $l
  | [ "GH-\(.number)",
      (if ($l|index("epic")) then "Epic" elif ($l|index("bug")) then "Bug" elif ($l|index("task")) then "Task" else "Story" end),
      (if .state == "closed" then "Done" elif ($l|index("in-progress")) then "In Progress" else "To Do" end),
      (if .state == "closed" then "done" elif ($l|index("in-progress")) then "doing" else "todo" end),
      "-", (.title | gsub("[\t\n]"; " ")) ] | @tsv;'

cmd="${1:-}"; shift || true
case "$cmd" in
  ping)
    _api GET "repos/$SLUG" >/dev/null || die "cannot reach $SLUG"
    echo "✅ GitHub Issues reachable — $SLUG"
    ;;

  new)
    TYPE="${1:?type}"; SUMMARY="${2:?summary}"; BODY="${3:-}"; PARENT="${4:-}"; LABELS="${5:-}"
    LBL=$(echo "$TYPE" | tr '[:upper:]' '[:lower:]'); [ "$LBL" = "subtask" ] && LBL="task"
    TITLE="$SUMMARY"; [ "$TYPE" = "Epic" ] && TITLE="[Epic] $SUMMARY"
    TEXT=$(_text_or_file "${BODY:-_(created by DevPilot)_}")
    [ -n "$PARENT" ] && TEXT="Parent: #$(_n "$PARENT")

$TEXT"
    R=$(_api POST "repos/$SLUG/issues" "$(jq -n --arg t "$TITLE" --arg b "$TEXT" --arg l "$LBL${LABELS:+,$LABELS}" \
      '{title:$t, body:$b, labels:($l|split(",")|map(select(length>0)))}')") || die "could not create issue '$SUMMARY'"
    N=$(echo "$R" | jq -r '.number'); IID=$(echo "$R" | jq -r '.id')
    if [ -n "$PARENT" ]; then
      _api POST "repos/$SLUG/issues/$(_n "$PARENT")/sub_issues" "{\"sub_issue_id\":$IID}" >/dev/null 2>&1 \
        || echo "ℹ️  sub-issue link skipped (not enabled on this repo) — parent noted in the body" >&2
    fi
    echo "GH-$N"
    ;;

  show)
    N=$(_n "${1:?KEY}")
    _api GET "repos/$SLUG/issues/$N" | jq -r '"Key:    GH-\(.number)", "Type:   \([.labels[].name] | join(","))",
      "State:  \(.state)", "Parent: -", "Title:  \(.title)", "Description:", ((.body // "") | .[0:1500])' || exit 1
    echo "Children:"
    _api GET "repos/$SLUG/issues/$N/sub_issues?per_page=100" 2>/dev/null | jq -r "$ROW .[] | row" | sed 's/^/  /'
    ;;

  search)
    Q="repo:$SLUG is:issue $(printf '%s' "${1:?text}" | tr -c '[:alnum:] ' ' ' | tr -s ' ')"
    _api GET "search/issues?per_page=25&q=$(dp_urlenc "$Q")" | jq -r "$ROW .items[] | row"
    ;;

  list)
    for PAGE in 1 2 3 4 5; do
      OUT=$(_api GET "repos/$SLUG/issues?state=all&per_page=100&page=$PAGE") || exit 1
      [ "$(echo "$OUT" | jq 'length')" -eq 0 ] && break
      echo "$OUT" | jq -r "$ROW .[] | select(.pull_request | not) | row"
    done
    ;;

  status)
    N=$(_n "${1:?KEY}"); WANT=$(echo "${2:?status}" | tr '[:upper:]' '[:lower:]')
    case "$WANT" in
      done|closed|resolved)
        _api PATCH "repos/$SLUG/issues/$N" '{"state":"closed","state_reason":"completed"}' >/dev/null || exit 1
        _api DELETE "repos/$SLUG/issues/$N/labels/in-progress" >/dev/null 2>&1 || true ;;
      "in progress"|doing|active)
        _api PATCH "repos/$SLUG/issues/$N" '{"state":"open"}' >/dev/null || exit 1
        _api POST "repos/$SLUG/issues/$N/labels" '{"labels":["in-progress"]}' >/dev/null || exit 1 ;;
      *)
        _api PATCH "repos/$SLUG/issues/$N" '{"state":"open"}' >/dev/null || exit 1 ;;
    esac
    echo "GH-$N → ${2}" >&2
    ;;

  comment)
    N=$(_n "${1:?KEY}")
    _api POST "repos/$SLUG/issues/$N/comments" "$(jq -n --arg b "${2:?text}" '{body:$b}')" >/dev/null || exit 1
    echo "💬 comment → GH-$N" >&2
    ;;

  describe)
    N=$(_n "${1:?KEY}")
    _api PATCH "repos/$SLUG/issues/$N" "$(jq -n --arg b "$(_text_or_file "${2:?file or text}")" '{body:$b}')" >/dev/null || exit 1
    echo "📝 description → GH-$N" >&2
    ;;

  link)
    FROM=$(_n "${1:?KEY}"); KIND="${2:?duplicate|relates}"; TO=$(_n "${3:?KEY2}")
    if [ "$KIND" = "duplicate" ] || [ "$KIND" = "Duplicate" ]; then
      _api POST "repos/$SLUG/issues/$FROM/comments" "{\"body\":\"Duplicate of #$TO\"}" >/dev/null || exit 1
      _api PATCH "repos/$SLUG/issues/$FROM" '{"state":"closed","state_reason":"not_planned"}' >/dev/null || exit 1
    else
      _api POST "repos/$SLUG/issues/$FROM/comments" "{\"body\":\"Related to #$TO\"}" >/dev/null || exit 1
    fi
    echo "🔗 GH-$FROM $KIND → GH-$TO" >&2
    ;;

  url) echo "https://github.com/$SLUG/issues/$(_n "${1:?KEY}")" ;;
  ref) echo "#$(_n "${1:?KEY}")" ;;

  sprint-create)
    _api POST "repos/$SLUG/milestones" "$(jq -n --arg t "${1:?name}" --arg d "$(dp_date_plus 14)T00:00:00Z" \
      '{title:$t, due_on:$d}')" | jq -r '.number'
    ;;
  sprint-assign)
    M="${1:?milestone}"; shift; [ "$#" -gt 0 ] || die "no issue keys"
    for K in "$@"; do _api PATCH "repos/$SLUG/issues/$(_n "$K")" "{\"milestone\":$M}" >/dev/null || exit 1; done
    echo "🗂 $* → milestone $M" >&2
    ;;
  sprint-start) exit 0 ;;
  sprint-active)
    _api GET "repos/$SLUG/milestones?state=open&sort=due_on&direction=asc" | jq -r '.[0].number // empty'
    ;;
  sprint-close)
    M="${1:?milestone}"
    OPEN=$(_api GET "repos/$SLUG/milestones/$M" | jq -r '.open_issues') || exit 1
    [ "${OPEN:-0}" -gt 0 ] && { echo "open:$OPEN"; exit 4; }
    _api PATCH "repos/$SLUG/milestones/$M" '{"state":"closed"}' >/dev/null || exit 1
    echo "closed"
    ;;
  sprint-list)
    _api GET "repos/$SLUG/milestones?state=open" | jq -r '.[] | [.number, .state, .title] | @tsv'
    ;;

  delete)   # REST cannot delete issues — close as not planned instead
    N=$(_n "${1:?KEY}")
    _api PATCH "repos/$SLUG/issues/$N" '{"state":"closed","state_reason":"not_planned"}' >/dev/null || exit 1
    echo "🗑 GH-$N closed (issues cannot be deleted via the API)" >&2
    ;;
  sprint-delete)
    _api DELETE "repos/$SLUG/milestones/${1:?milestone}" >/dev/null || exit 1
    echo "🗑 milestone ${1} deleted" >&2
    ;;

  *) echo "Usage: github.sh <ping|new|show|search|list|status|comment|describe|link|url|ref|sprint-*> …" >&2; exit 2 ;;
esac
