#!/usr/bin/env bash
# =============================================================================
# resolve-engine.sh — routing brain for devpilot coding engines.
#
# Resolves which engine + model handles a given layer, applying (in order):
#   1. layer_overrides.<layer>      — explicit per-layer engine, wins over all
#   2. engines.coding               — the project default coding engine
#   3. Claude entry-point coupling  — runner=claude forces claude (unless 1)
# Then picks the model for the resolved engine from coding_models.<engine>.<layer>
# (or coding_models.ollama.<layer> when DEVPILOT_LOCAL=1 and engine != claude).
#
# Subcommands:
#   resolve-engine.sh layer <frontend|backend|db|integration>
#       → prints:  LAYER_ENGINE=<engine>
#                  LAYER_MODEL=<model-or-empty>
#       (eval-able; claude never needs a model id)
#
#   resolve-engine.sh effective
#       → prints:  RUNNER=<...>  CODING=<...>  (after coupling)
#
#   resolve-engine.sh suggest "<task text>"
#       → prints a complexity verdict + suggested model tier (advisory only)
#
# All reads come from project.config.md at the repo root.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/project.config.md"

# ── config readers (grep-based, consistent with the rest of devpilot) ──────────
# top-level key:  cfg_top <key>
cfg_top() {
  [ -f "$CONFIG" ] || return 0
  grep -E "^$1:" "$CONFIG" 2>/dev/null | head -1 \
    | sed "s/^$1:[[:space:]]*//; s/#.*//" | tr -d '"' | awk '{print $1}'
}

# nested one level under a parent block:  cfg_under <parent> <key> [grep-window]
cfg_under() {
  local parent="$1" key="$2" win="${3:-12}"
  [ -f "$CONFIG" ] || return 0
  grep -A "$win" "^${parent}:" "$CONFIG" 2>/dev/null \
    | grep -E "^[[:space:]]+${key}:" | head -1 \
    | sed "s/.*${key}:[[:space:]]*//; s/#.*//" | tr -d '"' | awk '{print $1}'
}

# two levels deep:  cfg_deep <grandparent> <parent> <key>
# e.g. coding_models: > opencode: > backend:
cfg_deep() {
  local gp="$1" parent="$2" key="$3"
  [ -f "$CONFIG" ] || return 0
  awk -v gp="$gp" -v parent="$parent" -v key="$key" '
    $0 ~ "^"gp":" { ingp=1; next }
    ingp && $0 ~ "^[^[:space:]]" { ingp=0 }                 # left grandparent
    ingp && $0 ~ "^[[:space:]]+"parent":" { inp=1; next }
    ingp && inp && $0 ~ "^[[:space:]][[:space:]]?[a-zA-Z]" { inp=0 }  # next sibling block
    ingp && inp && $0 ~ "^[[:space:]]+"key":" {
      sub(".*"key":[[:space:]]*", ""); sub(/#.*/, ""); gsub(/[",]/, ""); split($0,a," "); print a[1]; exit
    }
  ' "$CONFIG"
}

# ── effective runner / coding after Claude-entry coupling ──────────────────────
resolve_effective() {
  local runner coding
  runner="$(cfg_under engines runner)";  [ -z "$runner" ] && runner="claude"
  coding="$(cfg_under engines coding)";  [ -z "$coding" ] && coding="claude"
  # Claude entry-point: keep the whole lifecycle on the Claude family.
  if [ "$runner" = "claude" ]; then
    coding="claude"
  fi
  printf 'RUNNER=%q\nCODING=%q\n' "$runner" "$coding"
}

# ── resolve a single layer ─────────────────────────────────────────────────────
resolve_layer() {
  local layer="${1:-}"
  case "$layer" in
    frontend|backend|db|integration) ;;
    *) echo "Usage: resolve-engine.sh layer <frontend|backend|db|integration>" >&2; exit 1 ;;
  esac

  local runner coding override engine model
  runner="$(cfg_under engines runner)";  [ -z "$runner" ] && runner="claude"
  coding="$(cfg_under engines coding)";  [ -z "$coding" ] && coding="claude"
  override="$(cfg_under layer_overrides "$layer" 6)"

  if [ -n "$override" ]; then
    engine="$override"                      # explicit override wins over everything
  elif [ "$runner" = "claude" ]; then
    engine="claude"                         # Claude entry-point coupling
  else
    engine="$coding"
  fi

  if [ "$engine" = "claude" ]; then
    model=""                                # Claude subagents pick their own tier model
  elif [ "${DEVPILOT_LOCAL:-0}" = "1" ]; then
    model="$(cfg_deep coding_models ollama "$layer")"
  else
    model="$(cfg_deep coding_models "$engine" "$layer")"
  fi

  printf 'LAYER_ENGINE=%q\nLAYER_MODEL=%q\n' "$engine" "$model"
}

# ── advisory model suggestion based on task complexity ─────────────────────────
resolve_suggest() {
  local task="${*:-}"
  local words complex=0
  words=$(printf '%s' "$task" | wc -w | tr -d ' ')
  # heuristic: architectural / cross-cutting work → heavier model
  if printf '%s' "$task" | grep -qiE 'architect|refactor|migrat|redesign|schema|concurren|distributed|security|performance|multiple|across (layers|services)'; then
    complex=1
  fi
  [ "${words:-0}" -gt 40 ] && complex=1

  local runner; runner="$(cfg_under engines runner)"; [ -z "$runner" ] && runner="claude"

  if [ "$complex" = "1" ]; then
    echo "COMPLEXITY=high"
    if [ "$runner" = "claude" ]; then
      echo "SUGGEST=claude-sonnet-4-6 (deep reasoning tier)"
    else
      echo "SUGGEST=${runner}: strongest available model (e.g. github-copilot/gpt-4o)"
    fi
  else
    echo "COMPLEXITY=low"
    if [ "$runner" = "claude" ]; then
      echo "SUGGEST=claude-haiku-4-5 (fast/cheap tier)"
    elif [ "${DEVPILOT_LOCAL:-0}" = "1" ]; then
      echo "SUGGEST=${runner}: local Ollama model (coding_models.ollama.*)"
    else
      echo "SUGGEST=${runner}: fast/cheap model (e.g. github-copilot/gpt-3.5-codex)"
    fi
  fi
}

# ── dispatch ───────────────────────────────────────────────────────────────────
CMD="${1:-}"; shift || true
case "$CMD" in
  layer)     resolve_layer "$@" ;;
  effective) resolve_effective ;;
  suggest)   resolve_suggest "$@" ;;
  *)
    echo "Usage: resolve-engine.sh <layer <name> | effective | suggest \"<task>\">" >&2
    exit 1
    ;;
esac
