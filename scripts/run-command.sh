#!/usr/bin/env bash
# =============================================================================
# run-command.sh — Generic AI command runner
#
# Reads .claude/commands/<cmd>.md, substitutes $ARGUMENTS, injects a
# runner-specific preamble, and pipes the prompt to the configured AI CLI.
#
# Supported runners: claude | opencode | antigravity | custom
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
  echo "  Config: set engines.runner in project.config.md"
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

# ── Read config from project.config.md ────────────────────────────────────────
_read_config() {
  local section="$1" key="$2"
  
  # Try python3 parser first if available
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$section" "$key" <<'PY' 2>/dev/null
import sys, re

def get_value(section, key):
    try:
        with open('project.config.md', 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception:
        return ""
        
    current_section = None
    section_indent = -1
    
    for line in lines:
        line_clean = re.sub(r'#.*$', '', line).rstrip()
        if not line_clean.strip():
            continue
            
        m = re.match(r'^(\s*)(\w+):\s*(.*)$', line_clean)
        if m:
            indent, k, v = m.groups()
            indent_len = len(indent)
            v = v.strip()
            
            if not section:
                if indent_len == 0 and k == key:
                    return v.strip('{}[]"\' ')
                continue
                
            if k == section:
                current_section = section
                section_indent = indent_len
                continue
                
            if current_section is not None:
                if indent_len <= section_indent:
                    if k != section:
                        current_section = None
                        section_indent = -1
                
                if current_section is not None and k == key:
                    v_clean = v.strip('{}[]"\' ')
                    if 'enabled:' in v_clean:
                        enabled_match = re.search(r'enabled:\s*(\w+)', v_clean)
                        if enabled_match:
                            return enabled_match.group(1)
                    return v_clean
    return ""

if __name__ == '__main__':
    sec = sys.argv[1] if len(sys.argv) > 1 else ""
    k = sys.argv[2] if len(sys.argv) > 2 else ""
    print(get_value(sec, k))
PY
    return
  fi

  # Fallback: Robust strict structured text boundary tracking in pure Bash
  local in_section=0
  local section_indent=-1
  local value=""

  while IFS= read -r line || [ -n "$line" ]; do
    local line_clean
    line_clean=$(echo "$line" | sed 's/#.*$//' | sed 's/[[:space:]]*$//')
    [ -z "$line_clean" ] && continue

    if [[ "$line_clean" =~ ^([[:space:]]*)([a-zA-Z0-9_]+):[[:space:]]*(.*)$ ]]; then
      local indent="${BASH_REMATCH[1]}"
      local k="${BASH_REMATCH[2]}"
      local v="${BASH_REMATCH[3]}"
      local indent_len=${#indent}

      if [ -z "$section" ]; then
        if [ "$indent_len" -eq 0 ] && [ "$k" = "$key" ]; then
          value=$(echo "$v" | tr -d '"' | tr -d "'" | tr -d '{}' | tr -d ' ' | tr -d '[]')
          echo "$value"
          return 0
        fi
        continue
      fi

      if [ "$k" = "$section" ]; then
        in_section=1
        section_indent=$indent_len
        continue
      fi

      if [ $in_section -eq 1 ]; then
        if [ "$indent_len" -le "$section_indent" ]; then
          if [ "$k" != "$section" ]; then
            in_section=0
            section_indent=-1
          fi
        fi
        if [ $in_section -eq 1 ] && [ "$k" = "$key" ]; then
          v=$(echo "$v" | sed "s/^[[:space:]]*//" | sed "s/[[:space:]]*$//")
          if [[ "$v" =~ enabled:[[:space:]]*(true|false) ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
          fi
          value=$(echo "$v" | tr -d '"' | tr -d "'" | tr -d '{}' | tr -d '[]')
          echo "$value"
          return 0
        fi
      fi
    fi
  done < project.config.md
  echo ""
}

RUNNER=$(_read_config "engines" "runner")
[ -z "$RUNNER" ] && RUNNER="claude"

CODING=$(_read_config "engines" "coding")
[ -z "$CODING" ] && CODING="claude"

# Claude entry-point coupling: when the command is launched via Claude Code,
# the whole lifecycle stays on the Claude model family. Per-layer exceptions are
# applied later by scripts/resolve-engine.sh (layer_overrides).
LAYER_NOTE=""
if [ "$RUNNER" = "claude" ] && [ "$CODING" != "claude" ]; then
  CODING="claude"
fi
if [ "$RUNNER" = "claude" ] && grep -A 6 '^layer_overrides:' project.config.md 2>/dev/null \
     | grep -qE '^[[:space:]]+(frontend|backend|db|integration):[[:space:]]*"(opencode|antigravity)"'; then
  LAYER_NOTE=" (+ active layer_overrides)"
fi

# Runner model — for opencode/antigravity, read from coding_models section
# (runner uses same model as coding engine by default)
RUNNER_MODEL=""
if [ "$RUNNER" = "opencode" ]; then
  RUNNER_MODEL=$(_read_config "opencode" "backend")
elif [ "$RUNNER" = "antigravity" ]; then
  RUNNER_MODEL=$(_read_config "antigravity" "backend")
fi

# ── Substitute $ARGUMENTS ──────────────────────────────────────────────────────
TASK_ESC=$(printf '%s' "$TASK" | sed 's/[\/&]/\\&/g')
PROMPT=$(sed "s/\\\$ARGUMENTS/${TASK_ESC}/g" "$COMMAND_FILE")

# ── Build preamble based on runner ────────────────────────────────────────────
case "$RUNNER" in
  opencode)
    PREAMBLE="# RUNNER: opencode${RUNNER_MODEL:+ (model: $RUNNER_MODEL)}
# CODING ENGINE: ${CODING}

You are an AI coding assistant running this devpilot command via opencode.

Execution rules:
- Run all bash/shell commands directly using your bash tool
- Read files using your file reading tools
- Write and edit code directly — do NOT describe spawning subagents; YOU are the implementation agent
- Follow every step in the command below exactly
- For Jira/git scripts: run them with bash as instructed
- For implementation phases: implement the code yourself, following .devpilot/rules.md

---
"
    ;;
  antigravity)
    PREAMBLE="# RUNNER: antigravity${RUNNER_MODEL:+ (model: $RUNNER_MODEL)}
# CODING ENGINE: ${CODING}

You are an AI coding assistant running this devpilot command via antigravity.

Execution rules:
- Run all bash/shell commands directly using your bash tool
- Read files using your file reading tools
- Write and edit code directly — do NOT describe spawning subagents; YOU are the implementation agent
- Follow every step in the command below exactly
- For Jira/git scripts: run them with bash as instructed
- For implementation phases: implement the code yourself, following .devpilot/rules.md

---
"
    ;;
  claude)
    PREAMBLE="# RUNNER: Claude Code CLI
# CODING ENGINE: ${CODING}${LAYER_NOTE}

You are running this devpilot command via the Claude Code CLI.
All downstream phases, sub-agents, and LLM calls use the Claude model family.
Exception: layers listed in layer_overrides (project.config.md) route to the
engine resolved by 'bash scripts/resolve-engine.sh layer <layer>'. Call it
before each implementation phase to get the correct engine + model per layer.
Follow every step in the command below exactly.

---
"
    ;;
  *)
    PREAMBLE="# RUNNER: ${RUNNER}
# CODING ENGINE: ${CODING}

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
  echo "  Task:   $TASK"
fi
echo "  Runner: ${RUNNER}${RUNNER_MODEL:+ ($RUNNER_MODEL)}"
echo "  Coding: ${CODING}${LAYER_NOTE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Invoke AI CLI ──────────────────────────────────────────────────────────────
case "$RUNNER" in
  opencode)
    if [ -n "$RUNNER_MODEL" ]; then
      printf '%s' "$FULL_PROMPT" | opencode --model "$RUNNER_MODEL"
    else
      printf '%s' "$FULL_PROMPT" | opencode
    fi
    ;;
  antigravity)
    if [ -n "$RUNNER_MODEL" ]; then
      printf '%s' "$FULL_PROMPT" | antigravity --model "$RUNNER_MODEL"
    else
      printf '%s' "$FULL_PROMPT" | antigravity
    fi
    ;;
  claude)
    printf '%s' "$FULL_PROMPT" | claude
    ;;
  *)
    printf '%s' "$FULL_PROMPT" | eval "$RUNNER"
    ;;
esac
