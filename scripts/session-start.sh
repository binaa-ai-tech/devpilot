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

# Refresh the project index — hash-gated, so this is a free no-op when the
# repo content is unchanged and an automatic rebuild when it isn't.
bash scripts/generate-project-index.sh >/dev/null 2>&1 || true

exit 0
