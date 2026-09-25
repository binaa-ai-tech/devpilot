#!/usr/bin/env bash
# =============================================================================
# tracker.sh — the ONE work-tracking interface every command uses.
#
# Backend = project.config.md → tracker.type:
#   local   docs/tasks/<KEY>.md files, zero setup (default)
#   jira    Jira Cloud          → scripts/jira.sh
#   azure   Azure DevOps Boards → scripts/azdo.sh
#   github  GitHub Issues       → scripts/github.sh
#
# Setup / decision (the "not configured" flow):
#   check                 0 ready · 2 external tracker selected but not configured
#                         3 local tracker, the user has never chosen (offer to connect)
#   skip                  continue locally until credentials are added (no more asking)
#   use <type>            switch tracker.type
#   setup <type> [KEY=VALUE ...]   store credentials, switch, verify live
#   ping                  live connection test · type · configured
#
# Work items (every backend):
#   new <Epic|Story|Bug|Task> <summary> <body-file|text> [parent] [labels]  → KEY
#   show <KEY>            details + child items (existing tasks under it)
#   search <text>         scored dedup candidates: SCORE KEY TYPE STATE CAT PARENT TITLE
#   list                  every item (TSV: KEY TYPE STATE CAT PARENT TITLE)
#   status <KEY> <To Do|In Progress|Done> · comment <KEY> <text> · describe <KEY> <file|text>
#   link <KEY> <duplicate|relates> <KEY2> · url <KEY> · ref <KEY>
#   close <KEY...>        → Done
#   close-parent <KEY>    → Done when every child is done
#   sprint <create|assign|start|active|close|list> …   (close exits 4 while items are open)
#
# Gates:
#   assert-key <KEY...>   at least one well-formed key exists (tracker-first rule)
#   hotfix-gate <intent> <severity>   P0/P1 bugs must use /dp-hotfix
#
# Only new / search / list / show / url / ref / sprint create|active|list print
# on stdout; progress goes to stderr so KEY=$(tracker.sh new …) stays clean.
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=devpilot-lib.sh
. "$DIR/devpilot-lib.sh"
dp_load_secrets

TASKS="$DP_ROOT/docs/tasks"
SPRINTS="$DP_ROOT/docs/sprints"
SKIP_FILE="$DP_ROOT/.devpilot/.tracker-skip"
KEY_RE='^[A-Z][A-Z0-9_]*-[0-9]+$'

log() { echo "$*" >&2; }

configured_type() {
  local t; t=$(dp_cfg tracker type)
  case "$t" in jira|azure|github) echo "$t" ;; *) echo "local" ;; esac
}

gh_ok() { command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; }

# Credentials present (no network call) — `ping` does the live test.
creds_ok() {
  case "$1" in
    jira)   [ -n "$JIRA_BASE_URL" ] && [ -n "$JIRA_EMAIL" ] && [ -n "$JIRA_API_TOKEN" ] && [ -n "$JIRA_PROJECT_KEY" ] ;;
    azure)  [ -n "$AZDO_PAT" ] && { { [ -n "$AZDO_ORG_URL" ] && [ -n "$AZDO_PROJECT" ]; } \
              || dp_remote_url | grep -qE 'dev\.azure\.com|visualstudio\.com'; } ;;
    github) gh_ok || { [ -n "$GITHUB_TOKEN" ] && { [ -n "$GITHUB_REPO" ] || dp_remote_url | grep -q 'github\.com'; }; } ;;
    *)      return 0 ;;
  esac
}

effective_type() {
  local t; t=$(configured_type)
  if [ "$t" != "local" ] && ! creds_ok "$t"; then echo "local"; else echo "$t"; fi
}

missing_help() {
  case "$1" in
    jira) cat <<'EOF'
  Jira needs 4 values (API token: https://id.atlassian.com/manage-profile/security/api-tokens):
    bash scripts/tracker.sh setup jira jira_base_url=https://<org>.atlassian.net \
         jira_email=<you@org.com> jira_api_token=<token> jira_project_key=<KEY>
EOF
    ;;
    azure) cat <<'EOF'
  Azure DevOps needs 3 values (PAT scopes: Work Items R/W, Code R/W, Build Read):
    bash scripts/tracker.sh setup azure azdo_org_url=https://dev.azure.com/<org> \
         azdo_project=<project> azdo_pat=<token>
EOF
    ;;
    github) cat <<'EOF'
  GitHub Issues needs `gh auth login`, or a token with Issues R/W:
    bash scripts/tracker.sh setup github github_token=<token>
EOF
    ;;
  esac
}

# ── local backend ─────────────────────────────────────────────────────────────
local_field() { grep -m1 -E "^- $2:" "$1" 2>/dev/null | sed -E "s/^- $2:[[:space:]]*//"; }
local_row() {
  local f="$1" key title type state cat parent
  key=$(basename "$f" .md)
  title=$(head -1 "$f" | sed -E 's/^# [^ ]+ — //')
  type=$(local_field "$f" Type); state=$(local_field "$f" Status); parent=$(local_field "$f" Parent)
  case "$state" in Done) cat="done" ;; "In Progress") cat="doing" ;; *) cat="todo"; state="To Do" ;; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$key" "${type:-Task}" "$state" "$cat" "${parent:--}" "$title"
}
local_append() {
  local f="$TASKS/$1.md"
  mkdir -p "$TASKS"; [ -f "$f" ] || printf '# %s\n\n## Activity\n' "$1" > "$f"
  printf -- '- [%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$2" >> "$f"
}
local_set_status() {
  local f="$TASKS/$1.md" tmp
  [ -f "$f" ] || local_append "$1" "created"
  if grep -q '^- Status:' "$f"; then
    tmp=$(mktemp); awk -v s="$2" '/^- Status:/ && !d { print "- Status: " s; d = 1; next } { print }' "$f" > "$tmp" && mv "$tmp" "$f"
  else
    tmp=$(mktemp); awk -v s="$2" 'NR == 2 { print "- Status: " s } { print }' "$f" > "$tmp" && mv "$tmp" "$f"
  fi
  local_append "$1" "Status → $2"
}
local_sprint_file() { printf '%s/%s.md' "$SPRINTS" "$(printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-')"; }

local_cmd() {
  local c="$1"; shift
  case "$c" in
    ping) echo "✅ local tracker — docs/tasks/" ;;
    new)
      local type="$1" summary="$2" body="${3:-}" parent="${4:-}" labels="${5:-}" key
      mkdir -p "$TASKS"
      # Sequential keys (LOCAL-1, LOCAL-2 …) — short and branch-friendly.
      key=$(find "$TASKS" -maxdepth 1 -name 'LOCAL-*.md' 2>/dev/null | sed -nE 's#.*/LOCAL-([0-9]+)\.md$#\1#p' \
        | sort -n | tail -1)
      key="LOCAL-$(( ${key:-0} + 1 ))"
      {
        echo "# $key — $summary"
        echo "- Type: $type"
        echo "- Status: To Do"
        [ -n "$parent" ] && echo "- Parent: $parent"
        [ -n "$labels" ] && echo "- Labels: $labels"
        echo "- Created: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "## Description"
        if [ -f "$body" ]; then cat "$body"; else echo "${body:-(none)}"; fi
        echo ""
        echo "## Activity"
      } > "$TASKS/$key.md"
      log "📝 local $type $key → docs/tasks/$key.md"
      echo "$key"
      ;;
    show)
      local f="$TASKS/$1.md" c2
      [ -f "$f" ] || { log "❌ $1 not found"; return 1; }
      local_row "$f" | awk -F'\t' '{ printf "Key:    %s\nType:   %s\nState:  %s\nParent: %s\nTitle:  %s\n", $1, $2, $3, $5, $6 }'
      echo "Description:"
      sed -n '/^## Description/,/^## Activity/p' "$f" | sed '1d;$d' | head -40
      echo "Children:"
      for c2 in "$TASKS"/*.md; do
        [ -f "$c2" ] && [ "$(local_field "$c2" Parent)" = "$1" ] && local_row "$c2" | sed 's/^/  /'
      done
      return 0
      ;;
    search|list)
      local f k
      for f in "$TASKS"/*.md; do
        k=$(basename "$f" .md)
        [[ "$k" =~ $KEY_RE ]] && [ -f "$f" ] && local_row "$f"
      done
      return 0
      ;;
    status)   local_set_status "$1" "$( case "$(echo "$2" | tr '[:upper:]' '[:lower:]')" in
                done|closed|resolved) echo Done ;; "in progress"|doing|active) echo "In Progress" ;; *) echo "To Do" ;; esac )"
              log "$1 → $2" ;;
    comment)  local_append "$1" "$(printf '%s' "$2" | head -1)"; log "💬 comment → $1" ;;
    describe) local_append "$1" "Description updated$( [ -f "$2" ] && echo " from $2")"; log "📝 description → $1" ;;
    link)     local_append "$1" "$2 → $3"; local_append "$3" "linked from $1 ($2)"; log "🔗 $1 $2 → $3" ;;
    url)      echo "docs/tasks/$1.md" ;;
    ref)      echo "$1" ;;
    sprint-create)
      local sf; sf=$(local_sprint_file "$1"); mkdir -p "$SPRINTS"
      [ -f "$sf" ] || printf '# Sprint %s\n- State: active\n- Created: %s\n\n## Items\n' "$1" "$(date '+%Y-%m-%d')" > "$sf"
      basename "$sf" .md
      ;;
    sprint-assign)
      local sf k; sf=$(local_sprint_file "$1"); shift
      [ -f "$sf" ] || local_cmd sprint-create "$(basename "$sf" .md)" >/dev/null
      for k in "$@"; do grep -qx -- "- $k" "$sf" || echo "- $k" >> "$sf"; local_append "$k" "Sprint → $(basename "$sf" .md)"; done
      log "🗂 $* → sprint $(basename "$sf" .md)"
      ;;
    sprint-start) return 0 ;;
    sprint-active)
      local sf newest=""
      for sf in "$SPRINTS"/*.md; do
        [ -f "$sf" ] && grep -q '^- State: active' "$sf" \
          && { [ -z "$newest" ] || [ "$sf" -nt "$newest" ]; } && newest="$sf"
      done
      [ -n "$newest" ] && basename "$newest" .md
      return 0
      ;;
    sprint-close)
      local sf k open=0 tmp; sf=$(local_sprint_file "$1")
      [ -f "$sf" ] || { echo "closed"; return 0; }
      for k in $(sed -n 's/^- \([A-Z][A-Z0-9_]*-[0-9][0-9]*\)$/\1/p' "$sf"); do
        [ "$(local_field "$TASKS/$k.md" Status)" = "Done" ] || open=$((open + 1))
      done
      [ "$open" -gt 0 ] && { echo "open:$open"; return 4; }
      tmp=$(mktemp); sed 's/^- State: active/- State: closed/' "$sf" > "$tmp" && mv "$tmp" "$sf"
      echo "closed"
      ;;
    sprint-list)
      local sf
      for sf in "$SPRINTS"/*.md; do
        [ -f "$sf" ] && grep -q '^- State:' "$sf" \
          && printf '%s\t%s\t%s\n' "$(basename "$sf" .md)" "$(local_field "$sf" State)" "$(head -1 "$sf" | sed 's/^# Sprint //')"
      done
      return 0
      ;;
    *) log "local tracker: unknown command $c"; return 2 ;;
  esac
}

backend() {
  local c="$1"; shift
  case "$(effective_type)" in
    jira)   bash "$DIR/jira.sh"   "$c" "$@" ;;
    azure)  bash "$DIR/azdo.sh"   "$c" "$@" ;;
    github) bash "$DIR/github.sh" "$c" "$@" ;;
    *)      local_cmd "$c" "$@" ;;
  esac
}

# Keyword-overlap score of each candidate title against the request.
score_rows() {
  local words
  words=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' ' ' | tr -s ' ' '\n' \
    | awk 'length >= 3 && !/^(the|and|for|with|from|that|this|add|new|when|into|should|able|user|users|can|will|are|not)$/' | sort -u)
  awk -F'\t' -v w="$(printf '%s ' $words)" '
    BEGIN { n = split(w, kw, " ") }
    { t = tolower($6); s = 0; for (i = 1; i <= n; i++) if (kw[i] != "" && index(t, kw[i])) s++
      if (s > 0) printf "%d\t%s\n", s, $0 }' | sort -t"$(printf '\t')" -k1,1nr | head -10
}

cmd="${1:-}"; shift || true
case "$cmd" in
  type)       effective_type ;;
  configured) configured_type ;;

  check)
    T=$(configured_type); WHEN=$(dp_cfg tracker when_unconfigured); WHEN="${WHEN:-ask}"
    if [ "$T" = "local" ]; then
      if [ "$WHEN" = "ask" ] && [ ! -f "$SKIP_FILE" ]; then
        echo "TRACKER=local STATE=choose"
        echo "ℹ️  No external tracker is connected. Connect Jira, Azure DevOps or GitHub Issues now,"
        echo "   or continue with local tracking (docs/tasks/). Record the choice with:"
        echo "     bash scripts/tracker.sh skip        # keep local, stop asking"
        missing_help jira; missing_help azure; missing_help github
        echo "  Secrets can also come from environment variables with the same names (CI)."
        exit 3
      fi
      echo "TRACKER=local STATE=ready"; echo "✅ Local tracking (docs/tasks/)."
      exit 0
    fi
    if creds_ok "$T"; then
      rm -f "$SKIP_FILE"
      echo "TRACKER=$T STATE=ready"; echo "✅ $T tracker configured — the PLAN phase creates the items before any code."
      exit 0
    fi
    if [ -f "$SKIP_FILE" ] || [ "$WHEN" = "skip" ]; then
      echo "TRACKER=local STATE=skipped"
      echo "⏭  tracker '$T' is not configured — continuing with local tracking (docs/tasks/)."
      echo "   Connect it any time: /dp-setup tracker"
      exit 0
    fi
    echo "TRACKER=$T STATE=unconfigured"
    echo "⚠️  tracker '$T' is selected but its credentials are missing."
    missing_help "$T"
    echo "  Or continue without it:  bash scripts/tracker.sh skip"
    exit 2
    ;;

  skip)
    mkdir -p "$(dirname "$SKIP_FILE")"
    echo "skipped $(configured_type) $(date '+%Y-%m-%d %H:%M')" > "$SKIP_FILE"
    log "⏭  Continuing with local tracking. Connect later with /dp-setup tracker."
    ;;

  use)
    T="${1:?Usage: tracker.sh use <local|jira|azure|github>}"
    case "$T" in local|jira|azure|github) ;; *) log "❌ unknown tracker '$T'"; exit 1 ;; esac
    [ -f "$DP_CONFIG" ] || { log "❌ project.config.md not found"; exit 1; }
    TMP=$(mktemp)
    if grep -q '^tracker:' "$DP_CONFIG"; then
      awk -v t="$T" '
        /^tracker:/ { f = 1; print; next }
        f && /^[^[:space:]#]/ { f = 0 }
        f && /^[[:space:]]+type:/ && !d { sub(/type:[[:space:]]*[A-Za-z]+/, "type: " t); d = 1 }
        { print }' "$DP_CONFIG" > "$TMP"
    else
      { cat "$DP_CONFIG"; printf '\ntracker:\n  type: %s\n' "$T"; } > "$TMP"
    fi
    mv "$TMP" "$DP_CONFIG"
    [ "$T" != "local" ] && rm -f "$SKIP_FILE"
    log "✅ tracker.type → $T"
    ;;

  setup)
    T="${1:?Usage: tracker.sh setup <jira|azure|github> KEY=VALUE ...}"; shift
    if [ ! -f "$DP_SECRETS" ]; then
      mkdir -p "$(dirname "$DP_SECRETS")"
      printf '#!/bin/bash\n# DevPilot secrets — gitignored. Manage with scripts/devpilot-config.sh\n' > "$DP_SECRETS"
    fi
    for KV in "$@"; do ( cd "$DP_ROOT" && bash "$DIR/devpilot-config.sh" set "$KV" >/dev/null ) || exit 1; done
    bash "$0" use "$T" || exit 1
    bash "$0" ping
    ;;

  ping)
    T=$(configured_type)
    if [ "$T" != "local" ] && ! creds_ok "$T"; then log "⚠️  $T credentials missing"; missing_help "$T" >&2; exit 2; fi
    backend ping
    ;;

  new)
    [ $# -ge 2 ] || { log "Usage: tracker.sh new <Epic|Story|Bug|Task> <summary> <body-file|text> [parent] [labels]"; exit 1; }
    backend new "$@"
    ;;
  show|status|comment|describe|link|url|ref|list) backend "$cmd" "$@" ;;

  search)
    TEXT="${1:?Usage: tracker.sh search <text>}"
    backend search "$TEXT" | score_rows "$TEXT"
    ;;

  close)
    RC=0
    for K in "$@"; do backend status "$K" "Done" || RC=1; done
    exit $RC
    ;;

  close-parent)
    P="${1:?Usage: tracker.sh close-parent <KEY>}"
    KIDS=$(backend show "$P" | sed -n '/^Children:/,$p' | tail -n +2)
    [ -z "$KIDS" ] && { log "$P has no child items — left as is"; exit 0; }
    OPEN=$(printf '%s\n' "$KIDS" | awk -F'\t' '$4 != "done"' | grep -c . || true)
    if [ "$OPEN" -gt 0 ]; then log "$P stays open — $OPEN child item(s) not done"; exit 0; fi
    backend status "$P" "Done"
    ;;

  sprint)
    SUB="${1:?Usage: tracker.sh sprint <create|assign|start|active|close|list> …}"; shift
    backend "sprint-$SUB" "$@"
    ;;

  assert-key)
    VALID=0
    for K in "$@"; do [[ "$K" =~ $KEY_RE ]] && VALID=$((VALID + 1)); done
    if [ "$VALID" -ge 1 ]; then log "✅ Tracker gate passed — $VALID key(s): $*"; exit 0; fi
    log "❌ Tracker ceremony was SKIPPED — no work item key was produced."
    log "   /dp-deliver and /dp-plan MUST create the item (Epic→Story, or Bug) BEFORE any code:"
    log "     EPIC=\$(bash scripts/tracker.sh new Epic \"<epic>\" \"<goal>\")"
    log "     KEY=\$(bash scripts/tracker.sh new Story \"<summary>\" docs/tasks/<slug>-brief.md \"\$EPIC\")"
    log "   DUPLICATE / FOLD-IN verdicts resolve to the EXISTING key — still never empty."
    exit 1
    ;;

  hotfix-gate)
    INTENT=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')
    SEV=$(printf '%s' "${2:-}" | tr '[:lower:]' '[:upper:]')
    if { [ "$INTENT" = "bug" ] || [ "$INTENT" = "issue" ]; } && { [ "$SEV" = "P0" ] || [ "$SEV" = "P1" ]; }; then
      log "❌ STOP — a $SEV bug must not go through /dp-deliver or /dp-plan."
      log "   Production-critical defects take the expedited lane: /dp-hotfix <ticket> <slug> <version>"
      log "   (branches from main, minimal diff, human-approved PRD deploy, postmortem)."
      exit 1
    fi
    exit 0
    ;;

  *)
    sed -n '3,38p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
