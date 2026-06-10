#!/usr/bin/env bash
# =============================================================================
# devpilot — Installer
#
# Installs the devpilot AI team system into any project.
#
# Remote install (from any project root):
#   curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh | bash
#
# Local install (from a cloned copy):
#   bash /path/to/devpilot/install.sh
#
# This installs:
#   .claude/          — Claude Code commands + agent definitions
#   .opencode/        — opencode project config + AGENTS.md
#   .devpilot/        — shared rules, prompts, templates, skills
#   scripts/          — git-flow, Jira, deploy helpers
#   AGENTS.md         — project context (opencode / antigravity)
#   CLAUDE.md         — project context (Claude Code)
#   project.config.md — engine + model config (edit with /dp-config wizard)
# =============================================================================
set -euo pipefail

# When piped via curl | bash, stdin IS the script — bash and read() both fight over it.
# Fix: download a clean copy to a temp file and re-exec from disk, redirecting stdin
# from the controlling terminal so every `read` prompt gets the keyboard, not the pipe.
if [ ! -t 0 ] && [ -z "${DEVPILOT_REEXEC:-}" ]; then
  if [ ! -e /dev/tty ]; then
    echo "Error: no terminal available for interactive prompts." >&2
    echo "Download and run instead:" >&2
    echo "  curl -fsSL ${REPO:-https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main}/install.sh -o /tmp/devpilot-install.sh && bash /tmp/devpilot-install.sh" >&2
    exit 1
  fi
  # Trailing X's only — macOS BSD mktemp won't randomize when a suffix (.sh)
  # follows the X's; it would create a literal file that collides on re-run.
  TMPFILE=$(mktemp "${TMPDIR:-/tmp}/devpilot-install.XXXXXX")
  curl -fsSL "https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh" -o "$TMPFILE"
  DEVPILOT_REEXEC=1 bash "$TMPFILE" "$@" < /dev/tty
  rm -f "$TMPFILE"
  exit $?
fi

REPO="https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main"
PROJECT_ROOT=$(pwd)

# Detect if running from a local clone (DEVPILOT_LOCAL set, or install.sh is in the same dir as .claude/)
DEVPILOT_LOCAL=""
if [ -d "$(dirname "$0")/.claude" ]; then
  DEVPILOT_LOCAL="$(cd "$(dirname "$0")" && pwd)"
fi

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

info()    { echo -e "${GREEN}[install]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET} $*"; }
section() { echo -e "\n${CYAN}${BOLD}$*${RESET}"; }
ask()     { printf "${BOLD}%s${RESET}" "$*"; }

# Track files that could not be installed, so a partial install is loud, not silent.
# (Plain string + counter, not an array — stays bash 3.2 safe under `set -u`.)
FETCH_FAILED=""
FETCH_FAIL_COUNT=0

# Download a file — from local clone if available, else from GitHub
fetch() {
  local src="$1"  # path relative to devpilot root
  local dst="$2"  # destination path

  mkdir -p "$(dirname "$dst")"

  if [ -n "$DEVPILOT_LOCAL" ] && [ -f "$DEVPILOT_LOCAL/$src" ]; then
    cp "$DEVPILOT_LOCAL/$src" "$dst"
  elif curl -fsSL "$REPO/$src" -o "$dst" 2>/dev/null; then
    : # fetched from the remote
  else
    warn "$src not found — skipping"
    FETCH_FAILED="${FETCH_FAILED}    - ${src}
"
    FETCH_FAIL_COUNT=$((FETCH_FAIL_COUNT + 1))
  fi
}

# Report any skipped files. Returns non-zero if the install is incomplete.
fetch_summary() {
  [ "$FETCH_FAIL_COUNT" -eq 0 ] && return 0
  echo ""
  warn "${FETCH_FAIL_COUNT} file(s) could NOT be installed — this install is INCOMPLETE:"
  printf '%s' "$FETCH_FAILED" >&2
  warn "Fix network/repo access (or install from a local clone), then run: bash install.sh --update"
  return 1
}

# ── Update mode ──────────────────────────────────────────────────────────────
# `bash install.sh --update` refreshes the managed devpilot files in place and
# NEVER touches your settings: project.config.md, .devpilot/config.sh,
# AGENTS.md, and CLAUDE.md are left exactly as they are.
# (Keep these lists in sync with STEP 9.)
run_update() {
  echo ""
  echo -e "${BOLD}  devpilot — update (config preserved)${RESET}"
  echo ""

  RULE_SNIPPETS="angular.md react-vue.md dotnet.md node.md python.md go.md java.md sqlserver.md postgres-mysql.md"
  PROMPT_TEAM="ba-agent.md lead-plan.md lead-review.md frontend-agent.md dotnet-agent.md backend-agent.md qa-agent.md"
  TEMPLATE_TEAM="requirements.md implementation-plan.md qa-report.md review-report.md adr.md domain-model.md jira-brief.md"
  SKILLS="get-shit-done.md spec-first.md security-scan.md performance-review.md architecture-guard.md self-heal.md definition-of-done.md compact-context.md core-rules.md code-review.md test-strategy.md debug-method.md estimation-and-slicing.md tech-debt.md observability.md release-discipline.md status-reporting.md definition-of-ready.md incident-postmortem.md data-migration-safety.md api-design.md accessibility.md threat-modeling.md secrets-management.md data-privacy.md clean-code.md version-control.md refactoring.md ci-cd.md feature-flags.md reliability-slo.md dependency-management.md documentation.md i18n.md cost-awareness.md database-performance.md test-case-design.md e2e-testing.md performance-testing.md auto-merge.md README.md"
  CHECKLISTS="feature.md bugfix.md hotfix.md"
  CMDS="ceo.md dp-plan.md dp-sprint.md dp-build.md dp-release.md dp-rollback.md dp-hotfix.md dp-status.md dp-config.md dp-review-fix.md dp-test.md dp-autofix.md"
  AGENTS_LIST="team-lead.md team-ba.md team-frontend.md team-dotnet.md team-backend.md team-qa.md"
  SCRIPTS="git-flow.sh new-feature.sh run-command.sh resolve-engine.sh model-profiles.sh preflight-scan.sh run-summary.sh checkpoint.sh devpilot-config.sh run-mode.sh track.sh open-pr.sh scope.sh scope-guard.sh session-start.sh doctor.sh status.sh audit.sh changelog.sh rollback.sh metrics.sh scope-hook.sh install-git-hooks.sh deploy-dev.sh deploy-sit.sh deploy-uat.sh deploy-prd.sh create-jira-ticket.sh create-jira-epic.sh update-jira-status.sh update-jira-description.sh add-jira-comment.sh generate-project-index.sh generate-backlog-index.sh jira-sprint.sh link-jira-issues.sh md-to-adf.sh jira-describe.sh ceo.sh dp-plan.sh dp-sprint.sh dp-build.sh dp-release.sh dp-status.sh dp-config.sh"

  info "Refreshing .devpilot/rules..."
  fetch ".devpilot/rules.md" ".devpilot/rules.md"
  fetch ".devpilot/process.md" ".devpilot/process.md"
  for f in $RULE_SNIPPETS;   do fetch ".devpilot/rules/$f"        ".devpilot/rules/$f";        done
  for f in $PROMPT_TEAM;     do fetch ".devpilot/prompts/team/$f" ".devpilot/prompts/team/$f"; done
  for f in 6-env-diff.md 6-generate-tests.md; do fetch ".devpilot/prompts/$f" ".devpilot/prompts/$f"; done
  for f in $TEMPLATE_TEAM;   do fetch ".devpilot/templates/team/$f" ".devpilot/templates/team/$f"; done
  for f in changelog-entry.md ticket.md; do fetch ".devpilot/templates/$f" ".devpilot/templates/$f"; done
  for f in $CHECKLISTS;      do fetch ".devpilot/checklists/$f"   ".devpilot/checklists/$f";   done
  for f in $SKILLS;          do fetch ".devpilot/skills/$f"       ".devpilot/skills/$f";       done
  fetch ".devpilot/config/models.md" ".devpilot/config/models.md"

  info "Refreshing .claude/..."
  for f in $CMDS;       do fetch ".claude/commands/$f" ".claude/commands/$f"; done
  for f in $AGENTS_LIST; do fetch ".claude/agents/$f"  ".claude/agents/$f";  done

  info "Refreshing scripts/..."
  for f in $SCRIPTS; do fetch "scripts/$f" "scripts/$f"; chmod +x "scripts/$f" 2>/dev/null || true; done

  # Refetching the agent files above reset their model: frontmatter to repo
  # defaults — re-sync it from the user's project.config.md so their chosen
  # profile / wizard model assignments survive the update.
  [ -f project.config.md ] && bash scripts/model-profiles.sh sync-agents 2>/dev/null || true

  fetch_summary || true

  echo ""
  echo -e "${GREEN}  ✅ devpilot updated.${RESET}  project.config.md and .devpilot/config.sh were left untouched."
  echo ""
  exit 0
}

if [ "${1:-}" = "--update" ] || [ "${1:-}" = "update" ]; then
  run_update
fi

# ── Banner ─────────────────────────────────────────────────────────────────────
echo ""
DEVPILOT_VERSION=""
if [ -n "$DEVPILOT_LOCAL" ] && [ -f "$DEVPILOT_LOCAL/VERSION" ]; then
  DEVPILOT_VERSION=$(cat "$DEVPILOT_LOCAL/VERSION" | tr -d '[:space:]')
else
  DEVPILOT_VERSION=$(curl -fsSL "$REPO/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "2.0.0")
fi

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  devpilot v${DEVPILOT_VERSION} — AI Team System Installer${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  Project: $PROJECT_ROOT"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — SYSTEM SCAN
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 1 — Scanning installed AI tools..."

HAS_CLAUDE=false
HAS_OPENCODE=false
HAS_ANTIGRAVITY=false
HAS_GH=false
HAS_GIT=false

command -v claude       &>/dev/null && HAS_CLAUDE=true       && echo "  ✅ claude       — Claude Code CLI"           || echo "  ⚠️  claude       — not found (install for Claude agent mode)"
command -v opencode     &>/dev/null && HAS_OPENCODE=true     && echo "  ✅ opencode     — GitHub Copilot models"      || echo "  ⚠️  opencode     — not found"
command -v antigravity  &>/dev/null && HAS_ANTIGRAVITY=true  && echo "  ✅ antigravity  — antigravity AI"              || echo "  ⚠️  antigravity  — not found"
command -v gh           &>/dev/null && HAS_GH=true           && echo "  ✅ gh           — GitHub CLI (PR automation)" || echo "  ❌ gh           — not found (install for PR automation)"
command -v git          &>/dev/null && HAS_GIT=true          && echo "  ✅ git"                                        || echo "  ❌ git          — REQUIRED"
command -v jq           &>/dev/null                          && echo "  ✅ jq"                                        || echo "  ⚠️  jq           — not found (some scripts limited)"

if [ "$HAS_GIT" = false ]; then
  echo ""
  echo "  ❌ git is required. Install git and re-run."
  exit 1
fi

if [ "$HAS_CLAUDE" = false ] && [ "$HAS_OPENCODE" = false ] && [ "$HAS_ANTIGRAVITY" = false ]; then
  echo ""
  echo "  ❌ No AI CLI found. Install at least one:"
  echo "     claude       — https://claude.ai/code"
  echo "     opencode     — https://opencode.ai"
  echo "     antigravity  — https://antigravity.ai"
  exit 1
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2 — PROJECT STACK SCAN
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 2 — Scanning project stack..."

DETECT_FRONTEND="none"
DETECT_BACKEND="none"
DETECT_DB="none"
DETECT_INTEGRATION="none"

if [ -f "angular.json" ] || \
   grep -q '"@angular/core"' package.json 2>/dev/null || \
   grep -q '"@nx/angular"' package.json 2>/dev/null || \
   find . -maxdepth 4 -name "angular.json" 2>/dev/null | grep -q .; then
                                                             DETECT_FRONTEND="angular";  echo "  ✅ Angular"
elif grep -q '"next"' package.json 2>/dev/null;         then DETECT_FRONTEND="nextjs";   echo "  ✅ Next.js"
elif grep -q '"react"' package.json 2>/dev/null;        then DETECT_FRONTEND="react";    echo "  ✅ React"
elif grep -q '"vue"' package.json 2>/dev/null;          then DETECT_FRONTEND="vue";      echo "  ✅ Vue"
elif [ -f "package.json" ];                             then DETECT_FRONTEND="node";     echo "  ✅ Node/JS"
fi

if find . -maxdepth 3 \( -name "*.sln" -o -name "*.csproj" \) 2>/dev/null | grep -q .; then
  DETECT_BACKEND="dotnet"; echo "  ✅ .NET"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  DETECT_BACKEND="python"; echo "  ✅ Python"
elif [ -f "go.mod" ];   then DETECT_BACKEND="go";   echo "  ✅ Go"
elif [ -f "pom.xml" ];  then DETECT_BACKEND="java"; echo "  ✅ Java"
fi

# Scan deeper than the backend probe: EF Core / monorepo migrations often nest
# (e.g. apps/api/Infrastructure/Data/Migrations = depth 5). Skip build/dep noise.
if find . -maxdepth 7 \
     -not -path '*/node_modules/*' -not -path '*/bin/*' -not -path '*/obj/*' -not -path '*/.git/*' \
     \( -iname "*.sql" -o -iname "*migration*" \) 2>/dev/null | grep -q .; then
  DETECT_DB="sqlserver"; echo "  ✅ Database migrations detected"
fi

if grep -rq -i "rabbitmq\|kafka\|servicebus\|azure.messaging\|masstransit" . \
    --include="*.json" --include="*.cs" --include="*.ts" 2>/dev/null; then
  DETECT_INTEGRATION="yes"; echo "  ✅ Integration/messaging detected"
fi

if   [ "$DETECT_FRONTEND" != "none" ] && [ "$DETECT_BACKEND" != "none" ]; then DETECTED_TYPE="fullstack"
elif [ "$DETECT_FRONTEND" != "none" ]; then DETECTED_TYPE="frontend"
elif [ "$DETECT_BACKEND" != "none" ];  then DETECTED_TYPE="backend"
else DETECTED_TYPE="fullstack"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3 — AGENT TEAM
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 3 — Recommended agent team..."

AGENT_FRONTEND="false"; AGENT_BACKEND="false"; AGENT_DB="false"; AGENT_INTEGRATION="false"
[ "$DETECT_FRONTEND" != "none" ]  && AGENT_FRONTEND="true"
[ "$DETECT_BACKEND" != "none" ]   && AGENT_BACKEND="true"
[ "$DETECT_DB" != "none" ]        && AGENT_DB="true"
[ "$DETECT_INTEGRATION" = "yes" ] && AGENT_INTEGRATION="true"

echo "  Recommended:"
echo "    ✅ BA · Team Lead · QA   (always on)"
[ "$AGENT_FRONTEND" = "true" ]    && echo "    ✅ Frontend Developer"    || echo "    ⬜ Frontend Developer (not detected)"
[ "$AGENT_BACKEND" = "true" ]     && echo "    ✅ Backend Developer"     || echo "    ⬜ Backend Developer (not detected)"
[ "$AGENT_DB" = "true" ]          && echo "    ✅ DB Agent"              || echo "    ⬜ DB Agent (not detected)"
[ "$AGENT_INTEGRATION" = "true" ] && echo "    ✅ Integration Agent"     || echo "    ⬜ Integration Agent (not detected)"

echo ""
ask "  Accept recommended team? [Y/n]: "; read -r ACCEPT_TEAM
if [[ "${ACCEPT_TEAM:-Y}" =~ ^[Nn] ]]; then
  ask "  Enable Frontend agent? [y/N]: ";    read -r v; [[ "${v:-N}" =~ ^[Yy] ]] && AGENT_FRONTEND="true"    || AGENT_FRONTEND="false"
  ask "  Enable Backend agent? [y/N]: ";     read -r v; [[ "${v:-N}" =~ ^[Yy] ]] && AGENT_BACKEND="true"     || AGENT_BACKEND="false"
  ask "  Enable DB agent? [y/N]: ";          read -r v; [[ "${v:-N}" =~ ^[Yy] ]] && AGENT_DB="true"          || AGENT_DB="false"
  ask "  Enable Integration agent? [y/N]: "; read -r v; [[ "${v:-N}" =~ ^[Yy] ]] && AGENT_INTEGRATION="true" || AGENT_INTEGRATION="false"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4 — CODING ENGINE
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 4 — Coding engine (who writes the implementation code)..."

CODING_ENGINE="claude"
FALLBACK_ENGINE="none"

echo ""
echo "  [1] claude       — Claude subagents write all code (fully automatic, no terminal steps)"
echo "  [2] opencode     — Claude orchestrates; opencode writes code (GitHub Copilot models)"
echo "  [3] antigravity  — Claude orchestrates; antigravity writes code"
echo ""

if [ "$HAS_CLAUDE" = true ] && [ "$HAS_OPENCODE" = false ] && [ "$HAS_ANTIGRAVITY" = false ]; then
  DEFAULT_ENG=1
elif [ "$HAS_OPENCODE" = true ] && [ "$HAS_CLAUDE" = false ]; then
  DEFAULT_ENG=2
elif [ "$HAS_ANTIGRAVITY" = true ] && [ "$HAS_CLAUDE" = false ]; then
  DEFAULT_ENG=3
else
  DEFAULT_ENG=1
fi

ask "  Choice [$DEFAULT_ENG]: "; read -r ENG_CHOICE
case "${ENG_CHOICE:-$DEFAULT_ENG}" in
  2) CODING_ENGINE="opencode" ;;
  3) CODING_ENGINE="antigravity" ;;
  *) CODING_ENGINE="claude" ;;
esac

# Fallback engine
if [ "$CODING_ENGINE" = "claude" ]; then
  if [ "$HAS_OPENCODE" = true ] || [ "$HAS_ANTIGRAVITY" = true ]; then
    echo ""
    echo "  Fallback when Claude hits limits:"
    echo "  [1] opencode    [2] antigravity    [3] none"
    ask "  Choice [1]: "; read -r FB_CHOICE
    case "${FB_CHOICE:-1}" in
      2) FALLBACK_ENGINE="antigravity" ;;
      3) FALLBACK_ENGINE="none" ;;
      *) FALLBACK_ENGINE="${HAS_OPENCODE:+opencode}"; [ "$FALLBACK_ENGINE" = "" ] && FALLBACK_ENGINE="antigravity" ;;
    esac
  fi
elif [ "$CODING_ENGINE" = "opencode" ] && [ "$HAS_ANTIGRAVITY" = true ]; then
  echo ""
  ask "  Fallback when opencode hits limits? (antigravity) [Y/n]: "; read -r v
  [[ "${v:-Y}" =~ ^[Yy] ]] && FALLBACK_ENGINE="antigravity" || FALLBACK_ENGINE="none"
elif [ "$CODING_ENGINE" = "antigravity" ] && [ "$HAS_OPENCODE" = true ]; then
  echo ""
  ask "  Fallback when antigravity hits limits? (opencode) [Y/n]: "; read -r v
  [[ "${v:-Y}" =~ ^[Yy] ]] && FALLBACK_ENGINE="opencode" || FALLBACK_ENGINE="none"
fi

info "Coding engine: $CODING_ENGINE  (fallback: $FALLBACK_ENGINE)"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5 — MODEL PROFILE (powerful + easy: pick one word, not a tier matrix)
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 5 — Model profile..."

# A profile is a preset over the power/standard/lite tiers. Per-task routing
# (resolve-engine.sh + skills) still picks the tier per task; the profile only
# decides which model each tier maps to. Re-run anytime: /dp-config models <profile>.
# NOTE: these mappings mirror scripts/model-profiles.sh — keep them in sync.

CL_OPUS="claude-opus-4-8"; CL_SONNET="claude-sonnet-4-6"; CL_HAIKU="claude-haiku-4-5-20251001"

CL_POWER="$CL_OPUS"; CL_STANDARD="$CL_SONNET"; CL_LITE="$CL_HAIKU"
OC_POWER="github-copilot/gpt-5"; OC_STANDARD="github-copilot/gpt-4o"; OC_LITE="github-copilot/gpt-4o-mini"; OC_FALLBACK=""
AG_POWER=""; AG_STANDARD=""; AG_LITE=""
CODING_PROFILE="auto"; OC_PROFILE="recommended"

# Orchestrator tiers — tier1 is derived from the Claude profile below; tier2/tier3
# are sensible Copilot/free fallbacks the user rarely needs to edit by hand.
T1_BA="$CL_HAIKU";   T2_BA="copilot: Gemini 3.5 Flash"; T3_BA="free: DeepSeek V4 Flash Free"
T1_LEAD="$CL_SONNET"; T2_LEAD="copilot: Gemini 2.5 Pro"; T3_LEAD="free: DeepSeek V4 Flash Free"
T1_QA="$CL_HAIKU";   T2_QA="copilot: GPT-5-mini";        T3_QA="free: Nemotron 3 Super Free"

# Map a Claude profile → coding tiers + orchestrator tier1 (mirrors model-profiles.sh).
claude_profile_apply() {
  case "$1" in
    balanced) CL_POWER="$CL_SONNET"; CL_STANDARD="$CL_SONNET"; CL_LITE="$CL_HAIKU"
              T1_BA="$CL_HAIKU"; T1_LEAD="$CL_SONNET"; T1_QA="$CL_HAIKU" ;;
    save)     CL_POWER="$CL_SONNET"; CL_STANDARD="$CL_HAIKU"; CL_LITE="$CL_HAIKU"
              T1_BA="$CL_HAIKU"; T1_LEAD="$CL_HAIKU"; T1_QA="$CL_HAIKU" ;;
    *)        CL_POWER="$CL_OPUS"; CL_STANDARD="$CL_SONNET"; CL_LITE="$CL_HAIKU"
              T1_BA="$CL_HAIKU"; T1_LEAD="$CL_SONNET"; T1_QA="$CL_HAIKU" ;;
  esac
}

# ── Claude profile (Claude always runs orchestration, so this always applies) ──
echo ""
echo "  Claude — how should it balance power vs. tokens?"
echo "    [1] auto      — Opus for hard work, Sonnet normal, Haiku for light tasks  (recommended)"
echo "    [2] balanced  — Sonnet for real work, Haiku for light tasks (no Opus)"
echo "    [3] save      — token-saving: Haiku by default, Sonnet only when complex"
ask "  Choice [1]: "; read -r CP_CHOICE
case "${CP_CHOICE:-1}" in
  2) CODING_PROFILE="balanced" ;;
  3) CODING_PROFILE="save" ;;
  *) CODING_PROFILE="auto" ;;
esac
claude_profile_apply "$CODING_PROFILE"
info "Claude profile: $CODING_PROFILE  (per-task routing still applies)"

# ── opencode profile — populated from the live model list when opencode exists ──
if [ "$CODING_ENGINE" = "opencode" ] || [ "$FALLBACK_ENGINE" = "opencode" ]; then
  echo ""
  echo "  opencode — GitHub Copilot models:"
  OC_AVAIL=""
  if command -v opencode >/dev/null 2>&1; then
    OC_AVAIL=$( { opencode models 2>/dev/null; opencode model list 2>/dev/null; } \
      | grep -oE '[A-Za-z0-9._-]+/[A-Za-z0-9._:-]+' | sort -u || true )
    if [ -n "$OC_AVAIL" ]; then
      echo "  Detected in your opencode:"
      printf '%s\n' "$OC_AVAIL" | head -20 | sed 's/^/    • /'
    fi
  fi
  [ -z "$OC_AVAIL" ] && echo "  (opencode not detected — using recommended Copilot defaults; re-run /dp-config models later)"
  # oc_pick <fallback-literal> <preferred-substring...> → first available match, else fallback
  oc_pick() { local fb="$1"; shift; local p hit; for p in "$@"; do hit=$(printf '%s\n' "$OC_AVAIL" | grep -iF -e "$p" | head -1 || true); [ -n "$hit" ] && { echo "$hit"; return; }; done; echo "$fb"; }
  echo "    [1] recommended — strongest coder / solid / fast-cheap  (recommended)"
  echo "    [2] balanced    — solid all-round everywhere"
  echo "    [3] save        — fast & cheap everywhere"
  echo "    [4] custom      — pick each tier yourself"
  ask "  Choice [1]: "; read -r OP_CHOICE
  case "${OP_CHOICE:-1}" in
    2) OC_PROFILE="balanced"
       OC_POWER=$(oc_pick "github-copilot/gpt-4o" gpt-4o gpt-4.1); OC_STANDARD=$(oc_pick "github-copilot/gpt-4o" gpt-4o gpt-4.1); OC_LITE=$(oc_pick "github-copilot/gpt-4o-mini" -mini flash) ;;
    3) OC_PROFILE="save"
       OC_POWER=$(oc_pick "github-copilot/gpt-4o-mini" -mini flash); OC_STANDARD=$(oc_pick "github-copilot/gpt-4o-mini" -mini flash); OC_LITE=$(oc_pick "github-copilot/gpt-4o-mini" -mini flash) ;;
    4) OC_PROFILE="custom"
       ask "  Power model    [$OC_POWER]: ";    read -r v; [ -n "$v" ] && OC_POWER="$v"
       ask "  Standard model [$OC_STANDARD]: "; read -r v; [ -n "$v" ] && OC_STANDARD="$v"
       ask "  Lite model     [$OC_LITE]: ";     read -r v; [ -n "$v" ] && OC_LITE="$v" ;;
    *) OC_PROFILE="recommended"
       OC_POWER=$(oc_pick "github-copilot/gpt-5" gpt-5.4 gpt-5); OC_STANDARD=$(oc_pick "github-copilot/gpt-4o" gpt-4o gpt-4.1); OC_LITE=$(oc_pick "github-copilot/gpt-4o-mini" -mini flash) ;;
  esac
  ask "  Fallback when Copilot unavailable [blank = opencode default]: "; read -r v; OC_FALLBACK="$v"
  info "opencode profile: $OC_PROFILE  (power=$OC_POWER  standard=$OC_STANDARD  lite=$OC_LITE)"
fi

# ── antigravity profile — populated from the live model list when present ──
AG_PROFILE="recommended"
if [ "$CODING_ENGINE" = "antigravity" ] || [ "$FALLBACK_ENGINE" = "antigravity" ]; then
  echo ""
  echo "  antigravity — models:"
  AG_AVAIL=""
  if command -v antigravity >/dev/null 2>&1; then
    AG_AVAIL=$( { antigravity model list 2>/dev/null; antigravity models 2>/dev/null; } \
      | grep -oE '[A-Za-z0-9._-]+/[A-Za-z0-9._:-]+|(gemini|claude|gpt|o[0-9])[A-Za-z0-9._:-]*' | sort -u || true )
    if [ -n "$AG_AVAIL" ]; then
      echo "  Detected in your antigravity:"
      printf '%s\n' "$AG_AVAIL" | head -20 | sed 's/^/    • /'
    fi
  fi
  [ -z "$AG_AVAIL" ] && echo "  (antigravity not detected — leaving tiers blank; set them with /dp-config models after install)"
  # ag_pick <fallback> <preferred-substring...> → first available match, else fallback (blank = no guessed id)
  ag_pick() { local fb="$1"; shift; local p hit; for p in "$@"; do hit=$(printf '%s\n' "$AG_AVAIL" | grep -iF -e "$p" | head -1 || true); [ -n "$hit" ] && { echo "$hit"; return; }; done; echo "$fb"; }
  echo "    [1] recommended — strongest reasoning / solid / fast  (recommended)"
  echo "    [2] balanced    — solid all-round everywhere"
  echo "    [3] save        — fast & cheap everywhere"
  echo "    [4] custom      — pick each tier yourself"
  ask "  Choice [1]: "; read -r AGP_CHOICE
  case "${AGP_CHOICE:-1}" in
    2) AG_PROFILE="balanced"
       AG_POWER=$(ag_pick "" pro flash); AG_STANDARD=$(ag_pick "" pro flash); AG_LITE=$(ag_pick "" flash -mini lite nano) ;;
    3) AG_PROFILE="save"
       AG_POWER=$(ag_pick "" flash -mini lite nano); AG_STANDARD=$(ag_pick "" flash -mini lite nano); AG_LITE=$(ag_pick "" flash -mini lite nano) ;;
    4) AG_PROFILE="custom"
       ask "  Power model    [$AG_POWER]: ";    read -r v; [ -n "$v" ] && AG_POWER="$v"
       ask "  Standard model [$AG_STANDARD]: "; read -r v; [ -n "$v" ] && AG_STANDARD="$v"
       ask "  Lite model     [$AG_LITE]: ";     read -r v; [ -n "$v" ] && AG_LITE="$v" ;;
    *) AG_PROFILE="recommended"
       AG_POWER=$(ag_pick "" ultra pro opus large); AG_STANDARD=$(ag_pick "" pro flash); AG_LITE=$(ag_pick "" flash -mini lite nano) ;;
  esac
  info "antigravity profile: $AG_PROFILE  (power=${AG_POWER:-<set later>}  standard=${AG_STANDARD:-<set later>}  lite=${AG_LITE:-<set later>})"
fi

# The profile recorded in project.config.md = the ACTIVE coding engine's profile.
ACTIVE_PROFILE="$CODING_PROFILE"
[ "$CODING_ENGINE" = "opencode" ]    && ACTIVE_PROFILE="$OC_PROFILE"
[ "$CODING_ENGINE" = "antigravity" ] && ACTIVE_PROFILE="$AG_PROFILE"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6 — TERMINAL RUNNER (which AI CLI runs /ceo from scripts/)
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 6 — Terminal runner (runs /ceo from bash scripts)..."

RUNNER_CLI="claude"

echo ""
echo "  How will you run commands from the terminal? (bash scripts/ceo.sh)"
echo "  Inside Claude Code: slash commands always work natively."
echo ""
echo "  [1] claude       — Claude Code CLI"
echo "  [2] opencode     — opencode CLI"
echo "  [3] antigravity  — antigravity CLI"
echo "  [4] same as coding engine"
echo ""

DEFAULT_RUNNER=1
[ "$CODING_ENGINE" = "opencode" ]     && DEFAULT_RUNNER=2
[ "$CODING_ENGINE" = "antigravity" ]  && DEFAULT_RUNNER=3
[ "$HAS_CLAUDE" = false ] && [ "$HAS_OPENCODE" = true ]    && DEFAULT_RUNNER=2
[ "$HAS_CLAUDE" = false ] && [ "$HAS_ANTIGRAVITY" = true ] && DEFAULT_RUNNER=3

ask "  Choice [$DEFAULT_RUNNER]: "; read -r RUNNER_CHOICE
case "${RUNNER_CHOICE:-$DEFAULT_RUNNER}" in
  2) RUNNER_CLI="opencode" ;;
  3) RUNNER_CLI="antigravity" ;;
  4) RUNNER_CLI="$CODING_ENGINE" ;;
  *) RUNNER_CLI="claude" ;;
esac

info "Runner: $RUNNER_CLI"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7 — CLAUDE ORCHESTRATOR MODELS (derived from the profile chosen in STEP 5)
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 7 — Claude orchestrator models..."

# BA / Team Lead / QA tier-1 models follow the Claude profile from STEP 5;
# tier2/tier3 stay as Copilot/free fallbacks. Fine-tune later: /dp-config wizard.
info "BA        → $T1_BA"
info "Team Lead → $T1_LEAD"
info "QA        → $T1_QA"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8 — PROJECT IDENTITY
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 8 — Project identity..."

DEFAULT_NAME=$(basename "$PROJECT_ROOT")
ask "  Project name [$DEFAULT_NAME]: ";    read -r PROJECT_NAME;   [ -z "$PROJECT_NAME" ]   && PROJECT_NAME="$DEFAULT_NAME"
ask "  Ticket prefix (e.g. MSK, APP): ";   read -r TICKET_PREFIX;  [ -z "$TICKET_PREFIX" ]  && TICKET_PREFIX="KEY"

# Default base branch to develop when a develop branch exists (DEV→SIT→UAT→PRD pipeline).
DEFAULT_BASE="main"
if git show-ref --verify --quiet refs/heads/develop 2>/dev/null \
   || git ls-remote --exit-code --heads origin develop >/dev/null 2>&1; then
  DEFAULT_BASE="develop"
fi
ask "  Base branch [$DEFAULT_BASE]: ";      read -r BASE_BRANCH;    [ -z "$BASE_BRANCH" ]    && BASE_BRANCH="$DEFAULT_BASE"

echo ""
echo "  Issue tracker:"
echo "    [1] local   — no setup; tasks logged to docs/tasks/  (recommended for solo / quick start)"
echo "    [2] github  — GitHub Issues via the gh CLI"
echo "    [3] jira    — Jira Cloud (needs credentials in .devpilot/config.sh)"
TRACKER_TYPE="local"
ask "  Choice [1]: "; read -r TRK_CHOICE
case "${TRK_CHOICE:-1}" in
  2) TRACKER_TYPE="github" ;;
  3) TRACKER_TYPE="jira" ;;
  *) TRACKER_TYPE="local" ;;
esac
info "Tracker: $TRACKER_TYPE"

echo ""
echo "  Merge policy:"
echo "    [1] auto     — devpilot squash-merges the PR into $BASE_BRANCH automatically"
echo "    [2] pr-only  — devpilot opens the PR; you merge it"
MERGE_POLICY="auto"
ask "  Choice [1]: "; read -r MP_CHOICE
case "${MP_CHOICE:-1}" in
  2) MERGE_POLICY="pr-only" ;;
  *) MERGE_POLICY="auto" ;;
esac
info "Merge policy: $MERGE_POLICY"

echo ""
DOC_LANGUAGE="en"
ask "  Docs language (en, ar, fr, …) [en]: "; read -r LANG_IN; [ -n "$LANG_IN" ] && DOC_LANGUAGE="$LANG_IN"
info "Docs language: $DOC_LANGUAGE  (code stays English)"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 9 — DOWNLOAD / COPY FILES
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 9 — Installing devpilot files..."

# Create directory structure
mkdir -p .devpilot/{prompts/team,templates/team,checklists,skills,config}
mkdir -p .claude/commands .claude/agents
mkdir -p .opencode
mkdir -p scripts
mkdir -p .github/ISSUE_TEMPLATE
mkdir -p docs/{requirements,plans,qa,reviews,adrs,domain-models,fallback,implementation,tasks}

# .devpilot — shared rules, prompts, templates, skills
info "Installing .devpilot/..."
fetch ".devpilot/rules.md" ".devpilot/rules.md"
fetch ".devpilot/process.md" ".devpilot/process.md"
# .devpilot/config.sh holds per-project credentials and is gitignored, so it is
# NEVER fetched from the repo (a remote fetch would 404 and silently skip it,
# leaving the project with no config). We generate it locally instead, pre-filled
# from the answers above. Never overwrite an existing one — it holds real secrets.
if [ -f ".devpilot/config.sh" ]; then
  info ".devpilot/config.sh exists — keeping it"
else
  # Derive GitHub org/repo from the origin remote when one is configured.
  CFG_GH_ORG="your-org"; CFG_GH_REPO="your-repo"
  REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || true)
  if [ -n "$REMOTE_URL" ]; then
    SLUG=$(printf '%s' "$REMOTE_URL" | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#; s/\.git$//')
    if printf '%s' "$SLUG" | grep -q '/'; then
      CFG_GH_ORG="${SLUG%%/*}"
      CFG_GH_REPO="${SLUG##*/}"
    fi
  fi
  CFG_PREFIX=$(printf '%s' "$TICKET_PREFIX" | tr '[:upper:]' '[:lower:]')
  CFG_JIRA_KEY=$(printf '%s' "$TICKET_PREFIX" | tr '[:lower:]' '[:upper:]')
  CFG_NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  cat > .devpilot/config.sh << CFGEOF
#!/bin/bash
# =============================================================================
# PROJECT CONFIG — fill this in once per project, then keep it out of git
# (.devpilot/config.sh is gitignored by the installer)
#
# Update any key via CLI (recommended — no manual editing needed):
#   bash scripts/devpilot-config.sh set jira_api_token=<new-token>
#   bash scripts/devpilot-config.sh validate
# =============================================================================

# ── Jira ─────────────────────────────────────────────────────────────────────
JIRA_BASE_URL="https://YOUR-ORG.atlassian.net"
JIRA_EMAIL="your-email@example.com"
JIRA_API_TOKEN='YOUR_JIRA_API_TOKEN'
JIRA_PROJECT_KEY="$CFG_JIRA_KEY"        # e.g. MSK, APP, PRJ

# ── Git / GitHub ──────────────────────────────────────────────────────────────
GITHUB_ORG="$CFG_GH_ORG"
GITHUB_REPO="$CFG_GH_REPO"
TICKET_PREFIX="$CFG_PREFIX"           # project abbreviation, used in branch names: feature/key-12-slug
                               # e.g. msk, app, prj — should match your Jira project key (lowercase)

# ── Branches ──────────────────────────────────────────────────────────────────
MAIN_BRANCH="main"
DEVELOP_BRANCH="develop"

# ── Environment URLs (update after each env is provisioned) ──────────────────
# Leave blank if an environment is not used in this project.
DEV_FRONTEND_URL=""
DEV_API_URL=""

SIT_FRONTEND_URL=""
SIT_API_URL=""

UAT_FRONTEND_URL=""
UAT_API_URL=""

PRD_FRONTEND_URL=""
PRD_API_URL=""

# ── Notifications ─────────────────────────────────────────────────────────────
NOTIFY_EMAIL="your-email@example.com"
DEVPILOT_CONFIG_UPDATED_AT='$CFG_NOW'
CFGEOF
  info ".devpilot/config.sh created — set your Jira/GitHub credentials with: bash scripts/devpilot-config.sh set jira_api_token=<token>"
fi

# Per-stack rule snippets (router in rules.md tells agents which to read)
mkdir -p .devpilot/rules
for f in angular.md react-vue.md dotnet.md node.md python.md go.md java.md sqlserver.md postgres-mysql.md; do
  fetch ".devpilot/rules/$f" ".devpilot/rules/$f"
done

for f in 6-env-diff.md 6-generate-tests.md; do
  fetch ".devpilot/prompts/$f" ".devpilot/prompts/$f"
done

for f in ba-agent.md lead-plan.md lead-review.md frontend-agent.md dotnet-agent.md backend-agent.md qa-agent.md; do
  fetch ".devpilot/prompts/team/$f" ".devpilot/prompts/team/$f"
done

for f in requirements.md implementation-plan.md qa-report.md review-report.md adr.md domain-model.md jira-brief.md; do
  fetch ".devpilot/templates/team/$f" ".devpilot/templates/team/$f"
done

for f in changelog-entry.md ticket.md; do
  fetch ".devpilot/templates/$f" ".devpilot/templates/$f"
done

for f in feature.md bugfix.md hotfix.md; do
  fetch ".devpilot/checklists/$f" ".devpilot/checklists/$f"
done

for f in get-shit-done.md spec-first.md security-scan.md performance-review.md architecture-guard.md self-heal.md definition-of-done.md compact-context.md core-rules.md \
         code-review.md test-strategy.md debug-method.md estimation-and-slicing.md tech-debt.md observability.md release-discipline.md status-reporting.md \
         definition-of-ready.md incident-postmortem.md data-migration-safety.md api-design.md accessibility.md \
         threat-modeling.md secrets-management.md data-privacy.md clean-code.md version-control.md refactoring.md ci-cd.md feature-flags.md reliability-slo.md dependency-management.md documentation.md \
         i18n.md cost-awareness.md database-performance.md \
         test-case-design.md e2e-testing.md performance-testing.md auto-merge.md \
         README.md; do
  fetch ".devpilot/skills/$f" ".devpilot/skills/$f"
done

fetch ".devpilot/config/models.md" ".devpilot/config/models.md"

# .claude/ — Claude Code commands + agent definitions
info "Installing .claude/..."
for f in ceo.md dp-plan.md dp-sprint.md dp-build.md \
         dp-release.md dp-rollback.md dp-hotfix.md \
         dp-status.md dp-config.md dp-review-fix.md dp-test.md dp-autofix.md; do
  fetch ".claude/commands/$f" ".claude/commands/$f"
done

for f in team-lead.md team-ba.md team-frontend.md team-dotnet.md team-backend.md team-qa.md; do
  fetch ".claude/agents/$f" ".claude/agents/$f"
done

# SessionStart hook — install only if the user has no settings yet (never clobber).
if [ ! -f ".claude/settings.json" ]; then
  fetch ".claude/settings.json" ".claude/settings.json"
  info ".claude/settings.json created (SessionStart hook → scripts/session-start.sh)"
else
  info ".claude/settings.json exists — to enable the warm-up hook, add a SessionStart entry running: bash scripts/session-start.sh"
fi

# .opencode/ — opencode project config
info "Installing .opencode/..."
fetch ".opencode/config.json" ".opencode/config.json"
fetch ".opencode/README.md"   ".opencode/README.md"

# AGENTS.md — project context for opencode + antigravity
if [ ! -f "AGENTS.md" ]; then
  fetch "AGENTS.md" "AGENTS.md"
  info "AGENTS.md created"
else
  info "AGENTS.md already exists — skipping (edit manually if needed)"
fi

# CLAUDE.md — project context for Claude Code
if [ ! -f "CLAUDE.md" ]; then
  fetch "CLAUDE.md" "CLAUDE.md"
  info "CLAUDE.md created"
fi

# scripts/
info "Installing scripts/..."
for f in git-flow.sh new-feature.sh run-command.sh resolve-engine.sh model-profiles.sh preflight-scan.sh run-summary.sh checkpoint.sh devpilot-config.sh \
          run-mode.sh track.sh open-pr.sh scope.sh scope-guard.sh session-start.sh \
          doctor.sh status.sh audit.sh changelog.sh rollback.sh metrics.sh scope-hook.sh install-git-hooks.sh \
          deploy-dev.sh deploy-sit.sh deploy-uat.sh deploy-prd.sh \
          create-jira-ticket.sh create-jira-epic.sh \
          update-jira-status.sh update-jira-description.sh \
          add-jira-comment.sh generate-project-index.sh \
          generate-backlog-index.sh jira-sprint.sh link-jira-issues.sh \
          md-to-adf.sh jira-describe.sh \
          ceo.sh dp-plan.sh dp-sprint.sh dp-build.sh \
          dp-release.sh dp-status.sh dp-config.sh; do
  fetch "scripts/$f" "scripts/$f"
  chmod +x "scripts/$f" 2>/dev/null || true
done

# .github/
for f in BRANCH_NAMING.md COMMIT_CONVENTION.md pull_request_template.md; do
  fetch ".github/$f" ".github/$f"
done
for f in bug_report.md feature_request.md; do
  fetch ".github/ISSUE_TEMPLATE/$f" ".github/ISSUE_TEMPLATE/$f"
done

# Misc
[ ! -f ".commitlintrc.json" ] && fetch ".commitlintrc.json" ".commitlintrc.json"
[ ! -f ".env.example" ]       && fetch ".env.example"       ".env.example"

for d in requirements plans qa reviews adrs domain-models fallback implementation tasks; do
  touch "docs/$d/.gitkeep"
done

# .gitignore additions
if [ -f ".gitignore" ]; then
  for entry in ".devpilot/config.sh" ".devpilot/.scope-lock" ".env" ".env.local" "docs/fallback/"; do
    grep -qF "$entry" .gitignore || echo "$entry" >> .gitignore
  done
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 10 — WRITE project.config.md
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 10 — Writing project.config.md..."

cat > project.config.md << CONFIGEOF
# Project Configuration
# Generated by devpilot install.sh — edit with /dp-config wizard

## Project Identity

project_name: "$PROJECT_NAME"
project_type: $DETECTED_TYPE
ticket_prefix: "$TICKET_PREFIX"
base_branch: $BASE_BRANCH

## Issue Tracker
# local | github | jira  — switch anytime by editing this value.

tracker:
  type: $TRACKER_TYPE

## Merge Policy
# auto    — devpilot squash-merges the PR into base_branch automatically
# pr-only — devpilot opens the PR and stops; a human merges it

merge_policy: $MERGE_POLICY

## Docs Language
# Human language for BA/QA/review docs. Code & commits stay English.

language: $DOC_LANGUAGE

## Tech Stack

stack:
  frontend: $DETECT_FRONTEND
  backend: $DETECT_BACKEND
  database: $DETECT_DB
  integration: $DETECT_INTEGRATION

## Active Agents

agents:
  ba:           { enabled: true }
  team_lead:    { enabled: true }
  frontend:     { enabled: $AGENT_FRONTEND }
  backend:      { enabled: $AGENT_BACKEND }
  db:           { enabled: $AGENT_DB }
  integration:  { enabled: $AGENT_INTEGRATION }
  qa:           { enabled: true }

## Engines
#
# orchestrator — always Claude (BA · planning · QA · review)
# coding       — who writes implementation code: claude | opencode | antigravity
# runner       — which AI CLI runs /ceo from bash scripts
# fallback     — coding engine fallback when primary hits limits

engines:
  orchestrator: claude
  coding: $CODING_ENGINE
  coding_profile: $ACTIVE_PROFILE   # auto|balanced|save (claude) · recommended|balanced|save|custom (opencode/antigravity) — change: /dp-config models <profile>
  runner: $RUNNER_CLI
  fallback: $FALLBACK_ENGINE

## Coding Engine Models — task-balanced tiers (power / standard / lite)
# Models are chosen per task by complexity (resolve-engine.sh), balancing power
# against token cost. Run: opencode model list   or   antigravity model list.
# Edit these anytime with: /dp-config models

coding_models:
  claude:
    power:    "$CL_POWER"
    standard: "$CL_STANDARD"
    lite:     "$CL_LITE"

  opencode:
    power:    "$OC_POWER"
    standard: "$OC_STANDARD"
    lite:     "$OC_LITE"
    fallback: "$OC_FALLBACK"   # used when GitHub Copilot is unavailable ("" = opencode default)

  antigravity:
    power:    "$AG_POWER"
    standard: "$AG_STANDARD"
    lite:     "$AG_LITE"

## Model Routing — Claude (orchestration phases: BA · Team Lead · QA)

models:
  ba:
    tier1: $T1_BA
    tier2: "$T2_BA"
    tier3: "$T3_BA"

  team_lead:
    tier1: $T1_LEAD
    tier2: "$T2_LEAD"
    tier3: "$T3_LEAD"

  qa:
    tier1: $T1_QA
    tier2: "$T2_QA"
    tier3: "$T3_QA"

## Fallback Behavior

fallback:
  auto_on_limit: true
  save_path: docs/fallback
  resume_command: "/ceo resume"
CONFIGEOF

info "project.config.md written"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 11 — UPDATE OPENCODE CONFIG (model default)
# ═════════════════════════════════════════════════════════════════════════════
if [ -f ".opencode/config.json" ] && command -v jq &>/dev/null; then
  DEFAULT_OC_MODEL="${OC_STANDARD:-}"   # opencode standard-tier model from the profile
  if [ "$CODING_ENGINE" = "opencode" ] && [ -n "$DEFAULT_OC_MODEL" ]; then
    jq --arg m "$DEFAULT_OC_MODEL" '.model = $m' .opencode/config.json > .opencode/config.json.tmp \
      && mv .opencode/config.json.tmp .opencode/config.json
    info ".opencode/config.json → model: $DEFAULT_OC_MODEL"
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 12 — SYNC AGENT FRONTMATTER
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 11 — Syncing Claude agent models..."

sync_model() {
  local file="$1" model="$2"
  [ -f "$file" ] && sed -i.bak "s/^model: .*/model: $model/" "$file" && rm -f "$file.bak" && info "$(basename $file) → $model"
}

sync_model ".claude/agents/team-lead.md" "$T1_LEAD"
sync_model ".claude/agents/team-ba.md"   "$T1_BA"
sync_model ".claude/agents/team-qa.md"   "$T1_QA"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 13 — GIT BRANCH SETUP
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 12 — Git branch setup..."

if git rev-parse --git-dir > /dev/null 2>&1; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
  if [ "$BASE_BRANCH" = "develop" ] && ! git show-ref --verify --quiet refs/heads/develop; then
    info "Creating develop branch..."
    git checkout -b develop
    git push -u origin develop 2>/dev/null || warn "Could not push develop — run: git push -u origin develop"
    git checkout "$CURRENT_BRANCH"
  else
    info "Branch: $BASE_BRANCH ✅"
  fi

  # Install the Conventional-Commits commit-msg hook.
  bash scripts/install-git-hooks.sh 2>/dev/null || warn "Could not install git hooks — run: bash scripts/install-git-hooks.sh"
fi

# ═════════════════════════════════════════════════════════════════════════════
# DONE
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  ✅  devpilot v${DEVPILOT_VERSION} installed${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  Project:        $PROJECT_NAME ($DETECTED_TYPE)"
echo "  Base branch:    $BASE_BRANCH"
echo "  Coding engine:  $CODING_ENGINE  (fallback: $FALLBACK_ENGINE)"
echo "  Runner:         $RUNNER_CLI"
echo ""
echo "  Installed:"
echo "    .claude/commands/    — slash commands for Claude Code"
echo "    .claude/agents/      — agent definitions"
echo "    .opencode/           — opencode project config"
echo "    AGENTS.md            — project context (opencode / antigravity)"
echo "    CLAUDE.md            — project context (Claude Code)"
echo "    .devpilot/           — rules, templates, skills"
echo "    scripts/             — git-flow, Jira, deploy helpers"
echo "    project.config.md    — engine + model config"
echo ""
echo "  ── Required setup ──────────────────────────────────────"
echo ""
echo "  1. Edit .devpilot/config.sh"
echo "     → JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN"
echo "     → GITHUB_ORG, GITHUB_REPO"
echo "     → DEV/SIT/UAT/PRD environment URLs"
echo ""
echo "  ── Start working ───────────────────────────────────────"
echo ""

if [ "$HAS_CLAUDE" = true ]; then
echo "  From Claude Code:"
echo "    /ceo your feature or bug description"
echo ""
fi

if [ "$RUNNER_CLI" = "opencode" ] || [ "$HAS_OPENCODE" = true ]; then
echo "  From opencode terminal:"
echo "    bash scripts/ceo.sh \"your feature or bug description\""
echo "    opencode < .claude/commands/ceo.md      (pipe command directly)"
echo ""
fi

if [ "$RUNNER_CLI" = "antigravity" ] || [ "$HAS_ANTIGRAVITY" = true ]; then
echo "  From antigravity terminal:"
echo "    bash scripts/ceo.sh \"your feature or bug description\""
echo "    antigravity < .claude/commands/ceo.md   (pipe command directly)"
echo ""
fi

echo "  ── Change config anytime ───────────────────────────────"
echo ""
echo "    /dp-config wizard       — re-run engine + model wizard"
echo "    /dp-config models       — switch coding engine / per-layer models"
echo "    Edit project.config.md directly"
echo ""

# Surface any skipped files last, so an incomplete install can't slip by unnoticed.
fetch_summary || true
