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
#   project.config.md — engine + model config (edit with /binaa reconfig)
# =============================================================================
set -euo pipefail

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

# Download a file — from local clone if available, else from GitHub
fetch() {
  local src="$1"  # path relative to devpilot root
  local dst="$2"  # destination path

  mkdir -p "$(dirname "$dst")"

  if [ -n "$DEVPILOT_LOCAL" ] && [ -f "$DEVPILOT_LOCAL/$src" ]; then
    cp "$DEVPILOT_LOCAL/$src" "$dst"
  else
    curl -fsSL "$REPO/$src" -o "$dst" 2>/dev/null || warn "$src not found — skipping"
  fi
}

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

if [ -f "angular.json" ];                               then DETECT_FRONTEND="angular";  echo "  ✅ Angular (angular.json)"
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

if find . -maxdepth 4 \( -name "*.sql" -o -name "*migration*" -o -name "*Migration*" \) 2>/dev/null | grep -q .; then
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
# STEP 5 — CODING MODELS (opencode + antigravity)
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 5 — Coding models..."

OC_MODEL_FE="github-copilot/gpt-4o"
OC_MODEL_BE="github-copilot/gpt-4o"
OC_MODEL_DB="github-copilot/gpt-4o"
OC_MODEL_INT="github-copilot/gpt-4o"

AG_MODEL_FE=""
AG_MODEL_BE=""
AG_MODEL_DB=""
AG_MODEL_INT=""

# opencode models
if [ "$CODING_ENGINE" = "opencode" ] || [ "$FALLBACK_ENGINE" = "opencode" ] || [ "$HAS_OPENCODE" = true ]; then
  echo ""
  echo "  opencode / GitHub Copilot models:"
  echo "    github-copilot/gpt-4o           — best all-round (default)"
  echo "    github-copilot/gpt-3.5-codex    — fast and cheap"
  echo "    github-copilot/claude-3.5-sonnet — strong reasoning"
  echo "  Run: opencode model list — to see all available"
  echo ""
  ask "  Frontend model [$OC_MODEL_FE]: "; read -r v; [ -n "$v" ] && OC_MODEL_FE="$v"
  ask "  Backend model  [$OC_MODEL_BE]: "; read -r v; [ -n "$v" ] && OC_MODEL_BE="$v"
  ask "  DB model       [$OC_MODEL_DB]: "; read -r v; [ -n "$v" ] && OC_MODEL_DB="$v"
  if [ "$AGENT_INTEGRATION" = "true" ]; then
    ask "  Integration    [$OC_MODEL_INT]: "; read -r v; [ -n "$v" ] && OC_MODEL_INT="$v"
  fi
fi

# antigravity models
if [ "$CODING_ENGINE" = "antigravity" ] || [ "$FALLBACK_ENGINE" = "antigravity" ] || [ "$HAS_ANTIGRAVITY" = true ]; then
  echo ""
  echo "  antigravity models (run: antigravity model list — to see all available):"
  echo ""
  ask "  Frontend model [leave blank to set later]: "; read -r v; AG_MODEL_FE="$v"
  ask "  Backend model  [leave blank to set later]: "; read -r v; AG_MODEL_BE="$v"
  ask "  DB model       [leave blank to set later]: "; read -r v; AG_MODEL_DB="$v"
  if [ "$AGENT_INTEGRATION" = "true" ]; then
    ask "  Integration    [leave blank to set later]: "; read -r v; AG_MODEL_INT="$v"
  fi
fi

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
# STEP 7 — CLAUDE ORCHESTRATOR MODELS (BA, Team Lead, QA)
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 7 — Claude orchestrator models (BA · Team Lead · QA)..."

T1_BA="claude-haiku-4-5-20251001"
T2_BA="copilot: Gemini 3.5 Flash"
T3_BA="free: DeepSeek V4 Flash Free"

T1_LEAD="claude-sonnet-4-6"
T2_LEAD="copilot: Gemini 2.5 Pro"
T3_LEAD="free: DeepSeek V4 Flash Free"

T1_QA="claude-haiku-4-5-20251001"
T2_QA="copilot: GPT-5-mini"
T3_QA="free: Nemotron 3 Super Free"

echo ""
echo "  Defaults:  BA → haiku-4-5   Lead → sonnet-4-6   QA → haiku-4-5"
ask "  Use defaults? [Y/n]: "; read -r ACCEPT_MODELS

if [[ "${ACCEPT_MODELS:-Y}" =~ ^[Nn] ]]; then
  echo "  Press Enter to keep the default."
  ask "  BA Tier 1 [$T1_BA]: ";         read -r v; [ -n "$v" ] && T1_BA="$v"
  ask "  Team Lead Tier 1 [$T1_LEAD]: "; read -r v; [ -n "$v" ] && T1_LEAD="$v"
  ask "  QA Tier 1 [$T1_QA]: ";         read -r v; [ -n "$v" ] && T1_QA="$v"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8 — PROJECT IDENTITY
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 8 — Project identity..."

DEFAULT_NAME=$(basename "$PROJECT_ROOT")
ask "  Project name [$DEFAULT_NAME]: ";    read -r PROJECT_NAME;   [ -z "$PROJECT_NAME" ]   && PROJECT_NAME="$DEFAULT_NAME"
ask "  Jira prefix (e.g. MSK, APP): ";     read -r TICKET_PREFIX;  [ -z "$TICKET_PREFIX" ]  && TICKET_PREFIX="KEY"
ask "  Base branch [main]: ";              read -r BASE_BRANCH;    [ -z "$BASE_BRANCH" ]    && BASE_BRANCH="main"

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
for f in rules.md config.sh; do
  fetch ".devpilot/$f" ".devpilot/$f"
done

for f in 6-env-diff.md 6-generate-tests.md; do
  fetch ".devpilot/prompts/$f" ".devpilot/prompts/$f"
done

for f in ba-agent.md lead-plan.md lead-review.md frontend-agent.md dotnet-agent.md qa-agent.md; do
  fetch ".devpilot/prompts/team/$f" ".devpilot/prompts/team/$f"
done

for f in requirements.md implementation-plan.md qa-report.md review-report.md adr.md domain-model.md; do
  fetch ".devpilot/templates/team/$f" ".devpilot/templates/team/$f"
done

for f in changelog-entry.md ticket.md; do
  fetch ".devpilot/templates/$f" ".devpilot/templates/$f"
done

for f in feature.md bugfix.md hotfix.md; do
  fetch ".devpilot/checklists/$f" ".devpilot/checklists/$f"
done

for f in get-shit-done.md spec-first.md security-scan.md performance-review.md architecture-guard.md self-heal.md definition-of-done.md compact-context.md; do
  fetch ".devpilot/skills/$f" ".devpilot/skills/$f"
done

fetch ".devpilot/config/models.md" ".devpilot/config/models.md"

# .claude/ — Claude Code commands + agent definitions
info "Installing .claude/..."
for f in ceo.md ceo-plan.md ceo-run.md ceo-fix.md ceo-fe.md ceo-be.md ceo-db.md ceo-int.md \
         ceo-issue.md ceo-subdomain.md \
         binaa.md binaa-sit.md binaa-uat.md binaa-prd.md binaa-hotfix.md \
         binaa-reconfig.md binaa-models.md binaa-index.md \
         team-task.md team-ba.md team-lead.md team-frontend.md team-dotnet.md team-qa.md; do
  fetch ".claude/commands/$f" ".claude/commands/$f"
done

for f in team-lead.md team-ba.md team-frontend.md team-dotnet.md team-qa.md; do
  fetch ".claude/agents/$f" ".claude/agents/$f"
done

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
for f in git-flow.sh new-feature.sh run-command.sh checkpoint.sh devpilot-config.sh \
          deploy-dev.sh deploy-sit.sh deploy-uat.sh deploy-prd.sh \
          create-jira-ticket.sh create-jira-epic.sh \
          update-jira-status.sh update-jira-description.sh \
          add-jira-comment.sh generate-project-index.sh \
          ceo.sh ceo-fix.sh ceo-plan.sh ceo-run.sh \
          ceo-fe.sh ceo-be.sh ceo-db.sh ceo-int.sh; do
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
  for entry in ".devpilot/config.sh" ".env" ".env.local" "docs/fallback/"; do
    grep -qF "$entry" .gitignore || echo "$entry" >> .gitignore
  done
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 10 — WRITE project.config.md
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 10 — Writing project.config.md..."

cat > project.config.md << CONFIGEOF
# Project Configuration
# Generated by devpilot install.sh — edit with /binaa reconfig

## Project Identity

project_name: "$PROJECT_NAME"
project_type: $DETECTED_TYPE
ticket_prefix: "$TICKET_PREFIX"
base_branch: $BASE_BRANCH

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
  runner: $RUNNER_CLI
  fallback: $FALLBACK_ENGINE

## Coding Engine Models
# Run: opencode model list   or   antigravity model list   (to see available)
# Edit these anytime with: /binaa-models

coding_models:
  opencode:
    frontend:    "$OC_MODEL_FE"
    backend:     "$OC_MODEL_BE"
    db:          "$OC_MODEL_DB"
    integration: "$OC_MODEL_INT"

  antigravity:
    frontend:    "$AG_MODEL_FE"
    backend:     "$AG_MODEL_BE"
    db:          "$AG_MODEL_DB"
    integration: "$AG_MODEL_INT"

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
  DEFAULT_OC_MODEL="$OC_MODEL_BE"
  if [ "$CODING_ENGINE" = "opencode" ] && [ -n "$DEFAULT_OC_MODEL" ]; then
    jq --arg m "$DEFAULT_OC_MODEL" '.model = $m' .opencode/config.json > .opencode/config.json.tmp \
      && mv .opencode/config.json.tmp .opencode/config.json
    info ".opencode/config.json → model: $DEFAULT_OC_MODEL"
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 12 — SYNC AGENT FRONTMATTER
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 12 — Syncing Claude agent models..."

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
section "STEP 13 — Git branch setup..."

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
echo "    /binaa reconfig         — re-run engine + model wizard"
echo "    /binaa-models engine opencode   — switch coding engine"
echo "    Edit project.config.md directly"
echo ""
