#!/usr/bin/env bash
# =============================================================================
# resolve-engine.sh — routing brain for devpilot coding engines + models.
#
# Resolves which engine + model handles a given layer, applying (in order):
#   1. layer_overrides.<layer>      — explicit per-layer engine, wins over all
#   2. engines.coding               — the project default coding engine
#   3. Claude entry-point coupling  — runner=claude forces claude (unless 1)
# Then picks the MODEL:
#   a. layer_models.<layer>         — explicit per-layer model pin (model_mode:
#                                     per-team), wins over the tier system
#   b. coding_models.<engine>.<tier> by task complexity (power | standard | lite)
#
# Engine families:
#   claude   → Claude models (subagents also carry a role default; tiers are the
#              orchestrator balance + escalation target). LAYER_MODEL stays empty.
#   opencode → GitHub Copilot models. If Copilot is NOT available in opencode,
#              falls back to coding_models.opencode.fallback, or to opencode's own
#              default model (empty → no --model passed).
#
# Subcommands:
#   resolve-engine.sh layer <frontend|backend|db|integration> [power|standard|lite]
#       → prints:  LAYER_ENGINE=<engine>
#                  LAYER_MODEL=<model-or-empty>
#   resolve-engine.sh effective         → RUNNER=<...>  CODING=<...>  (after coupling)
#   resolve-engine.sh suggest "<task>"  → COMPLEXITY=<high|low>  TIER=<power|standard|lite>  SUGGEST=<...>
#   resolve-engine.sh copilot           → prints "yes"/"no" (is GitHub Copilot usable in opencode?)
#
# All reads come from project.config.md at the repo root.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/project.config.md"

# ── config readers (grep-based, consistent with the rest of devpilot) ──────────
cfg_under() {
  local parent="$1" key="$2" win="${3:-12}"
  [ -f "$CONFIG" ] || return 0
  grep -A "$win" "^${parent}:" "$CONFIG" 2>/dev/null \
    | grep -E "^[[:space:]]+${key}:" | head -1 \
    | sed "s/.*${key}:[[:space:]]*//; s/#.*//" | tr -d '"' | awk '{print $1}'
}

# two levels deep:  cfg_deep <grandparent> <parent> <key>
# e.g. coding_models: > opencode: > standard:
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

# ── is GitHub Copilot usable in opencode? ──────────────────────────────────────
# Tolerant across opencode versions: check auth list, then model list, for a
# github-copilot provider. Cache the result in an env-export-friendly way.
copilot_available() {
  command -v opencode >/dev/null 2>&1 || return 1
  if opencode auth list 2>/dev/null | grep -qiE 'github[ -]?copilot'; then return 0; fi
  if opencode models    2>/dev/null | grep -qiE 'github-copilot/'; then return 0; fi
  if opencode model list 2>/dev/null | grep -qiE 'github-copilot/'; then return 0; fi
  return 1
}

# ── effective runner / coding after Claude-entry coupling ──────────────────────
resolve_effective() {
  local runner coding
  runner="$(cfg_under engines runner)";  [ -z "$runner" ] && runner="claude"
  coding="$(cfg_under engines coding)";  [ -z "$coding" ] && coding="claude"
  if [ "$runner" = "claude" ]; then coding="claude"; fi
  printf 'RUNNER=%q\nCODING=%q\n' "$runner" "$coding"
}

# normalise a complexity/tier token → power|standard|lite
norm_tier() {
  case "${1:-}" in
    power|high|complex)  echo "power"    ;;
    lite|low|simple)     echo "lite"     ;;
    *)                   echo "standard" ;;
  esac
}

# ── resolve a single layer ─────────────────────────────────────────────────────
resolve_layer() {
  local layer="${1:-}" tier
  tier="$(norm_tier "${2:-standard}")"
  case "$layer" in
    frontend|backend|db|integration) ;;
    *) echo "Usage: resolve-engine.sh layer <frontend|backend|db|integration> [power|standard|lite]" >&2; exit 1 ;;
  esac

  local runner coding override engine model pinned
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

  # Per-layer model pin (model_mode: per-team) — wins over the tier system.
  # For the claude family the same pin lives in .claude/agents/*.md frontmatter;
  # printing it here too keeps non-subagent paths (briefs, fallback) consistent.
  pinned="$(cfg_under layer_models "$layer" 6)"
  if [ -n "$pinned" ]; then
    printf 'LAYER_ENGINE=%q\nLAYER_MODEL=%q\n' "$engine" "$pinned"
    return
  fi

  if [ "$engine" = "claude" ]; then
    # Claude subagents carry their own role-tier model; nothing to pass.
    model=""
  elif [ "${DEVPILOT_LOCAL:-0}" = "1" ]; then
    model="$(cfg_deep coding_models ollama "$tier")"
  else
    model="$(cfg_deep coding_models "$engine" "$tier")"
    # GitHub Copilot fallback: if the resolved model is a Copilot model but
    # Copilot isn't usable in opencode, use the configured fallback, or empty
    # (→ opencode runs with its own default model, no --model).
    if [ "$engine" = "opencode" ] && printf '%s' "$model" | grep -qiE '^github-copilot/'; then
      if ! copilot_available; then
        model="$(cfg_deep coding_models opencode fallback)"
        echo "ℹ️  GitHub Copilot unavailable in opencode → using ${model:-opencode default model}" >&2
      fi
    fi
  fi

  printf 'LAYER_ENGINE=%q\nLAYER_MODEL=%q\n' "$engine" "$model"
}

# ── advisory model suggestion based on task complexity ─────────────────────────
resolve_suggest() {
  local task="${*:-}"
  local words complex=0 tier
  words=$(printf '%s' "$task" | wc -w | tr -d ' ')
  if printf '%s' "$task" | grep -qiE 'architect|refactor|migrat|redesign|schema|concurren|distributed|security|performance|multiple|across (layers|services)'; then
    complex=1
  fi
  [ "${words:-0}" -gt 40 ] && complex=1

  local runner; runner="$(cfg_under engines runner)"; [ -z "$runner" ] && runner="claude"
  [ "$runner" = "claude" ] && family="claude" || family="$runner"

  if [ "$complex" = "1" ]; then
    tier="power"; echo "COMPLEXITY=high"
  else
    tier="standard"; echo "COMPLEXITY=low"
  fi
  echo "TIER=$tier"

  local m; m="$(cfg_deep coding_models "$family" "$tier")"
  echo "SUGGEST=${family}: ${m:-<default>} ($tier tier)"
}

# ── dispatch ───────────────────────────────────────────────────────────────────
CMD="${1:-}"; shift || true
case "$CMD" in
  layer)     resolve_layer "$@" ;;
  effective) resolve_effective ;;
  suggest)   resolve_suggest "$@" ;;
  copilot)   copilot_available && echo "yes" || echo "no" ;;
  *)
    echo "Usage: resolve-engine.sh <layer <name> [tier] | effective | suggest \"<task>\" | copilot>" >&2
    exit 1
    ;;
esac
