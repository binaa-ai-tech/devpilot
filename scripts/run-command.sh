#!/usr/bin/env bash
# =============================================================================
# run-command.sh — Generic AI command runner
#
# Reads .claude/commands/<cmd>.md, substitutes $ARGUMENTS, injects a
# mode-specific preamble, and pipes the prompt to the configured AI CLI.
#
# Usage:
#   bash scripts/run-command.sh ceo "add property search with filters"
#   bash scripts/run-command.sh ceo-fix "sessions table not created on startup"
#   bash scripts/run-command.sh ceo-run MSK-22
#
# Or via convenience wrappers:
#   bash scripts/ceo.sh "add property search with filters"
#   bash scripts/ceo-fix.sh "sessions table not created on startup"
# =============================================================================
set -euo pipefail

CMD="${1:-}"
shift || true
TASK="$*"

# ── Help ───────────────────────────────────────────────────────────────────────
if [ -z "$CMD" ] || [ "$CMD" = "--help" ] || [ "$CMD" = "-h" ]; then
  echo ""
  echo "  Usage: bash scripts/run-command.sh <command> <task description>"
  echo ""
  echo "  Commands:"
  echo "    ceo        Full pipeline — BA → plan → code → QA → PR"
  echo "    ceo-plan   Analysis only — save plan to Jira (no code)"
  echo "    ceo-run    Execute saved plan by Jira KEY (e.g. MSK-22)"
  echo "    ceo-fix    Fast bug fix — no BA, no QA docs"
  echo "    ceo-fe     Frontend agent only"
  echo "    ceo-be     Backend agent only"
  echo "    ceo-db     DB / migration only"
  echo "    ceo-int    Integration / external services only"
  echo ""
  echo "  Config: set runner.cli and runner.model in project.config.md"
  echo "  Or:     /binaa-models to configure via wizard"
  echo ""
  exit 0
fi

# ── Locate command file ────────────────────────────────────────────────────────
COMMAND_FILE=".claude/commands/${CMD}.md"
if [ ! -f "$COMMAND_FILE" ]; then
  echo "❌  Command file not found: $COMMAND_FILE"
  echo "    Available: ceo, ceo-plan, ceo-run, ceo-fix, ceo-fe, ceo-be, ceo-db, ceo-int"
  exit 1
fi

# ── Read runner config from project.config.md ─────────────────────────────────
CLI=$(grep -A 10 '^runner:' project.config.md 2>/dev/null \
  | grep 'cli:' | head -1 \
  | sed 's/.*cli:[[:space:]]*//' | tr -d '"' | tr -d "'" \
  || echo "claude")
[ -z "$CLI" ] && CLI="claude"

MODEL=$(grep -A 10 '^runner:' project.config.md 2>/dev/null \
  | grep 'model:' | head -1 \
  | sed 's/.*model:[[:space:]]*//' | tr -d '"' | tr -d "'" \
  || echo "")

# ── Substitute $ARGUMENTS ──────────────────────────────────────────────────────
# Escape forward slashes and ampersands in TASK for sed
TASK_ESC=$(printf '%s' "$TASK" | sed 's/[\/&]/\\&/g')
PROMPT=$(sed "s/\\\$ARGUMENTS/${TASK_ESC}/g" "$COMMAND_FILE")

# ── Build preamble based on runner ────────────────────────────────────────────
case "$CLI" in
  opencode)
    PREAMBLE="# RUNNER: opencode${MODEL:+ (model: $MODEL)}

You are an AI coding assistant running this devpilot command via opencode.

Execution rules for opencode mode:
- Run all bash/shell commands directly using your bash tool
- Read files using your file reading tools
- Write and edit code directly — do NOT describe spawning subagents; YOU are the implementation agent
- Follow every step in the command below exactly
- For Jira/git scripts: run them with bash as instructed
- For implementation phases: implement the code yourself, following the stack rules in .devpilot/rules.md

---
"
    ;;
  claude)
    PREAMBLE="# RUNNER: Claude Code CLI

You are running this devpilot command via the Claude Code CLI.
Follow every step in the command below exactly.

---
"
    ;;
  *)
    PREAMBLE="# RUNNER: ${CLI}

Follow every step in the command below exactly.
Run bash commands with your shell tool. Read files with your file tool.

---
"
    ;;
esac

FULL_PROMPT="${PREAMBLE}${PROMPT}"

# ── Banner ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  /${CMD}"
if [ -n "$TASK" ]; then
  echo "  Task:  $TASK"
fi
echo "  AI:    ${CLI}${MODEL:+ ($MODEL)}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Invoke AI CLI ──────────────────────────────────────────────────────────────
case "$CLI" in
  opencode)
    if [ -n "$MODEL" ]; then
      printf '%s' "$FULL_PROMPT" | opencode --model "$MODEL"
    else
      printf '%s' "$FULL_PROMPT" | opencode
    fi
    ;;
  claude)
    printf '%s' "$FULL_PROMPT" | claude
    ;;
  *)
    # Custom CLI — pipe prompt to stdin
    printf '%s' "$FULL_PROMPT" | eval "$CLI"
    ;;
esac
