#!/usr/bin/env bash
# =============================================================================
# smoke.sh — is the environment up after a deploy?
#
#   bash scripts/smoke.sh <dev|sit|uat|prd>
#
# Checks <ENV>_API_URL + SMOKE_API_PATH (default /health) and <ENV>_FRONTEND_URL,
# retrying while the new version starts (SMOKE_RETRIES=10 × SMOKE_DELAY=15s).
# URLs come from the environment (pipeline variables) or .devpilot/config.sh.
# No URL configured → warns and passes (nothing to check), never fakes a result.
# =============================================================================
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
UP=$(printf '%s' "${1:?Usage: smoke.sh <dev|sit|uat|prd>}" | tr '[:lower:]' '[:upper:]')

API_VAR="${UP}_API_URL"; FE_VAR="${UP}_FRONTEND_URL"
API="${!API_VAR:-}"; FE="${!FE_VAR:-}"
if { [ -z "$API" ] || [ -z "$FE" ]; } && [ -f "$ROOT/.devpilot/config.sh" ]; then
  # shellcheck source=/dev/null
  CFG_API=$(. "$ROOT/.devpilot/config.sh" 2>/dev/null; echo "${!API_VAR:-}")
  # shellcheck source=/dev/null
  CFG_FE=$(. "$ROOT/.devpilot/config.sh" 2>/dev/null; echo "${!FE_VAR:-}")
  API="${API:-$CFG_API}"; FE="${FE:-$CFG_FE}"
fi

case "$API" in '$('*) API="" ;; esac   # Azure leaves undefined $(VAR) as literal text
case "$FE" in '$('*) FE="" ;; esac
TRIES="${SMOKE_RETRIES:-10}"; DELAY="${SMOKE_DELAY:-15}"
check() {  # check <label> <url>
  local i code
  for i in $(seq 1 "$TRIES"); do
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$2" 2>/dev/null)
    case "$code" in 2*|3*) echo "  ✅ $1 $2 (HTTP $code)"; return 0 ;; esac
    [ "$i" -lt "$TRIES" ] && sleep "$DELAY"
  done
  echo "  ❌ $1 $2 (HTTP ${code:-000} after $TRIES tries)"; return 1
}

RC=0; CHECKED=0
[ -n "$API" ] && { CHECKED=1; check "API" "${API%/}${SMOKE_API_PATH:-/health}" || RC=1; }
[ -n "$FE" ]  && { CHECKED=1; check "web" "$FE" || RC=1; }
[ "$CHECKED" = 0 ] && echo "  ⚠️  smoke skipped — set ${UP}_API_URL / ${UP}_FRONTEND_URL (pipeline variables or .devpilot/config.sh)"
exit $RC
