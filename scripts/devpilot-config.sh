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
# All values live in .devpilot/config.sh (gitignored).
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
  local known_keys="JIRA_BASE_URL JIRA_EMAIL JIRA_API_TOKEN JIRA_PROJECT_KEY GITHUB_ORG GITHUB_REPO TICKET_PREFIX MAIN_BRANCH DEVELOP_BRANCH DEV_FRONTEND_URL DEV_API_URL SIT_FRONTEND_URL SIT_API_URL UAT_FRONTEND_URL UAT_API_URL PRD_FRONTEND_URL PRD_API_URL NOTIFY_EMAIL"
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
    if [[ "$line" =~ _TOKEN= ]] || [[ "$line" =~ _SECRET= ]] || [[ "$line" =~ _PASSWORD= ]]; then
      key="${line%%=*}"
      echo "  ${key}=****** (masked)"
    else
      echo "  ${line}"
    fi
  done < "$CONFIG_FILE"
  echo ""
}

# Validate Jira credentials by making a real API call
config_validate() {
  require_config
  source "$CONFIG_FILE"

  echo ""
  echo -e "${BOLD}Validating devpilot configuration...${RESET}"
  echo ""

  local ok=true

  # Check required fields
  for var in JIRA_BASE_URL JIRA_EMAIL JIRA_API_TOKEN JIRA_PROJECT_KEY GITHUB_ORG GITHUB_REPO; do
    val="${!var:-}"
    if [ -z "$val" ] || [[ "$val" =~ ^YOUR_ ]] || [[ "$val" =~ example\.com ]]; then
      echo -e "  ${RED}✗${RESET} ${var}: not set (still has placeholder value)"
      ok=false
    else
      if [[ "$var" =~ _TOKEN ]] || [[ "$var" =~ _SECRET ]]; then
        echo -e "  ${GREEN}✓${RESET} ${var}: set (masked)"
      else
        echo -e "  ${GREEN}✓${RESET} ${var}: ${val}"
      fi
    fi
  done

  echo ""

  # Test Jira API connection
  if [ "${JIRA_BASE_URL:-}" != "" ] && [[ ! "${JIRA_BASE_URL:-}" =~ YOUR_ ]]; then
    echo -n "  Testing Jira API connection... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --url "${JIRA_BASE_URL}/rest/api/3/myself" \
      --user "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
      --header "Accept: application/json" \
      --max-time 10 2>/dev/null || echo "000")

    case "$HTTP_CODE" in
      200)
        echo -e "${GREEN}✓ Connected (HTTP 200)${RESET}"
        ;;
      401)
        echo -e "${RED}✗ Unauthorized (HTTP 401) — check JIRA_EMAIL and JIRA_API_TOKEN${RESET}"
        ok=false
        ;;
      403)
        echo -e "${RED}✗ Forbidden (HTTP 403) — token lacks permission${RESET}"
        ok=false
        ;;
      000)
        echo -e "${YELLOW}⚠ Could not reach ${JIRA_BASE_URL} — check network or URL${RESET}"
        ok=false
        ;;
      *)
        echo -e "${YELLOW}⚠ Unexpected HTTP ${HTTP_CODE}${RESET}"
        ok=false
        ;;
    esac
  fi

  # Test Jira project key
  if [ "${JIRA_PROJECT_KEY:-}" != "" ] && [[ ! "${JIRA_PROJECT_KEY:-}" =~ ^KEY$ ]]; then
    echo -n "  Testing Jira project ${JIRA_PROJECT_KEY}... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --url "${JIRA_BASE_URL}/rest/api/3/project/${JIRA_PROJECT_KEY}" \
      --user "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
      --header "Accept: application/json" \
      --max-time 10 2>/dev/null || echo "000")

    case "$HTTP_CODE" in
      200) echo -e "${GREEN}✓ Project found${RESET}" ;;
      404) echo -e "${RED}✗ Project ${JIRA_PROJECT_KEY} not found${RESET}"; ok=false ;;
      *)   echo -e "${YELLOW}⚠ HTTP ${HTTP_CODE}${RESET}" ;;
    esac
  fi

  echo ""
  if [ "$ok" = true ]; then
    echo -e "  ${GREEN}${BOLD}✅ Configuration valid${RESET}"
  else
    echo -e "  ${RED}${BOLD}❌ Configuration has errors — fix above and re-run${RESET}"
    echo ""
    echo "  Fix with:  bash scripts/devpilot-config.sh set jira_api_token=<new-token>"
    exit 1
  fi
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
    echo "    bash scripts/devpilot-config.sh validate                   — test Jira connection"
    echo ""
    echo "  Common updates:"
    echo "    Rotate Jira token:  bash scripts/devpilot-config.sh set jira_api_token=<new-token>"
    echo "    Set project key:    bash scripts/devpilot-config.sh set jira_project_key=MSK"
    echo "    Set GitHub org:     bash scripts/devpilot-config.sh set github_org=my-org"
    echo ""
    exit 1
    ;;
esac
