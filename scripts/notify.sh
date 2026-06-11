#!/usr/bin/env bash
# =============================================================================
# notify.sh <event> <message…> — best-effort notifications. NEVER blocks a flow:
# always exits 0, whether delivery worked, failed, or nothing is configured.
#
#   bash scripts/notify.sh done    "Sprint 1 built → PR #42"
#   bash scripts/notify.sh blocked "QA BLOCKED: KEY-12 — AC-3 has no passing test"
#
# Channels (set in .devpilot/config.sh — gitignored):
#   NOTIFY_WEBHOOK — Slack/Teams/Discord-compatible webhook (JSON {"text": …})
#   NOTIFY_EMAIL   — used when a local `mail` command exists
# Every event is also appended to docs/tasks/notifications.log as the durable record.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0

EVENT="${1:-info}"; shift || true
MSG="${*:-}"
[ -z "$MSG" ] && exit 0

# shellcheck disable=SC1091
[ -f .devpilot/config.sh ] && source .devpilot/config.sh 2>/dev/null

STAMP=$(date '+%Y-%m-%d %H:%M:%S')
mkdir -p docs/tasks
printf '%s [%s] %s\n' "$STAMP" "$EVENT" "$MSG" >> docs/tasks/notifications.log

WEBHOOK="${NOTIFY_WEBHOOK:-}"
case "$WEBHOOK" in *example.com*|"") WEBHOOK="" ;; esac
if [ -n "$WEBHOOK" ]; then
  # Escape backslashes and double quotes for the JSON payload.
  ESC=$(printf '%s' "[devpilot][$EVENT] $MSG" | sed 's/\\/\\\\/g; s/"/\\"/g')
  curl -fsS -X POST -H 'Content-Type: application/json' \
       -d "{\"text\":\"$ESC\"}" --max-time 10 "$WEBHOOK" >/dev/null 2>&1 \
    && echo "🔔 webhook notified ($EVENT)" \
    || echo "⚠️  webhook notify failed (non-blocking) — check NOTIFY_WEBHOOK"
fi

EMAIL="${NOTIFY_EMAIL:-}"
case "$EMAIL" in *example.com*|"") EMAIL="" ;; esac
if [ -n "$EMAIL" ] && command -v mail >/dev/null 2>&1; then
  printf '%s\n' "$MSG" | mail -s "[devpilot][$EVENT] $(basename "$ROOT")" "$EMAIL" >/dev/null 2>&1 \
    && echo "🔔 email notified ($EVENT)" \
    || echo "⚠️  email notify failed (non-blocking)"
fi

exit 0
