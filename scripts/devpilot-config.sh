#!/usr/bin/env bash
# =============================================================================
# devpilot-config.sh — Read, update, and validate devpilot configuration
#
# Usage:
#   bash scripts/devpilot-config.sh get jira_token
#   bash scripts/devpilot-config.sh set jira_token=<value>
#   bash scripts/devpilot-config.sh set jira_base_url=https://myorg.atlassian.net
#   bash scripts/devpilot-config.sh validate
#   bash scripts/devpilot-config.sh show
#
# All values live in .devpilot/config.sh (gitignored); environment variables of the
# same name override them (CI). Switch trackers with scripts/tracker.sh setup.
# This script updates that file safely via sed — no manual editing required.
# =============================================================================
set -euo pipefail

CONFIG_FILE=".devpilot/config.sh"
LOCK_DIR=".devpilot/.config.lock"

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

info()  { echo -e "${GREEN}[config]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[config]${RESET} $*"; }
error() { echo -e "${RED}[config] ERROR:${RESET} $*" >&2; exit 1; }

# ── Helpers ───────────────────────────────────────────────────────────────────

require_config() {
  [ -f "$CONFIG_FILE" ] || error "Config file not found: $CONFIG_FILE\nRun the installer first: bash install.sh"
}

acquire_lock() {
  local attempts=0
  local max_attempts=200

  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge "$max_attempts" ]; then
      error "Could not acquire config lock ($LOCK_DIR). Another process may still be writing."
    fi
    sleep 0.05
  done
}

release_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

with_lock() {
  acquire_lock
  local status=0
  if "$@"; then
    status=0
  else
    status=$?
  fi
  release_lock
  return "$status"
}

normalize_key() {
  local key="$1"
  key=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')
  if [[ ! "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
    error "Invalid key: $1 (allowed: letters, digits, underscore; cannot start with digit)"
  fi
  printf '%s\n' "$key"
}

strip_wrapping_quotes() {
  local val="$1"
  if [[ "$val" =~ ^\".*\"$ ]]; then
    val="${val#\"}"
    val="${val%\"}"
  elif [[ "$val" =~ ^\'.*\'$ ]]; then
    val="${val#\'}"
    val="${val%\'}"
  fi
  printf '%s\n' "$val"
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\"'\"'/g")"
}

# Read a single key from config.sh
config_get() {
  local key
  key=$(normalize_key "$1")
  require_config
  local line val
  line=$(grep -E "^${key}=" "$CONFIG_FILE" 2>/dev/null | head -1 || true)
  val="${line#*=}"
  val=$(strip_wrapping_quotes "$val")
  echo "$val"
}

# Set a single key in config.sh (creates or updates the line)
config_set_locked() {
  local key="$1"
  local val="$2"
  local now
  now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  local line generation_line
  line="${key}=$(shell_quote "$val")"
  generation_line="DEVPILOT_CONFIG_UPDATED_AT=$(shell_quote "$now")"

  local tmp
  tmp=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")

  awk -v k="$key" -v nl="$line" -v gk="DEVPILOT_CONFIG_UPDATED_AT" -v gl="$generation_line" '
    BEGIN { key_written = 0; generation_written = 0 }
    {
      if ($0 ~ "^" k "=") {
        if (key_written == 0) {
          print nl
          key_written = 1
        }
        next
      }

      if ($0 ~ "^" gk "=") {
        if (generation_written == 0) {
          print gl
          generation_written = 1
        }
        next
      }

      print
    }
    END {
      if (key_written == 0) {
        print ""
        print nl
      }
      if (generation_written == 0) {
        print gl
      }
    }
  ' "$CONFIG_FILE" > "$tmp"

  mv "$tmp" "$CONFIG_FILE"
}

config_set() {
  local raw="$1"
  local key="${raw%%=*}"
  local val="${raw#*=}"
  key=$(normalize_key "$key")

  require_config

  # Validate key is a known config key
  local known_keys="JIRA_BASE_URL JIRA_EMAIL JIRA_API_TOKEN JIRA_PROJECT_KEY AZDO_ORG_URL AZDO_PROJECT AZDO_PAT AZDO_TEAM AZDO_REPO AZDO_STORY_TYPE GITHUB_TOKEN GITHUB_ORG GITHUB_REPO TICKET_PREFIX MAIN_BRANCH DEVELOP_BRANCH DEV_FRONTEND_URL DEV_API_URL SIT_FRONTEND_URL SIT_API_URL UAT_FRONTEND_URL UAT_API_URL PRD_FRONTEND_URL PRD_API_URL NOTIFY_WEBHOOK NOTIFY_EMAIL"
  if ! echo "$known_keys" | grep -qw "$key"; then
    warn "Unknown key: $key"
    warn "Known keys: $known_keys"
    # Allow anyway — user may have custom vars
  fi

  with_lock config_set_locked "$key" "$val"
  info "Updated ${key}"
}

# Show the full config (mask the token)
config_show() {
  require_config
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  devpilot config — $CONFIG_FILE${RESET}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""

  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^# ]] && echo -e "${CYAN}${line}${RESET}" && continue
    [[ -z "$line" ]] && echo "" && continue

    # Mask tokens
    if [[ "$line" =~ _TOKEN= ]] || [[ "$line" =~ _PAT= ]] || [[ "$line" =~ _SECRET= ]] || [[ "$line" =~ _PASSWORD= ]]; then
      key="${line%%=*}"
      echo "  ${key}=****** (masked)"
    else
      echo "  ${line}"
    fi
  done < "$CONFIG_FILE"
  echo ""
}

# Validate the ACTIVE tracker's credentials with a real API call (scripts/tracker.sh ping)
config_validate() {
  local root tracker
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  tracker=$(bash "$root/scripts/tracker.sh" configured 2>/dev/null || echo local)
  echo ""
  echo -e "${BOLD}Validating devpilot configuration (tracker: $tracker)...${RESET}"
  echo ""
  if bash "$root/scripts/tracker.sh" ping; then
    echo -e "  ${GREEN}${BOLD}✅ Configuration valid${RESET}"
  else
    echo -e "  ${RED}${BOLD}❌ $tracker is not reachable — fix the values above and re-run${RESET}"
    exit 1
  fi
  if [ -f "$root/scripts/git-host.sh" ]; then bash "$root/scripts/git-host.sh" check || true; fi
  echo ""
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift || true

case "$CMD" in
  get)
    [ -z "${1:-}" ] && error "Usage: devpilot-config.sh get <KEY>"
    config_get "$1"
    ;;
  set)
    [ -z "${1:-}" ] && error "Usage: devpilot-config.sh set KEY=VALUE"
    [[ "$1" != *=* ]] && error "Format must be KEY=VALUE (e.g. jira_api_token=abc123)"
    config_set "$1"
    ;;
  validate)
    config_validate
    ;;
  show)
    config_show
    ;;
  *)
    echo ""
    echo -e "${BOLD}devpilot-config — manage project configuration${RESET}"
    echo ""
    echo "  Usage:"
    echo "    bash scripts/devpilot-config.sh show                       — show all config"
    echo "    bash scripts/devpilot-config.sh get jira_api_token         — read one key"
    echo "    bash scripts/devpilot-config.sh set jira_api_token=<val>   — update one key"
    echo "    bash scripts/devpilot-config.sh set jira_base_url=https://myorg.atlassian.net"
    echo "    bash scripts/devpilot-config.sh validate                   — test the tracker + git host"
    echo ""
    echo "  Common updates:"
    echo "    Rotate Jira token:  bash scripts/devpilot-config.sh set jira_api_token=<new-token>"
    echo "    Set project key:    bash scripts/devpilot-config.sh set jira_project_key=MSK"
    echo "    Azure DevOps PAT:   bash scripts/devpilot-config.sh set azdo_pat=<token>"
    echo "    Set GitHub org:     bash scripts/devpilot-config.sh set github_org=my-org"
    echo ""
    exit 1
    ;;
esac
