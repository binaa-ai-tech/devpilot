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
ok()   { echo "  ✅ $1"; }
warn() { echo "  ⚠️  $1"; }
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
command -v claude >/dev/null 2>&1 && ok "claude CLI present (orchestrator)" || warn "claude CLI not found"
if [ "$ENGINE" = opencode ] || [ "$ENGINE" = max ]; then
  command -v opencode >/dev/null 2>&1 && ok "opencode present (coding=$ENGINE)" || warn "opencode not found but engine=$ENGINE"
fi

# Tracker
TRACKER=$(grep -A3 '^tracker:' project.config.md 2>/dev/null | grep -E '^\s*type:' | head -1 | sed 's/.*type:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
TRACKER="${TRACKER:-local}"
case "$TRACKER" in
  local)  ok "tracker=local (no external setup needed)" ;;
  github) command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && ok "tracker=github, gh authenticated" || warn "tracker=github but gh missing/unauthenticated — will fall back to local" ;;
  jira)   if [ -f .devpilot/config.sh ] && ! grep -q 'YOUR_JIRA_API_TOKEN' .devpilot/config.sh; then ok "tracker=jira, credentials set"; else warn "tracker=jira but .devpilot/config.sh looks unconfigured"; fi ;;
esac

# Tooling
command -v git >/dev/null 2>&1 && ok "git" || bad "git is required"
command -v gh  >/dev/null 2>&1 && ok "gh (PR automation)" || warn "gh not found — open-pr.sh will print a compare URL"
command -v jq  >/dev/null 2>&1 && ok "jq" || warn "jq not found — some scripts are limited"

# Scripts executable
NOTEXEC=$(find scripts -name '*.sh' ! -perm -u+x 2>/dev/null | wc -l | tr -d ' ')
[ "${NOTEXEC:-0}" = "0" ] && ok "all scripts executable" || warn "$NOTEXEC script(s) not executable — run: chmod +x scripts/*.sh"

# Project index
[ -f docs/project-index.md ] && ok "project index present" || warn "no project index — run: bash scripts/generate-project-index.sh"

echo "──────────────────────────────────────────────────────"
if [ "$HARD_FAIL" = 0 ]; then echo "✅ ready to run /ceo"; else echo "❌ fix the items above before running /ceo"; fi
exit "$HARD_FAIL"
