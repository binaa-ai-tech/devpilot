#!/usr/bin/env bash
# =============================================================================
# track.sh — issue-tracker abstraction
#
# One wrapper over three backends, selected by `tracker.type` in
# project.config.md:
#
#   local   — no external service; everything is logged to docs/tasks/<KEY>.md
#   github  — GitHub Issues via the `gh` CLI (falls back to local if gh absent)
#   jira    — Jira Cloud via the existing scripts/*-jira-*.sh helpers
#
# Subcommands (stable interface — command files call these):
#   track.sh new-ticket "<summary>" "<body>" "<type>"   → echoes KEY (stdout)
#   track.sh new-epic   "<name>" "<body>" [parent]        → echoes KEY (stdout)
#   track.sh status     "<KEY>" "<status>"
#   track.sh comment    "<KEY>" "<body>"
#   track.sh describe   "<KEY>" "<body>"
#
# Only new-ticket / new-epic print the KEY on stdout; everything else logs to
# stderr so command substitution (`KEY=$(track.sh new-ticket ...)`) stays clean.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TASKS_DIR="$ROOT/docs/tasks"

log() { echo "$*" >&2; }

tracker_type() {
  local t=""
  [ -f "$ROOT/project.config.md" ] && t=$(grep -A 3 '^tracker:' "$ROOT/project.config.md" 2>/dev/null \
    | grep -E '^[[:space:]]*type:' | head -1 | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  case "$t" in
    local|github|jira) echo "$t" ;;
    *) echo "local" ;;   # default: zero-setup local tracking
  esac
}

# ── local backend ────────────────────────────────────────────────────────────
local_new() {
  local summary="$1" body="${2:-}" kind="${3:-Task}"
  mkdir -p "$TASKS_DIR"
  local key="LOCAL-$(date '+%y%m%d%H%M%S')"
  # Guard against same-second collisions.
  while [ -f "$TASKS_DIR/$key.md" ]; do key="LOCAL-$(date '+%y%m%d%H%M%S')$RANDOM"; done
  {
    echo "# $key — $summary"
    echo ""
    echo "- Type: $kind"
    echo "- Created: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "## Description"
    echo "${body:-(none)}"
    echo ""
    echo "## Activity"
  } > "$TASKS_DIR/$key.md"
  log "📝 local ticket $key → docs/tasks/$key.md"
  echo "$key"
}

local_append() {
  local key="$1" line="$2"
  mkdir -p "$TASKS_DIR"
  local f="$TASKS_DIR/$key.md"
  [ -f "$f" ] || { echo "# $key"; echo ""; echo "## Activity"; } > "$f"
  printf -- '- [%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$line" >> "$f"
}

# ── github backend (gh CLI) ───────────────────────────────────────────────────
gh_ok() { command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; }

gh_issue_num() { echo "$1" | grep -oE '[0-9]+' | head -1; }

# ── dispatch ───────────────────────────────────────────────────────────────────
TYPE="$(tracker_type)"
CMD="${1:-}"; shift || true

# github with no usable gh → degrade to local
if [ "$TYPE" = "github" ] && ! gh_ok; then
  log "⚠️  tracker=github but gh is unavailable/unauthenticated — using local tracking."
  TYPE="local"
fi

case "$CMD" in
  new-ticket)
    SUMMARY="${1:-}"; BODY="${2:-}"; KIND="${3:-Task}"
    case "$TYPE" in
      jira)   DEVPILOT_TRACKER_DIRECT=1 bash "$ROOT/scripts/create-jira-ticket.sh" "$SUMMARY" "$BODY" "$KIND" ;;
      github) URL=$(gh issue create --title "$SUMMARY" --body "${BODY:-_(created by devpilot)_}" 2>/dev/null);
              N=$(gh_issue_num "$URL"); log "🐙 GitHub issue #$N — $URL"; echo "GH-$N" ;;
      *)      local_new "$SUMMARY" "$BODY" "$KIND" ;;
    esac
    ;;
  new-epic)
    SUMMARY="${1:-}"; BODY="${2:-}"; PARENT="${3:-}"
    case "$TYPE" in
      jira)   DEVPILOT_TRACKER_DIRECT=1 bash "$ROOT/scripts/create-jira-epic.sh" "$SUMMARY" "$BODY" "$PARENT" ;;
      github) URL=$(gh issue create --title "[Epic] $SUMMARY" --body "${BODY:-_(epic)_}" 2>/dev/null);
              N=$(gh_issue_num "$URL"); log "🐙 GitHub epic issue #$N — $URL"; echo "GH-$N" ;;
      *)      local_new "$SUMMARY" "$BODY" "Epic" ;;
    esac
    ;;
  status)
    KEY="${1:-}"; STATUS="${2:-}"
    case "$TYPE" in
      jira)   DEVPILOT_TRACKER_DIRECT=1 bash "$ROOT/scripts/update-jira-status.sh" "$KEY" "$STATUS" ;;
      github) N=$(gh_issue_num "$KEY");
              gh issue comment "$N" --body "Status → **$STATUS**" >/dev/null 2>&1 || true
              [ "$STATUS" = "Done" ] && gh issue close "$N" >/dev/null 2>&1 || true
              log "$KEY → $STATUS" ;;
      *)      local_append "$KEY" "Status → $STATUS"; log "$KEY → $STATUS" ;;
    esac
    ;;
  comment)
    KEY="${1:-}"; BODY="${2:-}"
    case "$TYPE" in
      jira)   DEVPILOT_TRACKER_DIRECT=1 bash "$ROOT/scripts/add-jira-comment.sh" "$KEY" "$BODY" ;;
      github) N=$(gh_issue_num "$KEY"); gh issue comment "$N" --body "$BODY" >/dev/null 2>&1 || true
              log "💬 comment → $KEY" ;;
      *)      local_append "$KEY" "$(echo "$BODY" | head -1)"; log "💬 comment → $KEY" ;;
    esac
    ;;
  describe)
    KEY="${1:-}"; BODY="${2:-}"
    case "$TYPE" in
      jira)   DEVPILOT_TRACKER_DIRECT=1 bash "$ROOT/scripts/update-jira-description.sh" "$KEY" "$BODY" ;;
      github) N=$(gh_issue_num "$KEY"); gh issue edit "$N" --body "$BODY" >/dev/null 2>&1 || true
              log "📝 description → $KEY" ;;
      *)      local_append "$KEY" "Description updated"; log "📝 description → $KEY" ;;
    esac
    ;;
  *)
    log "Usage: track.sh <new-ticket|new-epic|status|comment|describe> ..."
    exit 1
    ;;
esac
