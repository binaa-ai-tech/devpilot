#!/usr/bin/env bash
# =============================================================================
# doctor.sh — devpilot pre-flight health check.
#
# Verifies the project is ready to run a /ceo task BEFORE one is started, so a
# misconfiguration fails fast here instead of mid-task.
#
#   bash scripts/doctor.sh        (exit 0 if no hard ❌, else 1)
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" 2>/dev/null || { echo "❌ not inside a git repository"; exit 1; }

HARD_FAIL=0
WARN_COUNT=0
ok()   { echo "  ✅ $1"; }
warn() { echo "  ⚠️  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
bad()  { echo "  ❌ $1"; HARD_FAIL=1; }

cfg() { grep -E "^[[:space:]]*$1:" project.config.md 2>/dev/null | head -1 | sed "s/.*$1:[[:space:]]*//" | tr -d '"' | awk '{print $1}'; }

echo "── devpilot doctor ───────────────────────────────────"

# Config present
[ -f project.config.md ] && ok "project.config.md found" || bad "project.config.md missing — run: bash install.sh"

# Git remote + base branch
git remote get-url origin >/dev/null 2>&1 && ok "git remote 'origin' set" || warn "no 'origin' remote — PRs/push will fail"
BASE=$(cfg base_branch); BASE="${BASE:-develop}"
if git show-ref --verify --quiet "refs/heads/$BASE" || git ls-remote --exit-code --heads origin "$BASE" >/dev/null 2>&1; then
  ok "base branch '$BASE' exists"
else
  warn "base branch '$BASE' not found locally or on origin"
fi

# AI engine
ENGINE=$(grep -A8 '^engines:' project.config.md 2>/dev/null | grep -E '^\s*coding:' | head -1 | sed 's/.*coding:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
ENGINE="${ENGINE:-claude}"
PROFILE=$(grep -A8 '^engines:' project.config.md 2>/dev/null | grep -E '^\s*coding_profile:' | head -1 | sed 's/.*coding_profile:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')
ok "coding engine=$ENGINE, profile=${PROFILE:-auto}  (change: /dp-config models <profile>)"
command -v claude >/dev/null 2>&1 && ok "claude CLI present (orchestrator)" || warn "claude CLI not found"
if [ "$ENGINE" = opencode ]; then
  if command -v opencode >/dev/null 2>&1; then
    ok "opencode present (coding=$ENGINE)"
    [ "$(bash "$(dirname "$0")/resolve-engine.sh" copilot 2>/dev/null)" = yes ] \
      && ok "GitHub Copilot available in opencode" \
      || warn "GitHub Copilot not available in opencode — will use opencode's default model"
  else
    warn "opencode not found but engine=$ENGINE"
  fi
fi

# Tracker
TRACKER=$(grep -A3 '^tracker:' project.config.md 2>/dev/null | grep -E '^\s*type:' | head -1 | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
TRACKER="${TRACKER:-local}"
case "$TRACKER" in
  local)  ok "tracker=local (no external setup needed)" ;;
  github) command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && ok "tracker=github, gh authenticated" || warn "tracker=github but gh missing/unauthenticated — will fall back to local" ;;
  jira)   if [ -f .devpilot/config.sh ] && ! grep -q 'YOUR_JIRA_API_TOKEN' .devpilot/config.sh; then ok "tracker=jira, credentials set"; else warn "tracker=jira but .devpilot/config.sh looks unconfigured"; fi ;;
esac

# ── Model configuration ───────────────────────────────────────────────────────
cfg_deep() {  # cfg_deep <grandparent> <parent> <key>
  awk -v gp="$1" -v parent="$2" -v key="$3" '
    $0 ~ "^"gp":" { ingp=1; next }
    ingp && $0 ~ "^[^[:space:]]" { ingp=0 }
    ingp && $0 ~ "^[[:space:]]+"parent":" { inp=1; next }
    ingp && inp && $0 ~ "^[[:space:]][[:space:]]?[a-zA-Z]" { inp=0 }
    ingp && inp && $0 ~ "^[[:space:]]+"key":" {
      sub(".*"key":[[:space:]]*", ""); sub(/#.*/, ""); gsub(/[",]/, ""); split($0,a," "); print a[1]; exit
    }
  ' project.config.md 2>/dev/null
}

MODEL_MODE=$(grep -A8 '^engines:' project.config.md 2>/dev/null | grep -E '^\s*model_mode:' | head -1 | sed 's/.*model_mode:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')
case "${MODEL_MODE:-recommended}" in
  recommended|single|per-team) ok "model_mode=${MODEL_MODE:-recommended}" ;;
  *) warn "model_mode='$MODEL_MODE' is not recommended|single|per-team — fix in project.config.md" ;;
esac

# Claude tiers: present + plausible ids (typos fail mid-task otherwise)
CL_BAD=0
for T in power standard lite; do
  M=$(cfg_deep coding_models claude "$T")
  if [ -z "$M" ]; then
    warn "coding_models.claude.$T is empty — set it: /dp-config models <profile>"; CL_BAD=1
  elif ! printf '%s' "$M" | grep -qE '^claude-(opus|sonnet|haiku|fable|mythos)-[0-9a-z.-]+$'; then
    warn "coding_models.claude.$T='$M' doesn't look like a Claude model id — typo? (e.g. claude-sonnet-4-6)"; CL_BAD=1
  fi
done
[ "$CL_BAD" = 0 ] && ok "claude model tiers look valid"

# Agent frontmatter vs config (drift breaks per-team/single modes silently)
agent_tier1() { grep -A30 '^models:' project.config.md 2>/dev/null | grep -A3 "^  $1:" | grep 'tier1:' | head -1 | sed 's/.*tier1:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}'; }
DRIFT=0
for PAIR in "ba:team-ba" "team_lead:team-lead" "qa:team-qa" "frontend_dev:team-frontend" "backend_dev:team-backend"; do
  KEY="${PAIR%%:*}"; FILE=".claude/agents/${PAIR##*:}.md"
  WANT=$(agent_tier1 "$KEY"); [ -z "$WANT" ] && continue
  [ -f "$FILE" ] || continue
  HAVE=$(grep '^model:' "$FILE" | head -1 | awk '{print $2}')
  [ "$WANT" = "$HAVE" ] || { warn "$FILE model '$HAVE' ≠ config '$WANT' — run: bash scripts/model-profiles.sh sync-agents"; DRIFT=1; }
done
[ "$DRIFT" = 0 ] && ok "agent frontmatter matches config (models.*.tier1)"

# opencode tiers exist in the live model list (when opencode is in play + installed)
if [ "$ENGINE" = opencode ] && command -v opencode >/dev/null 2>&1; then
  OC_LIVE=$( { opencode models 2>/dev/null; opencode model list 2>/dev/null; } | sort -u || true )
  for T in power standard lite; do
    M=$(cfg_deep coding_models opencode "$T")
    [ -z "$M" ] && continue
    printf '%s\n' "$OC_LIVE" | grep -qF "$M" \
      && ok "opencode $T tier '$M' available" \
      || warn "opencode $T tier '$M' not in your live model list — check: bash scripts/model-profiles.sh opencode-list"
  done
fi

# ── Config completeness (missing values fail mid-task otherwise) ──────────────
MISSING_CFG=0
for K in project_name ticket_prefix base_branch merge_policy; do
  V=$(cfg "$K")
  [ -n "$V" ] && [ "$V" != "KEY" ] || { warn "config '$K' is missing/default — re-configure: /dp-config fix"; MISSING_CFG=1; }
done
if [ "$TRACKER" = "jira" ]; then
  if [ ! -f .devpilot/config.sh ] || grep -q 'YOUR_JIRA_API_TOKEN\|YOUR-ORG.atlassian.net' .devpilot/config.sh 2>/dev/null; then
    warn "tracker=jira but credentials incomplete — run: bash scripts/devpilot-config.sh set jira_base_url=… / jira_api_token=…  then: bash scripts/devpilot-config.sh validate"
    MISSING_CFG=1
  fi
fi
[ "$MISSING_CFG" = 0 ] && ok "config complete (no missing values)"

# Tooling
command -v git >/dev/null 2>&1 && ok "git" || bad "git is required"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  ok "gh (PR automation) authenticated"
elif [ "$(cfg merge_policy)" = "auto" ]; then
  warn "merge_policy=auto but gh CLI missing/unauthenticated — auto-merge runs via GitHub MCP (Claude Code on the web) but will NOT work in a plain terminal. Install+auth gh, or run /ceo from the web."
else
  warn "gh not found — open-pr.sh will print a compare URL (open/merge via GitHub MCP)"
fi
command -v jq  >/dev/null 2>&1 && ok "jq" || warn "jq not found — some scripts are limited"

# Scripts executable
NOTEXEC=$(find scripts -name '*.sh' ! -perm -u+x 2>/dev/null | wc -l | tr -d ' ')
[ "${NOTEXEC:-0}" = "0" ] && ok "all scripts executable" || warn "$NOTEXEC script(s) not executable — run: chmod +x scripts/*.sh"

# Project index
[ -f docs/project-index.md ] && ok "project index present" || warn "no project index — run: bash scripts/generate-project-index.sh"

echo "──────────────────────────────────────────────────────"
if [ "$HARD_FAIL" = 0 ]; then
  echo "✅ ready to run /ceo"
  [ "$WARN_COUNT" -gt 0 ] && echo "ℹ️  $WARN_COUNT warning(s) — fix interactively: /dp-config fix"
else
  echo "❌ fix the items above before running /ceo  (interactive: /dp-config fix)"
fi
exit "$HARD_FAIL"
