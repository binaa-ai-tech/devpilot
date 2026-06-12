#!/usr/bin/env bash
# =============================================================================
# jira-guard.sh — the hard gate for the tracker ceremony.
#
# DevPilot's process contract (.devpilot/process.md) requires every planned
# item to land in the tracker as Epic→Story BEFORE any code is written, and
# gates are "enforced by skills and scripts, not by discipline alone." The
# Jira-creation gate was previously enforced only by prose in the command
# prompts — so an express /ceo run could focus on the code fix and silently
# skip the ceremony. This script makes the gate executable.
#
# Subcommands:
#   ready                 → prints "jira" | "tracker" | "unconfigured"
#   check                 → exit 0 if the tracker can accept issues; non-zero +
#                           a human reason if Jira is selected but unconfigured.
#   assert-key <KEY...>   → exit 0 if at least one well-formed issue key was
#                           produced by the PLAN phase; non-zero (loud) if not.
#                           Echoes the count of valid keys on success.
#   hotfix-gate <intent> <severity>
#                         → exit non-zero (block) when a P0/P1 bug is being
#                           planned/built through /ceo or /dp-plan — those belong
#                           on the expedited /dp-hotfix lane. exit 0 otherwise.
#
# Usage:
#   bash scripts/jira-guard.sh check
#   STORY_KEYS="MSK-50 MSK-51"
#   bash scripts/jira-guard.sh assert-key $STORY_KEYS
#   bash scripts/jira-guard.sh hotfix-gate bug P1
# =============================================================================
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_FILE="$ROOT/.devpilot/config.sh"

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; BOLD="\033[1m"; RESET="\033[0m"

# Which tracker is this repo wired to? (default jira)
TRACKER=$(grep -A 3 '^tracker:' "$ROOT/project.config.md" 2>/dev/null \
  | grep -E '^[[:space:]]*type:' | head -1 \
  | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
TRACKER="${TRACKER:-jira}"

# A well-formed Jira/tracker issue key, e.g. MSK-50, PROJ_X-1234.
KEY_RE='^[A-Z][A-Z0-9_]*-[0-9]+$'

jira_configured() {
  [ -f "$CONFIG_FILE" ] || return 1
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
  for var in JIRA_BASE_URL JIRA_EMAIL JIRA_API_TOKEN JIRA_PROJECT_KEY; do
    val="${!var:-}"
    { [ -z "$val" ] || [[ "$val" =~ ^YOUR_ ]] || [[ "$val" =~ example\.com ]]; } && return 1
  done
  return 0
}

cmd="${1:-}"; shift || true

case "$cmd" in
  ready)
    if [ "$TRACKER" != "jira" ]; then
      echo "tracker"
    elif jira_configured; then
      echo "jira"
    else
      echo "unconfigured"
    fi
    ;;

  check)
    # Non-jira trackers manage their own configuration via track.sh — the gate
    # still applies (assert-key), but there's nothing to check here.
    [ "$TRACKER" != "jira" ] && { echo "✅ Tracker '$TRACKER' active — ceremony enforced via track.sh."; exit 0; }
    if jira_configured; then
      echo -e "${GREEN}✅ Jira is configured — the PLAN phase MUST create the issue before any code.${RESET}"
      exit 0
    fi
    echo -e "${RED}${BOLD}❌ Jira is selected as the tracker but not configured.${RESET}" >&2
    echo -e "   Set the four required values, then re-run:" >&2
    echo -e "     bash scripts/devpilot-config.sh set jira_base_url=https://<org>.atlassian.net" >&2
    echo -e "     bash scripts/devpilot-config.sh set jira_email=<you@org.com>" >&2
    echo -e "     bash scripts/devpilot-config.sh set jira_api_token=<token>" >&2
    echo -e "     bash scripts/devpilot-config.sh set jira_project_key=<KEY>" >&2
    echo -e "   Verify with:  bash scripts/devpilot-config.sh validate" >&2
    exit 1
    ;;

  assert-key)
    valid=0
    for k in "$@"; do
      [[ "$k" =~ $KEY_RE ]] && valid=$((valid + 1))
    done
    if [ "$valid" -ge 1 ]; then
      echo -e "${GREEN}✅ Tracker gate passed — $valid issue key(s) created by PLAN: $*${RESET}"
      exit 0
    fi
    echo -e "${RED}${BOLD}❌ Tracker ceremony was SKIPPED — no issue key was produced.${RESET}" >&2
    echo -e "${YELLOW}   /ceo and /dp-plan MUST write the item to the tracker (Epic→Story) BEFORE any code.${RESET}" >&2
    echo -e "${YELLOW}   Do NOT build, branch, or write code. Go back and run the PLAN phase:${RESET}" >&2
    echo -e "     • UNRELATED → bash scripts/create-jira-epic.sh \"<epic>\" \"<goal>\"  then a child Story" >&2
    echo -e "     • RELATED   → bash scripts/create-jira-epic.sh \"<summary>\" \"<story>\" <EPIC_KEY>" >&2
    echo -e "   The verdict (DUPLICATE/FOLD-IN) is the only path with no NEW key — and it still" >&2
    echo -e "   resolves to an existing key. A truly empty result means the ceremony was skipped." >&2
    exit 1
    ;;

  hotfix-gate)
    intent="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
    severity="$(printf '%s' "${2:-}" | tr '[:lower:]' '[:upper:]')"
    if { [ "$intent" = "bug" ] || [ "$intent" = "issue" ]; } \
       && { [ "$severity" = "P0" ] || [ "$severity" = "P1" ]; }; then
      echo -e "${RED}${BOLD}❌ STOP — $severity bug must not go through /ceo or /dp-plan.${RESET}" >&2
      echo -e "${YELLOW}   A production-critical defect takes the expedited /dp-hotfix lane:${RESET}" >&2
      echo -e "     • branches from \`main\` (not develop), ships to PRD behind a manual gate" >&2
      echo -e "     • minimal diff, then a blameless postmortem (.devpilot/skills/incident-postmortem.md)" >&2
      echo -e "   Run:  /dp-hotfix <ticket> <slug> <version>   (see .devpilot/process.md)" >&2
      exit 1
    fi
    exit 0
    ;;

  *)
    echo "Usage: jira-guard.sh {ready | check | assert-key <KEY...> | hotfix-gate <intent> <severity>}" >&2
    exit 1
    ;;
esac
