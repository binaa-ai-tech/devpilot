#!/usr/bin/env bash
# =============================================================================
# model-profiles.sh — named model presets for devpilot ("powerful + easy").
#
# A *profile* is a one-word preset over the power/standard/lite tiers that the
# routing brain (resolve-engine.sh) already understands. The user picks one
# profile; per-task tier selection keeps working unchanged — the profile only
# decides which model each tier resolves to.
#
# Claude profiles
#   auto      power=opus    standard=sonnet  lite=haiku   ← Opus for hard tasks (default)
#   balanced  power=sonnet  standard=sonnet  lite=haiku   ← no Opus, solid everywhere
#   save      power=sonnet  standard=haiku   lite=haiku   ← token-saving; Sonnet only when complex
#
# opencode / antigravity profiles (mapped onto whatever the CLI reports live)
#   recommended  strongest coder / solid all-round / fast-cheap
#   balanced     solid all-round everywhere
#   save         fast-cheap everywhere
# antigravity has no curated fallback ids (unknown when the CLI is absent), so its
# tiers map from the live `antigravity model list` only, and stay blank otherwise.
#
# Usage
#   model-profiles.sh claude-map      <auto|balanced|save>        → POWER/STANDARD/LITE + BA/LEAD/QA
#   model-profiles.sh opencode-list                               → one available model id per line
#   model-profiles.sh opencode-map    <recommended|balanced|save> → POWER/STANDARD/LITE
#   model-profiles.sh antigravity-list                            → one available model id per line
#   model-profiles.sh antigravity-map <recommended|balanced|save> → POWER/STANDARD/LITE
#   model-profiles.sh apply  <claude|opencode|antigravity> <profile>  → write project.config.md in place
#   model-profiles.sh single <claude|opencode|antigravity> <model>    → ONE model for the whole team
#   model-profiles.sh show                                        → current profile + resolved models
#
# Model modes (recorded as engines.model_mode by install.sh):
#   recommended — task-balanced tiers via a named profile (apply …)
#   single      — one model everywhere (single …)
#   per-team    — per-role models: edit models.* / layer_models.* in
#                 project.config.md, then run `model-profiles.sh sync-agents`
#
# NOTE: the Claude/opencode mapping tables below are intentionally also inlined
# in install.sh (STEP 5/7). Keep the two in sync if you change a profile.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/project.config.md"

# ── Claude model ids (single source of truth) ──────────────────────────────────
CL_OPUS="claude-opus-4-8"
CL_SONNET="claude-sonnet-4-6"
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

# ── live opencode model ids (empty if opencode is unavailable) ──────────────────
opencode_list() {
  command -v opencode >/dev/null 2>&1 || return 0
  { opencode models 2>/dev/null; opencode model list 2>/dev/null; } \
    | grep -oE '[A-Za-z0-9._-]+/[A-Za-z0-9._:-]+' \
    | sort -u
}

# pick <fallback-literal> <preferred-substring...>
# echoes the first available model id whose text contains a preferred substring,
# else the fallback literal (so installs still work when opencode isn't present).
_oc_pick() {
  local fallback="$1"; shift
  local avail p hit
  avail="$(opencode_list)"
  for p in "$@"; do
    hit="$(printf '%s\n' "$avail" | grep -iF "$p" | head -1)"
    [ -n "$hit" ] && { printf '%s\n' "$hit"; return; }
  done
  printf '%s\n' "$fallback"
}

# ── opencode profile → tier models (chosen from the live list) ──────────────────
opencode_map() {
  local profile="${1:-recommended}"
  local P S L
  case "$profile" in
    recommended)
      P="$(_oc_pick 'github-copilot/gpt-5'      'gpt-5.4' 'gpt-5')"
      S="$(_oc_pick 'github-copilot/gpt-4o'     'gpt-4o' 'gpt-4.1')"
      L="$(_oc_pick 'github-copilot/gpt-4o-mini' 'mini' 'flash')" ;;
    balanced)
      P="$(_oc_pick 'github-copilot/gpt-4o'     'gpt-4o' 'gpt-4.1')"
      S="$(_oc_pick 'github-copilot/gpt-4o'     'gpt-4o' 'gpt-4.1')"
      L="$(_oc_pick 'github-copilot/gpt-4o-mini' 'mini' 'flash')" ;;
    save)
      P="$(_oc_pick 'github-copilot/gpt-4o-mini' 'mini' 'flash')"
      S="$(_oc_pick 'github-copilot/gpt-4o-mini' 'mini' 'flash')"
      L="$(_oc_pick 'github-copilot/gpt-4o-mini' 'mini' 'flash')" ;;
    *) echo "Unknown opencode profile: $profile (use recommended|balanced|save)" >&2; return 1 ;;
  esac
  printf 'POWER=%s\nSTANDARD=%s\nLITE=%s\n' "$P" "$S" "$L"
}

# ── live antigravity model ids (empty if antigravity is unavailable) ────────────
antigravity_list() {
  command -v antigravity >/dev/null 2>&1 || return 0
  { antigravity model list 2>/dev/null; antigravity models 2>/dev/null; } \
    | grep -oE '[A-Za-z0-9._-]+/[A-Za-z0-9._:-]+|(gemini|claude|gpt|o[0-9])[A-Za-z0-9._:-]*' \
    | sort -u
}

# ── antigravity profile → tier models (chosen from the live list; blank if absent) ──
# No curated fallbacks: antigravity model ids aren't known when the CLI is missing,
# so unmatched tiers stay empty rather than guessing an id.
antigravity_map() {
  local profile="${1:-recommended}"
  local avail P S L
  avail="$(antigravity_list)"
  _ag() { local p hit; for p in "$@"; do hit="$(printf '%s\n' "$avail" | grep -iF "$p" | head -1)"; [ -n "$hit" ] && { printf '%s\n' "$hit"; return; }; done; printf '%s\n' ""; }
  case "$profile" in
    recommended) P="$(_ag ultra pro opus large)"; S="$(_ag pro flash)";            L="$(_ag flash mini lite nano)" ;;
    balanced)    P="$(_ag pro flash)";            S="$(_ag pro flash)";            L="$(_ag flash mini lite nano)" ;;
    save)        P="$(_ag flash mini lite nano)"; S="$(_ag flash mini lite nano)"; L="$(_ag flash mini lite nano)" ;;
    *) echo "Unknown antigravity profile: $profile (use recommended|balanced|save)" >&2; return 1 ;;
  esac
  printf 'POWER=%s\nSTANDARD=%s\nLITE=%s\n' "$P" "$S" "$L"
}

# ── project.config.md writers ───────────────────────────────────────────────────
require_config() { [ -f "$CONFIG" ] || { echo "project.config.md not found at $ROOT" >&2; exit 1; }; }

# Replace power/standard/lite under coding_models.<family>
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

# Set or insert engines.model_mode (idempotent) — recommended | single | per-team
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
      /^engines:/ { ineng = 1 }
      ineng && /^[[:space:]]+coding:[[:space:]]/ { print "  model_mode: " m; ineng = 0 }
    ' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  fi
}

# Set or insert engines.coding_profile (idempotent)
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
    # Insert right after engines.coding.
    awk -v p="$profile" '
      { print }
      /^engines:/ { ineng = 1 }
      ineng && /^[[:space:]]+coding:[[:space:]]/ { print "  coding_profile: " p; ineng = 0 }
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
  if [ -n "$be" ]; then _sync_agent team-backend.md "$be"; _sync_agent team-dotnet.md "$be"; fi
  echo "✅ agent frontmatter synced from project.config.md (ba=${ba:-?} lead=${lead:-?} qa=${qa:-?} fe=${fe:-config-default} be=${be:-config-default})"
}

apply() {
  require_config
  local family="${1:-}" profile="${2:-}"
  [ -z "$family" ] || [ -z "$profile" ] && { echo "Usage: model-profiles.sh apply <claude|opencode> <profile>" >&2; exit 1; }

  case "$family" in
    claude)
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
      _sync_agent team-backend.md  "$STANDARD"
      _sync_agent team-dotnet.md   "$STANDARD"
      _set_coding_profile "$profile"
      _set_model_mode "recommended"
      echo "✅ Claude profile '$profile' applied  (power=$POWER  standard=$STANDARD  lite=$LITE)"
      ;;
    opencode)
      eval "$(opencode_map "$profile")" || exit 1
      _set_coding_tiers opencode "$POWER" "$STANDARD" "$LITE"
      _set_coding_profile "$profile"
      _set_model_mode "recommended"
      echo "✅ opencode profile '$profile' applied  (power=$POWER  standard=$STANDARD  lite=$LITE)"
      command -v opencode >/dev/null 2>&1 || echo "ℹ️  opencode not installed — used recommended defaults; re-run after install to pick from your live model list."
      ;;
    antigravity)
      eval "$(antigravity_map "$profile")" || exit 1
      _set_coding_tiers antigravity "$POWER" "$STANDARD" "$LITE"
      _set_coding_profile "$profile"
      _set_model_mode "recommended"
      echo "✅ antigravity profile '$profile' applied  (power=${POWER:-<unset>}  standard=${STANDARD:-<unset>}  lite=${LITE:-<unset>})"
      command -v antigravity >/dev/null 2>&1 || echo "ℹ️  antigravity not installed — tiers left blank; re-run after install to pick from your live model list."
      ;;
    *) echo "Unknown family: $family (use claude|opencode|antigravity)" >&2; exit 1 ;;
  esac
}

# One model for the whole team (model_mode: single).
# claude family → all tiers + every agent's frontmatter; other families → all tiers.
single() {
  require_config
  local family="${1:-}" model="${2:-}"
  { [ -z "$family" ] || [ -z "$model" ]; } && { echo "Usage: model-profiles.sh single <claude|opencode|antigravity> <model-id>" >&2; exit 1; }

  case "$family" in
    claude)
      _set_coding_tiers claude "$model" "$model" "$model"
      for agent in ba team_lead qa frontend_dev backend_dev; do
        _set_orchestrator_tier1 "$agent" "$model"
      done
      for f in team-ba.md team-lead.md team-qa.md team-frontend.md team-backend.md team-dotnet.md; do
        _sync_agent "$f" "$model"
      done
      ;;
    opencode|antigravity)
      _set_coding_tiers "$family" "$model" "$model" "$model"
      ;;
    *) echo "Unknown family: $family (use claude|opencode|antigravity)" >&2; exit 1 ;;
  esac
  _set_coding_profile "single"
  _set_model_mode "single"
  echo "✅ single-model mode: every $family tier (and team agent, for claude) → $model"
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
  opencode-list)     opencode_list ;;
  opencode-map)      opencode_map "$@" ;;
  antigravity-list)  antigravity_list ;;
  antigravity-map)   antigravity_map "$@" ;;
  apply)             apply "$@" ;;
  single)            single "$@" ;;
  sync-agents)       sync_agents ;;
  show)              show ;;
  *)
    echo "Usage: model-profiles.sh <claude-map <profile> | opencode-list | opencode-map <profile> | antigravity-list | antigravity-map <profile> | apply <family> <profile> | single <family> <model> | sync-agents | show>" >&2
    exit 1
    ;;
esac
