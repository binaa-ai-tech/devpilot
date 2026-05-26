#!/usr/bin/env bash
# =============================================================================
# devpilot — Installer
#
# Run from the root of any project:
#   curl -s https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh | bash
# Or locally:
#   bash /path/to/devpilot/install.sh
# =============================================================================
set -euo pipefail

REPO="https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main"
PROJECT_ROOT=$(pwd)

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

info()    { echo -e "${GREEN}[install]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET} $*"; }
section() { echo -e "\n${CYAN}${BOLD}$*${RESET}"; }
ask()     { echo -e "${BOLD}$*${RESET}"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
DEVPILOT_VERSION=$(curl -fsSL "$REPO/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "1.1.0")

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  devpilot v${DEVPILOT_VERSION} — Installer${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  Project: $PROJECT_ROOT"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — SYSTEM SCAN
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 1 — Scanning system..."

HAS_CLAUDE=false
HAS_OPENCODE=false
HAS_GH=false
HAS_GIT=false
HAS_JQ=false

command -v claude    &>/dev/null && HAS_CLAUDE=true    && echo "  ✅ claude CLI found     — Claude Pro agents available"    || echo "  ❌ claude not found     — Install Claude Code to use Claude agents"
command -v opencode  &>/dev/null && HAS_OPENCODE=true  && echo "  ✅ opencode found       — GitHub Copilot fallback available" || echo "  ⚠️  opencode not found   — No Copilot fallback (install opencode for resilience)"
command -v gh        &>/dev/null && HAS_GH=true        && echo "  ✅ gh CLI found         — GitHub PRs and Actions supported" || echo "  ❌ gh not found         — Install GitHub CLI for PR automation"
command -v git       &>/dev/null && HAS_GIT=true       && echo "  ✅ git found"                                              || echo "  ❌ git not found        — Required"
command -v jq        &>/dev/null && HAS_JQ=true        && echo "  ✅ jq found"                                              || echo "  ⚠️  jq not found         — Some scripts may be limited"

if [ "$HAS_GIT" = false ]; then
  echo ""
  echo "  ❌ git is required. Install git and re-run."
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

# Frontend detection
if [ -f "angular.json" ];                    then DETECT_FRONTEND="angular";  echo "  ✅ Angular detected (angular.json)"
elif grep -q '"next"' package.json 2>/dev/null; then DETECT_FRONTEND="nextjs"; echo "  ✅ Next.js detected (package.json)"
elif grep -q '"react"' package.json 2>/dev/null; then DETECT_FRONTEND="react"; echo "  ✅ React detected (package.json)"
elif grep -q '"vue"' package.json 2>/dev/null;   then DETECT_FRONTEND="vue";   echo "  ✅ Vue detected (package.json)"
elif [ -f "package.json" ];                  then DETECT_FRONTEND="node";    echo "  ✅ Node/JS project detected (package.json)"
fi

# Backend detection
if find . -maxdepth 3 -name "*.sln" -o -name "*.csproj" 2>/dev/null | grep -q .; then
  DETECT_BACKEND="dotnet"; echo "  ✅ .NET detected (*.csproj / *.sln)"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  DETECT_BACKEND="python"; echo "  ✅ Python detected"
elif [ -f "go.mod" ]; then
  DETECT_BACKEND="go"; echo "  ✅ Go detected"
elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
  DETECT_BACKEND="java"; echo "  ✅ Java detected"
fi

# Database detection
if find . -maxdepth 4 \( -name "*.sql" -o -name "*migration*" -o -name "*Migration*" \) 2>/dev/null | grep -q .; then
  DETECT_DB="sqlserver"; echo "  ✅ Database migrations detected"
elif [ -f "flyway.conf" ] || find . -maxdepth 3 -name "*.flyway" 2>/dev/null | grep -q .; then
  DETECT_DB="sqlserver"; echo "  ✅ Flyway migrations detected"
fi

# Integration services detection
if grep -rq -i "rabbitmq\|kafka\|servicebus\|azure.messaging\|masstransit" . --include="*.json" --include="*.cs" --include="*.ts" 2>/dev/null; then
  DETECT_INTEGRATION="yes"; echo "  ✅ Integration/messaging detected"
fi

# Determine project type
if [ "$DETECT_FRONTEND" != "none" ] && [ "$DETECT_BACKEND" != "none" ]; then
  DETECTED_TYPE="fullstack"
elif [ "$DETECT_FRONTEND" != "none" ]; then
  DETECTED_TYPE="frontend"
elif [ "$DETECT_BACKEND" != "none" ]; then
  DETECTED_TYPE="backend"
else
  DETECTED_TYPE="fullstack"
fi

echo ""
echo "  Detected stack:"
echo "    Frontend:    $DETECT_FRONTEND"
echo "    Backend:     $DETECT_BACKEND"
echo "    Database:    $DETECT_DB"
echo "    Integration: $DETECT_INTEGRATION"
echo "    Project type: $DETECTED_TYPE"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3 — RECOMMEND AGENT TEAM
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 3 — Recommended agent team..."

AGENT_FRONTEND="false"
AGENT_BACKEND="false"
AGENT_DB="false"
AGENT_INTEGRATION="false"

[ "$DETECT_FRONTEND" != "none" ]     && AGENT_FRONTEND="true"
[ "$DETECT_BACKEND" != "none" ]      && AGENT_BACKEND="true"
[ "$DETECT_DB" != "none" ]           && AGENT_DB="true"
[ "$DETECT_INTEGRATION" = "yes" ]    && AGENT_INTEGRATION="true"

echo "  Recommended team:"
echo "    ✅ BA Agent"
echo "    ✅ Team Lead"
[ "$AGENT_FRONTEND" = "true" ]     && echo "    ✅ Frontend Developer"    || echo "    ⬜ Frontend Developer (not detected)"
[ "$AGENT_BACKEND" = "true" ]      && echo "    ✅ Backend Developer"     || echo "    ⬜ Backend Developer (not detected)"
[ "$AGENT_DB" = "true" ]           && echo "    ✅ DB Agent"              || echo "    ⬜ DB Agent (not detected)"
[ "$AGENT_INTEGRATION" = "true" ]  && echo "    ✅ Integration Agent"     || echo "    ⬜ Integration Agent (not detected)"
echo "    ✅ QA Engineer"

echo ""
ask "  Accept recommended team? [Y/n]: "
read -r ACCEPT_TEAM
if [[ "$ACCEPT_TEAM" =~ ^[Nn] ]]; then
  ask "  Enable Frontend agent? [y/N]: ";    read -r v; [[ "$v" =~ ^[Yy] ]] && AGENT_FRONTEND="true"  || AGENT_FRONTEND="false"
  ask "  Enable Backend agent? [y/N]: ";     read -r v; [[ "$v" =~ ^[Yy] ]] && AGENT_BACKEND="true"   || AGENT_BACKEND="false"
  ask "  Enable DB agent? [y/N]: ";          read -r v; [[ "$v" =~ ^[Yy] ]] && AGENT_DB="true"        || AGENT_DB="false"
  ask "  Enable Integration agent? [y/N]: "; read -r v; [[ "$v" =~ ^[Yy] ]] && AGENT_INTEGRATION="true" || AGENT_INTEGRATION="false"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4 — IMPLEMENTATION ENGINE + MODEL CONFIG
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 4 — Implementation engine + model config..."

# Defaults
IMPL_ENGINE="claude"
IMPL_MODEL_FE="github-copilot/gpt-4o"
IMPL_MODEL_BE="github-copilot/gpt-4o"
IMPL_MODEL_DB="github-copilot/gpt-4o"
IMPL_MODEL_INT="github-copilot/gpt-4o"

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
echo "  Who writes the code?"
echo ""
echo "    [1] claude (recommended)"
echo "        Fully automatic — Claude subagents handle everything end-to-end."
echo "        BA → planning → coding → QA → PR with zero manual steps."
echo "    [2] opencode"
echo "        Claude handles BA, planning, QA, review."
echo "        You run opencode in your terminal for coding phases."
echo ""
ask "  Choice [1]: "; read -r ENG_CHOICE

case "${ENG_CHOICE:-1}" in
  2)
    IMPL_ENGINE="opencode"
    echo ""
    echo "  Common GitHub Copilot models (run: opencode model list — to see all):"
    echo ""
    echo "    github-copilot/gpt-4o           — best all-round (default)"
    echo "    github-copilot/gpt-3.5-codex    — fast and cheap"
    echo "    github-copilot/claude-3.5-sonnet — strong reasoning + code quality"
    echo ""
    echo "  Configure one model per developer role."
    echo "  Press Enter to use the default (github-copilot/gpt-4o) for each."
    echo ""
    ask "  Frontend dev model (Angular/React/Vue) [$IMPL_MODEL_FE]: "; read -r v; [ -n "$v" ] && IMPL_MODEL_FE="$v"
    ask "  Backend dev model (.NET/Node/Python)   [$IMPL_MODEL_BE]: "; read -r v; [ -n "$v" ] && IMPL_MODEL_BE="$v"
    ask "  DB dev model (migrations/SQL)          [$IMPL_MODEL_DB]: "; read -r v; [ -n "$v" ] && IMPL_MODEL_DB="$v"
    ask "  Integration dev model (messaging)      [$IMPL_MODEL_INT]: "; read -r v; [ -n "$v" ] && IMPL_MODEL_INT="$v"
    echo ""
    info "opencode models configured:"
    info "  Frontend:    $IMPL_MODEL_FE"
    info "  Backend:     $IMPL_MODEL_BE"
    info "  DB:          $IMPL_MODEL_DB"
    info "  Integration: $IMPL_MODEL_INT"
    ;;
  *)
    IMPL_ENGINE="claude"
    IMPL_MODEL_FE=""
    IMPL_MODEL_BE=""
    IMPL_MODEL_DB=""
    IMPL_MODEL_INT=""
    info "Engine set to: claude (fully automatic — no manual steps)"
    ;;
esac

echo ""
echo "  Claude model routing (BA, Team Lead, QA only — coding is handled by opencode):"
echo ""
echo "  Defaults:"
echo "    BA:        claude-haiku-4-5-20251001   (lightweight, fast)"
echo "    Team Lead: claude-sonnet-4-6           (planning + code review)"
echo "    QA:        claude-haiku-4-5-20251001   (lightweight, fast)"
echo ""
ask "  Use defaults? [Y/n]: "; read -r ACCEPT_MODELS

if [[ "$ACCEPT_MODELS" =~ ^[Nn] ]]; then
  echo "  Press Enter to keep the default for any field."
  echo ""
  ask "  BA — Tier 1 [$T1_BA]: ";         read -r v; [ -n "$v" ] && T1_BA="$v"
  ask "  Team Lead — Tier 1 [$T1_LEAD]: "; read -r v; [ -n "$v" ] && T1_LEAD="$v"
  ask "  QA — Tier 1 [$T1_QA]: ";         read -r v; [ -n "$v" ] && T1_QA="$v"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4b — COMMAND RUNNER (which AI CLI runs /ceo from terminal)
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 4b — Command runner config..."

RUNNER_CLI="claude"
RUNNER_MODEL=""

echo ""
echo "  Run /ceo commands from terminal with any AI:"
echo ""
echo "    [1] Claude Code CLI (claude)         — default, works inside Claude Code"
echo "    [2] opencode                         — run with GitHub Copilot models"
echo "    [3] custom                           — any CLI that reads prompt via stdin"
echo ""
ask "  Choice [1]: "; read -r RUNNER_CHOICE

case "${RUNNER_CHOICE:-1}" in
  2)
    RUNNER_CLI="opencode"
    echo ""
    echo "  Common GitHub Copilot models:"
    echo "    github-copilot/gpt-5.3-codex    — strong code generation"
    echo "    github-copilot/gpt-4o           — best all-round"
    echo "    github-copilot/gemini-2.5-pro   — Google alternative"
    echo ""
    ask "  opencode model [github-copilot/gpt-5.3-codex]: "; read -r v
    RUNNER_MODEL="${v:-github-copilot/gpt-5.3-codex}"
    info "Runner: opencode ($RUNNER_MODEL)"
    ;;
  3)
    ask "  Custom CLI command (e.g. aider --model gpt-4o): "; read -r v
    RUNNER_CLI="${v:-claude}"
    info "Runner: $RUNNER_CLI"
    ;;
  *)
    RUNNER_CLI="claude"
    info "Runner: claude (Claude Code CLI)"
    ;;
esac

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5 — PROJECT IDENTITY
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 5 — Project identity..."

DEFAULT_NAME=$(basename "$PROJECT_ROOT")
ask "  Project name [$DEFAULT_NAME]: "; read -r PROJECT_NAME
[ -z "$PROJECT_NAME" ] && PROJECT_NAME="$DEFAULT_NAME"

ask "  Jira ticket prefix (e.g. MSK, APP): "; read -r TICKET_PREFIX
[ -z "$TICKET_PREFIX" ] && TICKET_PREFIX="KEY"

ask "  Base branch [main]: "; read -r BASE_BRANCH
[ -z "$BASE_BRANCH" ] && BASE_BRANCH="main"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6 — DOWNLOAD FILES
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 6 — Downloading dev process files..."

mkdir -p .devpilot/{prompts/team,templates/team,checklists,impact-maps,skills,config}
mkdir -p scripts
mkdir -p .github/ISSUE_TEMPLATE
mkdir -p .claude/commands .claude/agents
mkdir -p docs/{requirements,plans,qa,reviews,adrs,domain-models,fallback,implementation,team}

# Core .aidev files
info "Downloading .aidev files..."
for f in README.md rules.md config.sh; do
  curl -fsSL "$REPO/.devpilot/$f" -o ".devpilot/$f" 2>/dev/null || warn "$f not found — skipping"
done

for f in 0-start-work.md 1-triage.md 2-investigate.md \
          4-implement-feature.md 4-implement-bugfix.md 4-implement-refactor.md \
          5-self-review.md 6-env-diff.md 6-generate-tests.md 7-pr-description.md; do
  curl -fsSL "$REPO/.devpilot/prompts/$f" -o ".devpilot/prompts/$f" 2>/dev/null || warn "prompts/$f not found — skipping"
done

for f in ba-agent.md lead-plan.md lead-review.md frontend-agent.md dotnet-agent.md qa-agent.md; do
  curl -fsSL "$REPO/.devpilot/prompts/team/$f" -o ".devpilot/prompts/team/$f" 2>/dev/null || warn "team/$f not found — skipping"
done

for f in impact-map.md pr-description.md ticket.md changelog-entry.md; do
  curl -fsSL "$REPO/.devpilot/templates/$f" -o ".devpilot/templates/$f" 2>/dev/null || warn "templates/$f not found — skipping"
done

for f in requirements.md implementation-plan.md qa-report.md review-report.md adr.md domain-model.md; do
  curl -fsSL "$REPO/.devpilot/templates/team/$f" -o ".devpilot/templates/team/$f" 2>/dev/null || warn "templates/team/$f not found — skipping"
done

for f in feature.md bugfix.md hotfix.md; do
  curl -fsSL "$REPO/.devpilot/checklists/$f" -o ".devpilot/checklists/$f" 2>/dev/null || warn "checklists/$f not found — skipping"
done

# Skills
info "Downloading skills..."
for f in get-shit-done.md spec-first.md security-scan.md performance-review.md architecture-guard.md self-heal.md definition-of-done.md; do
  curl -fsSL "$REPO/.devpilot/skills/$f" -o ".devpilot/skills/$f" 2>/dev/null || warn "skills/$f not found — skipping"
done

# Scripts
info "Downloading scripts..."
for f in git-flow.sh new-feature.sh \
          deploy-dev.sh deploy-sit.sh deploy-uat.sh deploy-prd.sh \
          create-jira-ticket.sh create-jira-epic.sh \
          update-jira-status.sh update-jira-description.sh \
          add-jira-comment.sh generate-project-index.sh; do
  curl -fsSL "$REPO/scripts/$f" -o "scripts/$f" 2>/dev/null || warn "scripts/$f not found — skipping"
  chmod +x "scripts/$f" 2>/dev/null || true
done

# Claude Code commands
info "Downloading Claude Code commands..."
for f in ceo.md binaa.md binaa-dev.md binaa-sit.md binaa-uat.md binaa-prd.md binaa-hotfix.md \
          binaa-reconfig.md binaa-models.md binaa-index.md \
          team-task.md team-ba.md team-lead.md team-frontend.md team-dotnet.md team-qa.md; do
  curl -fsSL "$REPO/.claude/commands/$f" -o ".claude/commands/$f" 2>/dev/null || warn "commands/$f not found — skipping"
done

# Claude Code agent definitions
info "Downloading agent definitions..."
for f in team-lead.md team-ba.md team-frontend.md team-dotnet.md team-qa.md; do
  curl -fsSL "$REPO/.claude/agents/$f" -o ".claude/agents/$f" 2>/dev/null || warn "agents/$f not found — skipping"
done

# GitHub templates (no CI/CD workflows — devpilot does not ship app workflows)
info "Downloading GitHub templates..."
for f in BRANCH_NAMING.md COMMIT_CONVENTION.md pull_request_template.md; do
  curl -fsSL "$REPO/.github/$f" -o ".github/$f" 2>/dev/null || true
done
for f in bug_report.md feature_request.md; do
  curl -fsSL "$REPO/.github/ISSUE_TEMPLATE/$f" -o ".github/ISSUE_TEMPLATE/$f" 2>/dev/null || true
done

# Misc
[ ! -f ".env.example" ] && curl -fsSL "$REPO/.env.example" -o ".env.example" 2>/dev/null || true
[ ! -f ".commitlintrc.json" ] && curl -fsSL "$REPO/.commitlintrc.json" -o ".commitlintrc.json" 2>/dev/null || true
curl -fsSL "$REPO/docs/team/README.md" -o "docs/team/README.md" 2>/dev/null || true
curl -fsSL "$REPO/.devpilot/config/models.md" -o ".devpilot/config/models.md" 2>/dev/null || true

for d in requirements plans qa reviews adrs domain-models fallback implementation; do
  touch "docs/$d/.gitkeep"
done
touch .devpilot/impact-maps/.gitkeep

# CLAUDE.md
if [ ! -f "CLAUDE.md" ]; then
  curl -fsSL "$REPO/CLAUDE.md" -o "CLAUDE.md" 2>/dev/null || true
fi

# .gitignore additions
if [ -f ".gitignore" ]; then
  for entry in ".devpilot/config.sh" ".env" ".env.local" ".env.*.local" "docs/fallback/"; do
    grep -qF "$entry" .gitignore || echo "$entry" >> .gitignore
  done
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7 — WRITE project.config.md
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 7 — Writing project.config.md..."

cat > project.config.md << CONFIGEOF
# Project Configuration
# Generated by install.sh — re-run with: /binaa reconfig

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
# BA, Team Lead, and QA always enabled.
# Disable frontend/backend/db/integration if that layer is not in your project.

agents:
  ba:           { enabled: true }
  team_lead:    { enabled: true }
  frontend:     { enabled: $AGENT_FRONTEND }
  backend:      { enabled: $AGENT_BACKEND }
  db:           { enabled: $AGENT_DB }
  integration:  { enabled: $AGENT_INTEGRATION }
  qa:           { enabled: true }

## Implementation Engine
#
# Who writes the code?
#   opencode — Claude handles BA/planning/QA/review; you run opencode CLI for coding
#   claude   — Claude subagents handle everything (use when opencode is unavailable)
#
# opencode model: exact model ID passed to \`opencode --model "..."\`
# Run: opencode model list — to see available models

implementation:
  engine: $IMPL_ENGINE
  model_frontend:    "$IMPL_MODEL_FE"    # Angular / React / Vue
  model_backend:     "$IMPL_MODEL_BE"    # .NET / Node / Python
  model_db:          "$IMPL_MODEL_DB"    # DB migrations and SQL
  model_integration: "$IMPL_MODEL_INT"   # Messaging / Services

## Model Routing — Claude (non-coding phases only)
#
# Tier 1: Claude Pro (primary)
# Tier 2: GitHub Copilot via opencode (fallback when Claude hits limits)
# Tier 3: OpenCode Zen Free (last resort)
#
# Coding agents (frontend, backend, db, integration) use opencode above — not Claude.

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

## Command Runner
# Run /ceo commands from any terminal: bash scripts/ceo.sh "description"
# Inside Claude Code: use slash commands directly (/ceo, /ceo-fix, etc.)

runner:
  cli:   $RUNNER_CLI
  model: "$RUNNER_MODEL"
CONFIGEOF

info "project.config.md written"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8 — SYNC AGENT FRONTMATTER MODELS
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 8 — Syncing agent model frontmatter..."

sync_agent_model() {
  local file="$1"
  local model="$2"
  if [ -f "$file" ]; then
    # Replace model: line in frontmatter
    if command -v sed &>/dev/null; then
      sed -i.bak "s/^model: .*/model: $model/" "$file" && rm -f "$file.bak"
      info "$(basename $file) → $model"
    fi
  fi
}

sync_agent_model ".claude/agents/team-lead.md" "$T1_LEAD"
sync_agent_model ".claude/agents/team-ba.md"   "$T1_BA"
sync_agent_model ".claude/agents/team-qa.md"   "$T1_QA"
# Note: team-frontend.md and team-dotnet.md are only used when engine=claude.
# Their model frontmatter is informational — opencode is the default coding engine.

# ═════════════════════════════════════════════════════════════════════════════
# STEP 9 — GIT BRANCH SETUP
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 9 — Git branch setup..."

if git rev-parse --git-dir > /dev/null 2>&1; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
  if [ "$BASE_BRANCH" = "develop" ] && ! git show-ref --verify --quiet refs/heads/develop; then
    info "Creating develop branch from $CURRENT_BRANCH..."
    git checkout -b develop
    git push -u origin develop 2>/dev/null || warn "Could not push develop — run: git push -u origin develop"
    git checkout "$CURRENT_BRANCH"
  else
    info "Branch setup: using $BASE_BRANCH ✅"
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# DONE
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  ✅  devpilot installed${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "  Project:   $PROJECT_NAME ($DETECTED_TYPE)"
echo "  Branch:    $BASE_BRANCH"
echo "  Agents:    BA, Team Lead$([ "$AGENT_FRONTEND" = "true" ] && echo ", Frontend")$([ "$AGENT_BACKEND" = "true" ] && echo ", Backend")$([ "$AGENT_DB" = "true" ] && echo ", DB")$([ "$AGENT_INTEGRATION" = "true" ] && echo ", Integration"), QA"
echo ""
echo "  ── Required setup ──────────────────────────────────────"
echo ""
echo "  1. Edit .devpilot/config.sh"
echo "     → JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN"
echo "     → GITHUB_ORG, GITHUB_REPO"
echo "     → DEV/SIT/UAT/PRD environment URLs"
echo ""
echo "  2. Add GitHub Secrets (repo Settings → Secrets → Actions):"
echo "     DEPLOY_HOOK_DEV, DEPLOY_HOOK_SIT, DEPLOY_HOOK_UAT, DEPLOY_HOOK_PRD"
echo ""
echo "  3. Create GitHub Environments: dev, sit, uat, prd"
echo ""
echo "  ── Start working ───────────────────────────────────────"
echo ""
echo "   /ceo your feature or bug description   ← single entry point"
echo ""
echo "  ── Change model config anytime ─────────────────────────"
echo ""
echo "   /binaa reconfig                         ← re-run model wizard"
echo ""
echo "  ── If Claude hits limits during work ───────────────────"
echo ""
echo "   The agent will output an opencode command to run."
echo "   After opencode finishes, run: /ceo resume"
echo ""
