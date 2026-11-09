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
#   dp_secret_store <KEY> <value>   save a secret in the configured provider
#   dp_remote_url             origin URL (empty when no remote)
#   dp_urlenc <text>          percent-encode one path/query component
#
# Secret providers (project.config.md → secrets.provider):
#   file            .devpilot/config.sh (gitignored) — default
#   keychain        macOS Keychain (security) / Linux Secret Service (secret-tool)
#   azure-keyvault  Azure Key Vault (az CLI, logged in) — secrets.vault: <vault-name>
# Only the secret values (DP_SECRET_ONLY) move to a provider; URLs/emails/projects stay in
# config.sh. Precedence: environment variable → provider → config.sh.
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

DP_SECRET_ONLY="JIRA_API_TOKEN AZDO_PAT GITHUB_TOKEN NOTIFY_WEBHOOK"

dp_secret_provider() { local p; p=$(dp_cfg secrets provider); echo "${p:-file}"; }
_dp_account() { local ns; ns=$(dp_cfg secrets namespace); echo "${ns:-default}/$1"; }
_dp_kv_name() { printf 'devpilot-%s' "$(printf '%s' "$1" | tr '[:upper:]_' '[:lower:]-')"; }

dp_secret_fetch() {  # dp_secret_fetch <KEY> → value on stdout (empty if absent)
  case "$(dp_secret_provider)" in
    keychain)
      if command -v security >/dev/null 2>&1; then security find-generic-password -s devpilot -a "$(_dp_account "$1")" -w 2>/dev/null
      elif command -v secret-tool >/dev/null 2>&1; then secret-tool lookup service devpilot account "$(_dp_account "$1")" 2>/dev/null; fi ;;
    azure-keyvault)
      local v; v=$(dp_cfg secrets vault)
      [ -n "$v" ] && command -v az >/dev/null 2>&1 \
        && az keyvault secret show --vault-name "$v" --name "$(_dp_kv_name "$1")" --query value -o tsv 2>/dev/null ;;
  esac
  return 0
}

dp_secret_store() {  # dp_secret_store <KEY> <value> → 0 stored in the provider, 1 use config.sh
  case "$(dp_secret_provider)" in
    keychain)
      if command -v security >/dev/null 2>&1; then
        security add-generic-password -U -s devpilot -a "$(_dp_account "$1")" -w "$2" 2>/dev/null
      elif command -v secret-tool >/dev/null 2>&1; then
        printf '%s' "$2" | secret-tool store --label "DevPilot $1" service devpilot account "$(_dp_account "$1")" 2>/dev/null
      else return 1; fi ;;
    azure-keyvault)
      local v; v=$(dp_cfg secrets vault)
      [ -n "$v" ] && command -v az >/dev/null 2>&1 || return 1
      az keyvault secret set --vault-name "$v" --name "$(_dp_kv_name "$1")" --value "$2" -o none 2>/dev/null ;;
    *) return 1 ;;
  esac
}

dp_load_secrets() {
  [ -n "${DP_SECRETS_LOADED:-}" ] && return 0
  local k v env_v pv
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
    else
      case " $DP_SECRET_ONLY " in
        *" $k "*) [ "$(dp_secret_provider)" != "file" ] && { pv=$(dp_secret_fetch "$k"); [ -n "$pv" ] && v="$pv"; } ;;
      esac
      dp_placeholder "$v" && v=""
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
