#!/usr/bin/env bash
# =============================================================================
# doctor.sh — devpilot pre-flight health check.
#
# Verifies the project is ready to run a /dp-deliver task BEFORE one is started, so a
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

# Claude (the only engine)
PROFILE=$(grep -A4 '^model_policy:' project.config.md 2>/dev/null | grep -E '^\s*coding_profile:' | head -1 | sed 's/.*coding_profile:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')
ok "model profile=${PROFILE:-auto}  (change: /dp-setup models <auto|balanced|save>)"
command -v claude >/dev/null 2>&1 && ok "claude CLI present" || warn "claude CLI not found — install Claude Code"
grep -q '^engines:' project.config.md 2>/dev/null && warn "project.config.md still has a legacy 'engines:' block (OpenCode/Antigravity support was removed) — delete it; models live under model_policy/coding_models"

# Tracker (local | jira | azure | github) — credentials only; live test: /dp-setup tracker
TRACKER=$(bash scripts/tracker.sh configured 2>/dev/null || echo local)
TRK_OUT=$(bash scripts/tracker.sh check 2>/dev/null); TRK_RC=$?
case "$TRK_RC" in
  0) case "$TRK_OUT" in
       *STATE=skipped*) warn "tracker=$TRACKER not configured — runs continue with local tracking (connect: /dp-setup tracker)" ;;
       *) ok "tracker=$TRACKER ready" ;;
     esac ;;
  2) warn "tracker=$TRACKER selected but credentials missing — /dp-setup tracker (or: bash scripts/tracker.sh skip)" ;;
  3) ok "tracker=local (connect Jira / Azure DevOps / GitHub Issues anytime: /dp-setup tracker)" ;;
  *) warn "tracker check failed — run: bash scripts/tracker.sh check" ;;
esac

# Git host + PR automation
HOST=$(bash scripts/git-host.sh 2>/dev/null || echo other)
HOST_MSG=$(bash scripts/git-host.sh check 2>/dev/null); HOST_RC=$?
if [ "$HOST_RC" = 0 ]; then ok "${HOST_MSG#✅ }"
elif [ "$HOST" = "github" ] && [ "$(cfg merge_policy)" = "auto" ]; then
  warn "git host GitHub, gh missing/unauthenticated — PRs run through the GitHub MCP tools (Claude Code on the web); in a terminal: gh auth login"
else warn "${HOST_MSG#⚠️  }"
fi

# Delivery pipeline (CD) + deploy target
if [ -f .github/workflows/devpilot-cd.yml ] || [ -f azure-pipelines-cd.yml ]; then
  ok "CD pipeline present (build once → DEV → SIT → UAT → PRD)"
  [ -f deploy/deploy.sh ] && ok "deploy target: deploy/deploy.sh" \
    || ok "deploy target: DEPLOY_HOOK secrets in the pipeline (or add deploy/deploy.sh) — deploy.sh fails loudly if neither exists"
else
  warn "no CD pipeline — releases can't deploy: /dp-setup pipelines"
fi

# Versioning
command -v bash >/dev/null && ok "version $(bash scripts/version.sh current 2>/dev/null) (bumped by every /dp-deliver PR: feature→minor, bug→patch)"

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

MODEL_MODE=$(grep -A4 '^model_policy:' project.config.md 2>/dev/null | grep -E '^\s*model_mode:' | head -1 | sed 's/.*model_mode:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')
case "${MODEL_MODE:-recommended}" in
  recommended|single|per-team) ok "model_mode=${MODEL_MODE:-recommended}" ;;
  *) warn "model_mode='$MODEL_MODE' is not recommended|single|per-team — fix in project.config.md" ;;
esac

# Claude tiers: present + plausible ids (typos fail mid-task otherwise)
CL_BAD=0
for T in power standard lite; do
  M=$(cfg_deep coding_models claude "$T")
  if [ -z "$M" ]; then
    warn "coding_models.claude.$T is empty — set it: /dp-setup models <profile>"; CL_BAD=1
  elif ! printf '%s' "$M" | grep -qE '^claude-(opus|sonnet|haiku|fable|mythos)-[0-9a-z.-]+$'; then
    warn "coding_models.claude.$T='$M' doesn't look like a Claude model id — typo? (e.g. claude-sonnet-5)"; CL_BAD=1
  fi
done
[ "$CL_BAD" = 0 ] && ok "claude model tiers look valid"

# Agent frontmatter vs config (drift breaks per-team/single modes silently)
agent_tier1() { grep -A30 '^models:' project.config.md 2>/dev/null | grep -A3 "^  $1:" | grep 'tier1:' | head -1 | sed 's/.*tier1:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}'; }
DRIFT=0
for PAIR in "ba:team-ba" "team_lead:team-lead" "qa:team-qa" "frontend_dev:team-frontend" "backend_dev:team-dotnet"; do
  KEY="${PAIR%%:*}"; FILE=".claude/agents/${PAIR##*:}.md"
  WANT=$(agent_tier1 "$KEY"); [ -z "$WANT" ] && continue
  [ -f "$FILE" ] || continue
  HAVE=$(grep '^model:' "$FILE" | head -1 | awk '{print $2}')
  [ "$WANT" = "$HAVE" ] || { warn "$FILE model '$HAVE' ≠ config '$WANT' — run: bash scripts/model-profiles.sh sync-agents"; DRIFT=1; }
done
[ "$DRIFT" = 0 ] && ok "agent frontmatter matches config (models.*.tier1)"

# ── Config completeness (missing values fail mid-task otherwise) ──────────────
MISSING_CFG=0
for K in project_name ticket_prefix base_branch merge_policy; do
  V=$(cfg "$K")
  [ -n "$V" ] && [ "$V" != "KEY" ] || { warn "config '$K' is missing/default — re-configure: /dp-setup fix"; MISSING_CFG=1; }
done
[ "$MISSING_CFG" = 0 ] && ok "config complete (no missing values)"

# Tooling
command -v git >/dev/null 2>&1 && ok "git" || bad "git is required"
command -v curl >/dev/null 2>&1 && ok "curl" || warn "curl not found — Jira / Azure DevOps / GitHub APIs unavailable"
command -v jq  >/dev/null 2>&1 && ok "jq" || warn "jq not found — tracker and PR automation need it"

# Scripts executable
NOTEXEC=$(find scripts -name '*.sh' ! -perm -u+x 2>/dev/null | wc -l | tr -d ' ')
[ "${NOTEXEC:-0}" = "0" ] && ok "all scripts executable" || warn "$NOTEXEC script(s) not executable — run: chmod +x scripts/*.sh"

# Project index
[ -f docs/project-index.md ] && ok "project index present" || warn "no project index — run: bash scripts/generate-project-index.sh"

echo "──────────────────────────────────────────────────────"
if [ "$HARD_FAIL" = 0 ]; then
  echo "✅ ready to run /dp-deliver"
  [ "$WARN_COUNT" -gt 0 ] && echo "ℹ️  $WARN_COUNT warning(s) — fix interactively: /dp-setup fix"
else
  echo "❌ fix the items above before running /dp-deliver  (interactive: /dp-setup fix)"
fi
exit "$HARD_FAIL"
