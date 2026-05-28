#!/usr/bin/env bash
# =============================================================================
# session-start.sh — devpilot SessionStart hook.
#
# Runs at the start of a Claude Code session (web / IDE / CLI) to make sure the
# project is ready to work without a manual warm-up:
#   - devpilot scripts are executable (fresh clones can drop the +x bit)
#   - the project index exists and is reasonably fresh (so BA/scope.sh are fast)
#
# Fast and non-blocking by design. Wire it up in .claude/settings.json:
#   "hooks": { "SessionStart": [ { "hooks": [
#     { "type": "command", "command": "bash scripts/session-start.sh" } ] } ] }
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" 2>/dev/null || exit 0

# Ensure devpilot scripts are runnable.
chmod +x scripts/*.sh 2>/dev/null || true

# Refresh the project index if it's missing or older than ~2h.
if [ ! -f docs/project-index.md ] || ! find docs/project-index.md -mmin -120 2>/dev/null | grep -q .; then
  bash scripts/generate-project-index.sh >/dev/null 2>&1 || true
fi

exit 0
