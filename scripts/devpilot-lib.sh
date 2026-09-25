# shellcheck shell=bash
# =============================================================================
# devpilot-lib.sh — shared helpers, sourced (never executed) by the tracker,
# git-host and version scripts.
#
#   dp_cfg <key>              top-level value from project.config.md
#   dp_cfg <section> <key>    nested value (e.g. dp_cfg tracker type)
#   dp_placeholder <value>    true when a value is empty or an installer placeholder
#   dp_load_secrets           load .devpilot/config.sh; real environment variables
#                             win over the file, so CI can inject secrets
#   dp_remote_url             origin URL (empty when no remote)
#   dp_urlenc <text>          percent-encode one path/query component
# =============================================================================

DP_ROOT="${DP_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DP_CONFIG="$DP_ROOT/project.config.md"
DP_SECRETS="$DP_ROOT/.devpilot/config.sh"

dp_cfg() {
  [ -f "$DP_CONFIG" ] || return 0
  if [ $# -eq 1 ]; then
    grep -E "^$1:" "$DP_CONFIG" 2>/dev/null | head -1 \
      | sed -E "s/^$1:[[:space:]]*//; s/[[:space:]]+#.*//" | tr -d '"' | awk '{print $1}'
  else
    awk -v s="$1" -v k="$2" '
      $0 ~ "^" s ":"                         { f = 1; next }
      f && /^[^[:space:]#]/                  { f = 0 }
      f && $0 ~ "^[[:space:]]+" k ":"        { sub("^[[:space:]]+" k ":[[:space:]]*", "");
                                               sub(/[[:space:]]+#.*/, ""); gsub(/"/, "");
                                               print $1; exit }
    ' "$DP_CONFIG" 2>/dev/null
  fi
}

dp_placeholder() {
  case "${1:-}" in
    ""|YOUR_*|*YOUR-ORG*|*YOUR_ORG*|*example.com*|your-*|KEY) return 0 ;;
  esac
  return 1
}

DP_SECRET_KEYS="JIRA_BASE_URL JIRA_EMAIL JIRA_API_TOKEN JIRA_PROJECT_KEY
AZDO_ORG_URL AZDO_PROJECT AZDO_PAT AZDO_TEAM AZDO_REPO AZDO_STORY_TYPE
GITHUB_TOKEN GITHUB_ORG GITHUB_REPO TICKET_PREFIX NOTIFY_WEBHOOK"

dp_load_secrets() {
  [ -n "${DP_SECRETS_LOADED:-}" ] && return 0
  local k v env_v
  # Snapshot the real environment before the file can overwrite it.
  for k in $DP_SECRET_KEYS; do
    printf -v "_dp_env_$k" '%s' "${!k:-}"
  done
  [ -z "${GITHUB_TOKEN:-}" ] && [ -n "${GH_TOKEN:-}" ] && _dp_env_GITHUB_TOKEN="$GH_TOKEN"
  # shellcheck source=/dev/null
  [ -f "$DP_SECRETS" ] && . "$DP_SECRETS"
  for k in $DP_SECRET_KEYS; do
    env_v="_dp_env_$k"; env_v="${!env_v}"
    v="${!k:-}"
    if ! dp_placeholder "$env_v"; then v="$env_v"
    elif dp_placeholder "$v"; then v=""
    fi
    printf -v "$k" '%s' "$v"
  done
  AZDO_ORG_URL="${AZDO_ORG_URL%/}"; JIRA_BASE_URL="${JIRA_BASE_URL%/}"
  # Deliberately not exported: child scripts reload from the file, so a value
  # saved mid-run (tracker.sh setup) is never shadowed by a stale copy.
  DP_SECRETS_LOADED=1
}

dp_remote_url() { git -C "$DP_ROOT" config --get remote.origin.url 2>/dev/null || true; }

dp_urlenc() { jq -rn --arg s "$1" '$s|@uri'; }

dp_today() { date -u '+%Y-%m-%d'; }

# dp_date_plus <days> → YYYY-MM-DD (GNU and BSD date)
dp_date_plus() {
  date -u -d "+$1 days" '+%Y-%m-%d' 2>/dev/null || date -u -v+"$1"d '+%Y-%m-%d'
}
