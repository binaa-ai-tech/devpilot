#!/usr/bin/env bash
# =============================================================================
# model-profiles.sh — named Claude model presets for devpilot ("powerful + easy").
#
# A *profile* is a one-word preset over the power/standard/lite tiers that the
# per-task router (resolve-model.sh) understands. The user picks one profile;
# per-task tier selection keeps working unchanged — the profile only decides
# which Claude model each tier resolves to.
#
#   auto      power=opus    standard=sonnet  lite=haiku   ← Opus for hard tasks (default)
#   balanced  power=sonnet  standard=sonnet  lite=haiku   ← no Opus, solid everywhere
#   save      power=sonnet  standard=haiku   lite=haiku   ← token-saving; Sonnet only when complex
#
# Usage
#   model-profiles.sh claude-map <auto|balanced|save>  → POWER/STANDARD/LITE + BA/LEAD/QA
#   model-profiles.sh apply  <profile>                 → write project.config.md + agent frontmatter
#   model-profiles.sh single <model-id>                → ONE model for the whole team
#   model-profiles.sh sync-agents                      → re-apply models.* to .claude/agents/*.md
#   model-profiles.sh show                             → current profile + tiers
# (`apply claude <profile>` / `single claude <model>` are accepted for compatibility.)
#
# Model modes (recorded as model_policy.model_mode):
#   recommended — task-balanced tiers via a named profile (apply …)
#   single      — one model everywhere (single …)
#   per-team    — per-role models: edit models.* in project.config.md, then sync-agents
#
# NOTE: the profile table below is also inlined in install.sh — keep them in sync.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/project.config.md"

# ── Claude model ids (single source of truth) ──────────────────────────────────
CL_OPUS="claude-opus-5-5"
CL_SONNET="claude-sonnet-5"
CL_HAIKU="claude-haiku-4-5-20251001"

# ── Claude profile → tier + orchestrator models ────────────────────────────────
claude_map() {
  local profile="${1:-auto}"
  local P S L BA LEAD QA
  case "$profile" in
    auto)     P="$CL_OPUS";   S="$CL_SONNET"; L="$CL_HAIKU"; BA="$CL_HAIKU"; LEAD="$CL_SONNET"; QA="$CL_HAIKU" ;;
    balanced) P="$CL_SONNET"; S="$CL_SONNET"; L="$CL_HAIKU"; BA="$CL_HAIKU"; LEAD="$CL_SONNET"; QA="$CL_HAIKU" ;;
    save)     P="$CL_SONNET"; S="$CL_HAIKU";  L="$CL_HAIKU"; BA="$CL_HAIKU"; LEAD="$CL_HAIKU";  QA="$CL_HAIKU" ;;
    *) echo "Unknown Claude profile: $profile (use auto|balanced|save)" >&2; return 1 ;;
  esac
  printf 'POWER=%s\nSTANDARD=%s\nLITE=%s\nBA=%s\nLEAD=%s\nQA=%s\n' "$P" "$S" "$L" "$BA" "$LEAD" "$QA"
}

# ── project.config.md writers ───────────────────────────────────────────────────
require_config() { [ -f "$CONFIG" ] || { echo "project.config.md not found at $ROOT" >&2; exit 1; }; }

# Replace power/standard/lite under coding_models.<family> (family = claude)
_set_coding_tiers() {
  local fam="$1" P="$2" S="$3" L="$4" tmp
  tmp="$(mktemp "${CONFIG}.tmp.XXXXXX")"
  awk -v fam="$fam" -v P="$P" -v S="$S" -v L="$L" '
    function emit(key, val,   k, pad, s, i) {
      k = key ":"; pad = 10 - length(k); if (pad < 1) pad = 1
      s = ""; for (i = 0; i < pad; i++) s = s " "
      printf "    %s%s\"%s\"\n", k, s, val
    }
    /^coding_models:/ { ingp = 1; print; next }
    ingp && /^[^[:space:]#]/ { ingp = 0; inf = 0 }              # column-0 line → left block
    ingp && $0 ~ ("^  " fam ":[[:space:]]*$") { inf = 1; print; next }
    ingp && inf && /^  [A-Za-z]/ && $0 !~ /^    / { inf = 0 }   # next 2-space sibling family
    ingp && inf && /^    power:/    { emit("power",    P); next }
    ingp && inf && /^    standard:/ { emit("standard", S); next }
    ingp && inf && /^    lite:/     { emit("lite",     L); next }
    { print }
  ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}

# Replace tier1 under models.<agent>
_set_orchestrator_tier1() {
  local agent="$1" model="$2" tmp
  tmp="$(mktemp "${CONFIG}.tmp.XXXXXX")"
  awk -v agent="$agent" -v m="$model" '
    /^models:/ { ingp = 1; print; next }
    ingp && /^[^[:space:]#]/ { ingp = 0; inf = 0 }
    ingp && $0 ~ ("^  " agent ":[[:space:]]*$") { inf = 1; print; next }
    ingp && inf && /^  [A-Za-z]/ && $0 !~ /^    / { inf = 0 }
    ingp && inf && /^    tier1:/ { print "    tier1: " m; next }
    { print }
  ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}

# Set or insert model_policy.model_mode (idempotent) — recommended | single | per-team
_set_model_mode() {
  local mode="$1" tmp
  tmp="$(mktemp "${CONFIG}.tmp.XXXXXX")"
  if grep -qE '^[[:space:]]+model_mode:' "$CONFIG"; then
    awk -v m="$mode" '
      !done && /^[[:space:]]+model_mode:/ { print "  model_mode: " m; done = 1; next }
      { print }
    ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  else
    awk -v m="$mode" '
      { print }
      /^model_policy:/ { print "  model_mode: " m }
    ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  fi
}

# Set or insert model_policy.coding_profile (idempotent)
_set_coding_profile() {
  local profile="$1" tmp
  tmp="$(mktemp "${CONFIG}.tmp.XXXXXX")"
  if grep -qE '^[[:space:]]+coding_profile:' "$CONFIG"; then
    # Replace the existing line in place.
    awk -v p="$profile" '
      !done && /^[[:space:]]+coding_profile:/ { print "  coding_profile: " p; done = 1; next }
      { print }
    ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  else
    # Insert right after the model_policy: header.
    awk -v p="$profile" '
      { print }
      /^model_policy:/ { print "  coding_profile: " p }
    ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  fi
}

# Sync .claude/agents/*.md frontmatter model: for orchestrator agents
_sync_agent() {
  local file="$ROOT/.claude/agents/$1" model="$2"
  [ -f "$file" ] && sed -i.bak "s/^model: .*/model: $model/" "$file" && rm -f "$file.bak"
}

# Read models.<agent>.tier1 from project.config.md
_get_orchestrator_tier1() {
  local agent="$1"
  awk -v agent="$agent" '
    /^models:/ { ingp = 1; next }
    ingp && /^[^[:space:]#]/ { ingp = 0; inf = 0 }
    ingp && $0 ~ ("^  " agent ":[[:space:]]*$") { inf = 1; next }
    ingp && inf && /^  [A-Za-z]/ && $0 !~ /^    / { inf = 0 }
    ingp && inf && /^    tier1:/ { sub(/.*tier1:[[:space:]]*/, ""); sub(/#.*/, ""); gsub(/["[:space:]]/, ""); print; exit }
  ' "$CONFIG"
}

# Re-apply agent model: frontmatter from project.config.md (used after `install.sh
# --update` refetches the agent files and resets their frontmatter to repo defaults).
sync_agents() {
  require_config
  local ba lead qa fe be
  ba="$(_get_orchestrator_tier1 ba)"
  lead="$(_get_orchestrator_tier1 team_lead)"
  qa="$(_get_orchestrator_tier1 qa)"
  fe="$(_get_orchestrator_tier1 frontend_dev)"
  be="$(_get_orchestrator_tier1 backend_dev)"
  [ -n "$ba" ]   && _sync_agent team-ba.md   "$ba"
  [ -n "$lead" ] && _sync_agent team-lead.md "$lead"
  [ -n "$qa" ]   && _sync_agent team-qa.md   "$qa"
  [ -n "$fe" ]   && _sync_agent team-frontend.md "$fe"
  [ -n "$be" ] && _sync_agent team-dotnet.md "$be"
  echo "✅ agent frontmatter synced from project.config.md (ba=${ba:-?} lead=${lead:-?} qa=${qa:-?} fe=${fe:-config-default} be=${be:-config-default})"
}

apply() {
  require_config
  [ "${1:-}" = "claude" ] && shift          # legacy form: apply claude <profile>
  local profile="${1:-}"
  [ -z "$profile" ] && { echo "Usage: model-profiles.sh apply <auto|balanced|save>" >&2; exit 1; }
  eval "$(claude_map "$profile")" || exit 1
  _set_coding_tiers claude "$POWER" "$STANDARD" "$LITE"
  _set_orchestrator_tier1 ba         "$BA"
  _set_orchestrator_tier1 team_lead  "$LEAD"
  _set_orchestrator_tier1 qa         "$QA"
  # Dev agents do standard-tier implementation work → follow the standard tier.
  _set_orchestrator_tier1 frontend_dev "$STANDARD"
  _set_orchestrator_tier1 backend_dev  "$STANDARD"
  _sync_agent team-ba.md   "$BA"
  _sync_agent team-lead.md "$LEAD"
  _sync_agent team-qa.md   "$QA"
  _sync_agent team-frontend.md "$STANDARD"
  _sync_agent team-dotnet.md   "$STANDARD"
  _set_coding_profile "$profile"
  _set_model_mode "recommended"
  echo "✅ Claude profile '$profile' applied  (power=$POWER  standard=$STANDARD  lite=$LITE)"
}

# One model for the whole team (model_mode: single): all tiers + every agent's frontmatter.
single() {
  require_config
  [ "${1:-}" = "claude" ] && shift          # legacy form: single claude <model>
  local model="${1:-}"
  [ -z "$model" ] && { echo "Usage: model-profiles.sh single <model-id>" >&2; exit 1; }
  _set_coding_tiers claude "$model" "$model" "$model"
  local agent f
  for agent in ba team_lead qa frontend_dev backend_dev; do
    _set_orchestrator_tier1 "$agent" "$model"
  done
  for f in team-ba.md team-lead.md team-qa.md team-frontend.md team-dotnet.md; do
    _sync_agent "$f" "$model"
  done
  _set_coding_profile "single"
  _set_model_mode "single"
  echo "✅ single-model mode: every tier and team agent → $model"
}

show() {
  require_config
  local prof
  prof="$(grep -E '^[[:space:]]+coding_profile:' "$CONFIG" 2>/dev/null | head -1 | sed 's/.*coding_profile:[[:space:]]*//; s/#.*//; s/[[:space:]]*$//')"
  echo "Active coding profile: ${prof:-<unset> (treated as auto)}"
  echo ""
  echo "coding_models tiers:"
  sed -n '/^coding_models:/,/^[^[:space:]#]/p' "$CONFIG" | grep -E '^( {2,4}[a-z]|    (power|standard|lite):)' || true
}

# ── dispatch ───────────────────────────────────────────────────────────────────
CMD="${1:-}"; shift || true
case "$CMD" in
  claude-map)        claude_map "$@" ;;
  apply)             apply "$@" ;;
  single)            single "$@" ;;
  sync-agents)       sync_agents ;;
  show)              show ;;
  *)
    echo "Usage: model-profiles.sh <claude-map <profile> | apply <profile> | single <model> | sync-agents | show>" >&2
    exit 1
    ;;
esac
