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
#   .devpilot/        — shared rules, prompts, templates, skills
#   scripts/          — git-flow, Jira, test, deploy helpers
#   CLAUDE.md         — project context (Claude Code)
#   project.config.md — team + Claude model config (edit with /dp-setup wizard)
# =============================================================================
set -euo pipefail

# Non-interactive mode: --defaults / -y accepts every recommended default.
DEVPILOT_DEFAULTS=0
for _arg in "$@"; do
  case "$_arg" in --defaults|-y) DEVPILOT_DEFAULTS=1 ;; esac
done

# When piped via curl | bash, stdin IS the script — bash and read() both fight over it.
# Fix: download a clean copy to a temp file and re-exec from disk, redirecting stdin
# from the controlling terminal so every `read` prompt gets the keyboard, not the pipe.
# Re-exec ONLY when actually piped ($0 isn't a file on disk) — a disk run with
# non-tty stdin (CI, --defaults) must keep running THIS version, not re-download.
if [ ! -t 0 ] && [ -z "${DEVPILOT_REEXEC:-}" ] && [ ! -f "$0" ]; then
  if [ "$DEVPILOT_DEFAULTS" = 1 ]; then
    TMPFILE=$(mktemp "${TMPDIR:-/tmp}/devpilot-install.XXXXXX")
    curl -fsSL "https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh" -o "$TMPFILE"
    DEVPILOT_REEXEC=1 bash "$TMPFILE" "$@" < /dev/null
    rm -f "$TMPFILE"
    exit $?
  fi
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
section() {
  echo ""
  echo -e "${CYAN}${BOLD}╭──────────────────────────────────────────────────────────╮${RESET}"
  printf  "${CYAN}${BOLD}│${RESET}  ${BOLD}%-56s${RESET}${CYAN}${BOLD}│${RESET}\n" "$*"
  echo -e "${CYAN}${BOLD}╰──────────────────────────────────────────────────────────╯${RESET}"
}
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
# and CLAUDE.md are left exactly as they are.
# (Keep these lists in sync with STEP 9.)
run_update() {
  echo ""
  echo -e "${BOLD}  devpilot — update (config preserved)${RESET}"
  echo ""

  RULE_SNIPPETS="angular.md dotnet.md sqlserver.md"
  PROMPT_TEAM="ba-agent.md lead-plan.md lead-review.md frontend-agent.md dotnet-agent.md qa-agent.md"
  TEMPLATE_TEAM="requirements.md implementation-plan.md qa-report.md review-report.md adr.md domain-model.md jira-brief.md"
  SKILLS="core-rules.md definition-of-ready.md estimation-and-slicing.md architecture-guard.md angular-dev.md angular-testing.md accessibility.md dotnet-api.md efcore-sqlserver.md dotnet-testing.md api-contract.md test-case-design.md test-strategy.md ui-e2e-playwright.md token-lean-testing.md test-guard.md performance.md code-review.md security-scan.md definition-of-done.md auto-merge.md release-ops.md self-heal.md README.md"
  CHECKLISTS="feature.md bugfix.md hotfix.md"
  CMDS="dp-deliver.md dp-plan.md dp-sprint.md dp-build.md dp-test.md dp-pr.md dp-release.md dp-hotfix.md dp-status.md dp-setup.md"
  AGENTS_LIST="team-lead.md team-ba.md team-frontend.md team-dotnet.md team-qa.md"
  SCRIPTS="git-flow.sh new-feature.sh resolve-model.sh model-profiles.sh preflight-scan.sh run-summary.sh checkpoint.sh devpilot-config.sh track.sh open-pr.sh scope.sh scope-guard.sh test-guard.sh run-tests.sh generate-ci.sh protect-branches.sh notify.sh session-start.sh doctor.sh status.sh audit.sh changelog.sh rollback.sh metrics.sh scope-hook.sh install-git-hooks.sh deploy-dev.sh deploy-sit.sh deploy-uat.sh deploy-prd.sh create-jira-ticket.sh create-jira-epic.sh update-jira-status.sh update-jira-description.sh add-jira-comment.sh generate-project-index.sh generate-backlog-index.sh jira-sprint.sh link-jira-issues.sh md-to-adf.sh jira-describe.sh"

  info "Refreshing .devpilot/rules..."
  fetch ".devpilot/rules.md" ".devpilot/rules.md"
  fetch ".devpilot/process.md" ".devpilot/process.md"
  fetch "docs/setup-guide.md" "docs/setup-guide.md"
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

  # Retired in the Angular + .NET consolidation — merged into the skills above.
  info "Removing retired skills, rules, and agents..."
  RETIRED="skills/get-shit-done.md skills/spec-first.md skills/compact-context.md skills/status-reporting.md
    skills/tech-debt.md skills/observability.md skills/clean-code.md skills/refactoring.md skills/version-control.md
    skills/ci-cd.md skills/release-discipline.md skills/reliability-slo.md skills/incident-postmortem.md
    skills/feature-flags.md skills/threat-modeling.md skills/secrets-management.md skills/data-privacy.md
    skills/dependency-management.md skills/cost-awareness.md skills/i18n.md skills/database-performance.md
    skills/data-migration-safety.md skills/api-design.md skills/e2e-testing.md skills/performance-review.md
    skills/performance-testing.md skills/debug-method.md skills/documentation.md
    rules/react-vue.md rules/node.md rules/python.md rules/go.md rules/java.md rules/postgres-mysql.md
    prompts/team/backend-agent.md"
  for f in $RETIRED; do rm -f ".devpilot/$f"; done
  rm -f .claude/agents/team-backend.md
  # Retired in the Claude-only move (OpenCode/Antigravity support + renamed commands).
  for f in ceo.md dp-config.md dp-autofix.md dp-review-fix.md dp-rollback.md; do rm -f ".claude/commands/$f"; done
  for f in run-command.sh run-mode.sh resolve-engine.sh ceo.sh dp-plan.sh dp-build.sh dp-sprint.sh dp-release.sh dp-status.sh dp-config.sh; do rm -f "scripts/$f"; done
  rm -rf .opencode

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

# --defaults: feed every prompt an empty answer → the recommended default wins.
# (Placed after --update dispatch; the script itself runs from disk at this point.)
if [ "$DEVPILOT_DEFAULTS" = 1 ]; then
  exec < <(yes '')
fi

# ── Banner ─────────────────────────────────────────────────────────────────────
echo ""
DEVPILOT_VERSION=""
if [ -n "$DEVPILOT_LOCAL" ] && [ -f "$DEVPILOT_LOCAL/VERSION" ]; then
  DEVPILOT_VERSION=$(cat "$DEVPILOT_LOCAL/VERSION" | tr -d '[:space:]')
else
  DEVPILOT_VERSION=$(curl -fsSL "$REPO/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "2.0.0")
fi

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
printf  "${CYAN}${BOLD}║${RESET}  ${BOLD}%-56s${RESET}${CYAN}${BOLD}║${RESET}\n" "devpilot v${DEVPILOT_VERSION} — AI Team System"
printf  "${CYAN}${BOLD}║${RESET}  %-56s${CYAN}${BOLD}║${RESET}\n" "Plan → Build → Test → Merge → Release, on autopilot"
echo -e "${CYAN}${BOLD}║${RESET}                                                          ${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "  Project:  $PROJECT_ROOT"
if [ "$DEVPILOT_DEFAULTS" = 1 ]; then
  echo "  Mode:     non-interactive (--defaults) — every recommendation accepted"
else
  echo "  Setup:    6 short steps (~4 min) · Enter accepts the recommended default"
  echo "  Safety:   nothing is written until you confirm the summary at the end"
fi
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — SYSTEM SCAN
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 1/6 · System scan — AI tools"

HAS_CLAUDE=false
HAS_GH=false
HAS_GIT=false

command -v claude       &>/dev/null && HAS_CLAUDE=true       && echo "  ✅ claude       — Claude Code CLI"           || echo "  ❌ claude       — not found (DevPilot runs on Claude Code: https://claude.ai/code)"
command -v gh           &>/dev/null && HAS_GH=true           && echo "  ✅ gh           — GitHub CLI (PR automation)" || echo "  ❌ gh           — not found (install for PR automation)"
command -v git          &>/dev/null && HAS_GIT=true          && echo "  ✅ git"                                        || echo "  ❌ git          — REQUIRED"
command -v jq           &>/dev/null                          && echo "  ✅ jq"                                        || echo "  ⚠️  jq           — not found (some scripts limited)"

if [ "$HAS_GIT" = false ]; then
  echo ""
  echo "  ❌ git is required. Install git and re-run."
  exit 1
fi

if [ "$HAS_CLAUDE" = false ]; then
  warn "Claude Code CLI not found — DevPilot runs inside Claude Code (CLI, desktop, IDE, or claude.ai/code)."
  warn "Install it from https://claude.ai/code; continuing so the files are ready when you do."
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2 — PROJECT STACK SCAN
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 2/6 · Project stack scan"

DETECT_FRONTEND="none"
DETECT_BACKEND="none"
DETECT_DB="none"
DETECT_INTEGRATION="none"

if [ -f "angular.json" ] || \
   grep -q '"@angular/core"' package.json 2>/dev/null || \
   grep -q '"@nx/angular"' package.json 2>/dev/null || \
   find . -maxdepth 4 -name "angular.json" 2>/dev/null | grep -q .; then
                                                             DETECT_FRONTEND="angular";  echo "  ✅ Angular"
elif [ -f "package.json" ]; then
  warn "package.json found but no Angular — DevPilot's frontend skills target Angular; frontend agent left off"
fi

if find . -maxdepth 3 \( -name "*.sln" -o -name "*.csproj" \) 2>/dev/null | grep -q .; then
  DETECT_BACKEND="dotnet"; echo "  ✅ .NET"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "go.mod" ] || [ -f "pom.xml" ]; then
  warn "non-.NET backend found — DevPilot's backend skills target .NET; backend agent left off"
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
section "STEP 3/6 · Agent team"

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
# STEP 4 — MODEL ASSIGNMENT (Claude: recommended tiers · one model · per-team)
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 4/6 · Claude model assignment"

# NOTE: profile mappings mirror scripts/model-profiles.sh — keep them in sync.
CL_OPUS="claude-opus-5-5"; CL_SONNET="claude-sonnet-5"; CL_HAIKU="claude-haiku-4-5-20251001"

CL_POWER="$CL_OPUS"; CL_STANDARD="$CL_SONNET"; CL_LITE="$CL_HAIKU"
CODING_PROFILE="auto"
MODEL_MODE="recommended"

# Role models — follow the choices below.
T1_BA="$CL_HAIKU"; T1_LEAD="$CL_SONNET"; T1_QA="$CL_HAIKU"
# Dev agent role models (synced into .claude/agents/*.md frontmatter in STEP 12)
T1_FE_DEV="$CL_SONNET"; T1_BE_DEV="$CL_SONNET"
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
  T1_FE_DEV="$CL_STANDARD"; T1_BE_DEV="$CL_STANDARD"
}

# Claude model menu (printed once) + per-role picker → sets PICKED_MODEL
claude_model_menu() {
  echo "    [1] Sonnet — strong all-round coder (recommended for most roles)"
  echo "    [2] Opus   — highest quality, most tokens (architecture / hard problems)"
  echo "    [3] Haiku  — fastest & cheapest (light tasks: BA, QA, simple changes)"
  echo "    [4] other  — type a model id"
}
pick_claude_model() {
  local role="$1" def="$2" defnum=1 choice
  case "$def" in
    "$CL_OPUS")  defnum=2 ;;
    "$CL_HAIKU") defnum=3 ;;
  esac
  ask "  $role [$defnum]: "; read -r choice
  case "${choice:-$defnum}" in
    2) PICKED_MODEL="$CL_OPUS" ;;
    3) PICKED_MODEL="$CL_HAIKU" ;;
    4) ask "    Model id: "; read -r PICKED_MODEL; [ -z "$PICKED_MODEL" ] && PICKED_MODEL="$def" ;;
    *) PICKED_MODEL="$CL_SONNET" ;;
  esac
}

echo ""
echo "  How should models be assigned to the team?"
echo "    [1] recommended — task-balanced tiers: a strong model for hard work, a light"
echo "                      model for simple work — best cost ↔ quality  (recommended)"
echo "    [2] single      — ONE model for the whole team (simplest, predictable cost)"
echo "    [3] per-team    — pick a model for each role (BA, Team Lead, Frontend, Backend, QA)"
ask "  Choice [1]: "; read -r MM_CHOICE
case "${MM_CHOICE:-1}" in
  2) MODEL_MODE="single" ;;
  3) MODEL_MODE="per-team" ;;
  *) MODEL_MODE="recommended" ;;
esac
info "Model mode: $MODEL_MODE"

# ── Mode: recommended — named profile per engine family ───────────────────────
if [ "$MODEL_MODE" = "recommended" ]; then
  # Claude profile (Claude always runs orchestration, so this always applies)
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

# ── Mode: single — one model for the whole team ────────────────────────────────
elif [ "$MODEL_MODE" = "single" ]; then
  echo ""
  echo "  One Claude model for the whole team (orchestration + all coding):"
  claude_model_menu
  pick_claude_model "Model" "$CL_SONNET"
  M="$PICKED_MODEL"
  CL_POWER="$M"; CL_STANDARD="$M"; CL_LITE="$M"
  T1_BA="$M"; T1_LEAD="$M"; T1_QA="$M"; T1_FE_DEV="$M"; T1_BE_DEV="$M"
  CODING_PROFILE="single"
  info "Claude: every role → $M"
  [ "$M" = "$CL_OPUS" ] && warn "Opus everywhere is the highest-cost choice — 'recommended' mode gives Opus only to hard tasks."


# ── Mode: per-team — a model per role ──────────────────────────────────────────
else
  echo ""
  echo "  Pick a Claude model per role:"
  echo ""
  claude_model_menu
  pick_claude_model "BA (requirements, dedup)     " "$CL_HAIKU";  T1_BA="$PICKED_MODEL"
  pick_claude_model "Team Lead (plans, review)    " "$CL_SONNET"; T1_LEAD="$PICKED_MODEL"
  pick_claude_model "QA (test design, verdict)    " "$CL_HAIKU";  T1_QA="$PICKED_MODEL"
  pick_claude_model "Frontend developer (Angular) " "$CL_SONNET"; T1_FE_DEV="$PICKED_MODEL"
  pick_claude_model "Backend developer (.NET/SQL) " "$CL_SONNET"; T1_BE_DEV="$PICKED_MODEL"
  CODING_PROFILE="per-team"
  info "Per-team models: BA=$T1_BA · Lead=$T1_LEAD · QA=$T1_QA · FE=$T1_FE_DEV · BE=$T1_BE_DEV"
fi

ACTIVE_PROFILE="$CODING_PROFILE"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5 — TEAM MODELS (derived from the model assignment in STEP 4)
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 5/6 · Team models — review"

# Fine-tune later: /dp-setup models.
info "BA        → $T1_BA"
info "Team Lead → $T1_LEAD"
info "QA        → $T1_QA"
info "Frontend  → $T1_FE_DEV"
info "Backend   → $T1_BE_DEV"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6 — PROJECT IDENTITY
# ═════════════════════════════════════════════════════════════════════════════
section "STEP 6/6 · Project identity & policies"

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

# Jira: collect credentials NOW with a guided walkthrough (skippable) so the
# tracker works on the first task instead of failing mid-implementation.
JIRA_URL_IN=""; JIRA_EMAIL_IN=""; JIRA_TOKEN_IN=""
if [ "$TRACKER_TYPE" = "jira" ]; then
  echo ""
  echo "  Jira connection — 3 quick steps (Enter on the URL skips; set later via"
  echo "  bash scripts/devpilot-config.sh):"
  echo "    1. Create an API token:  https://id.atlassian.com/manage-profile/security/api-tokens"
  echo "    2. Site URL = where you open Jira, e.g. https://your-org.atlassian.net"
  echo "    3. Email   = your Atlassian account email"
  echo ""
  echo "  ℹ Your ticket prefix '$TICKET_PREFIX' must equal the Jira PROJECT KEY"
  echo "    (Jira → Projects → your project → the short key, e.g. APP)."
  echo ""
  ask "  Jira site URL [skip]: "; read -r JIRA_URL_IN
  if [ -n "$JIRA_URL_IN" ]; then
    JIRA_URL_IN="${JIRA_URL_IN%/}"
    case "$JIRA_URL_IN" in http*) : ;; *) JIRA_URL_IN="https://$JIRA_URL_IN" ;; esac
    ask "  Atlassian account email: "; read -r JIRA_EMAIL_IN
    ask "  API token (input hidden): "; read -rs JIRA_TOKEN_IN; echo ""
    [ -n "$JIRA_TOKEN_IN" ] && info "Jira credentials captured — validated live after install" \
                            || warn "No token entered — set it later: bash scripts/devpilot-config.sh set jira_api_token=<token>"
  else
    warn "Jira setup skipped — the tracker falls back to local logs until credentials are set (see docs/setup-guide.md § Jira)"
  fi
fi

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
# REVIEW & CONFIRM — nothing has been written yet
# ═════════════════════════════════════════════════════════════════════════════
section "Review — your configuration"

echo ""
printf "  %-18s %s\n" "Project"        "$PROJECT_NAME  ($DETECTED_TYPE)"
printf "  %-18s %s\n" "Ticket prefix"  "$TICKET_PREFIX"
printf "  %-18s %s\n" "Base branch"    "$BASE_BRANCH"
printf "  %-18s %s\n" "Model mode"     "$MODEL_MODE  (profile: $ACTIVE_PROFILE)"
printf "  %-18s %s\n" "BA / Lead / QA" "$T1_BA · $T1_LEAD · $T1_QA"
printf "  %-18s %s\n" "Frontend / BE"  "$T1_FE_DEV · $T1_BE_DEV"
printf "  %-18s %s\n" "Tracker"        "$TRACKER_TYPE$([ "$TRACKER_TYPE" = jira ] && [ -n "$JIRA_TOKEN_IN" ] && echo ' (credentials captured)')"
printf "  %-18s %s\n" "Merge policy"   "$MERGE_POLICY"
printf "  %-18s %s\n" "Docs language"  "$DOC_LANGUAGE"
AGENT_LIST="BA · Lead · QA"
[ "$AGENT_FRONTEND" = "true" ]    && AGENT_LIST="$AGENT_LIST · Frontend"
[ "$AGENT_BACKEND" = "true" ]     && AGENT_LIST="$AGENT_LIST · Backend"
[ "$AGENT_DB" = "true" ]          && AGENT_LIST="$AGENT_LIST · DB"
[ "$AGENT_INTEGRATION" = "true" ] && AGENT_LIST="$AGENT_LIST · Integration"
printf "  %-18s %s\n" "Team"           "$AGENT_LIST"
echo ""
echo "  Everything above is changeable later — /dp-setup (or edit project.config.md)."
echo ""
ask "  Install with these settings? [Y/n]: "; read -r CONFIRM_INSTALL
if [[ "${CONFIRM_INSTALL:-Y}" =~ ^[Nn] ]]; then
  echo ""
  warn "Cancelled — nothing was written. Re-run: bash install.sh"
  exit 0
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 9 — DOWNLOAD / COPY FILES
# ═════════════════════════════════════════════════════════════════════════════
section "Installing devpilot files..."

# Create directory structure
mkdir -p .devpilot/{prompts/team,templates/team,checklists,skills,config}
mkdir -p .claude/commands .claude/agents
mkdir -p scripts
mkdir -p .github/ISSUE_TEMPLATE
mkdir -p docs/{requirements,plans,qa,reviews,adrs,domain-models,tasks}

# .devpilot — shared rules, prompts, templates, skills
info "Installing .devpilot/..."
fetch ".devpilot/rules.md" ".devpilot/rules.md"
fetch ".devpilot/process.md" ".devpilot/process.md"
fetch "docs/setup-guide.md" "docs/setup-guide.md"
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
JIRA_BASE_URL="${JIRA_URL_IN:-https://YOUR-ORG.atlassian.net}"
JIRA_EMAIL="${JIRA_EMAIL_IN:-your-email@example.com}"
JIRA_API_TOKEN='${JIRA_TOKEN_IN:-YOUR_JIRA_API_TOKEN}'
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

# ── Notifications (best-effort; scripts/notify.sh) ──────────────────────────
NOTIFY_WEBHOOK=""                      # Slack/Teams/Discord-compatible webhook URL
NOTIFY_EMAIL="your-email@example.com"  # used when a local 'mail' command exists
DEVPILOT_CONFIG_UPDATED_AT='$CFG_NOW'
CFGEOF
  info ".devpilot/config.sh created — set your Jira/GitHub credentials with: bash scripts/devpilot-config.sh set jira_api_token=<token>"
fi

# Per-stack rule snippets (router in rules.md tells agents which to read)
mkdir -p .devpilot/rules
for f in angular.md dotnet.md sqlserver.md; do
  fetch ".devpilot/rules/$f" ".devpilot/rules/$f"
done

for f in 6-env-diff.md 6-generate-tests.md; do
  fetch ".devpilot/prompts/$f" ".devpilot/prompts/$f"
done

for f in ba-agent.md lead-plan.md lead-review.md frontend-agent.md dotnet-agent.md qa-agent.md; do
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

for f in core-rules.md definition-of-ready.md estimation-and-slicing.md architecture-guard.md \
         angular-dev.md angular-testing.md accessibility.md \
         dotnet-api.md efcore-sqlserver.md dotnet-testing.md api-contract.md \
         test-case-design.md test-strategy.md ui-e2e-playwright.md token-lean-testing.md test-guard.md performance.md \
         code-review.md security-scan.md definition-of-done.md auto-merge.md release-ops.md self-heal.md \
         README.md; do
  fetch ".devpilot/skills/$f" ".devpilot/skills/$f"
done

fetch ".devpilot/config/models.md" ".devpilot/config/models.md"

# .claude/ — Claude Code commands + agent definitions
info "Installing .claude/..."
for f in dp-deliver.md dp-plan.md dp-sprint.md dp-build.md dp-test.md dp-pr.md \
         dp-release.md dp-hotfix.md dp-status.md dp-setup.md; do
  fetch ".claude/commands/$f" ".claude/commands/$f"
done

for f in team-lead.md team-ba.md team-frontend.md team-dotnet.md team-qa.md; do
  fetch ".claude/agents/$f" ".claude/agents/$f"
done

# SessionStart hook — install only if the user has no settings yet (never clobber).
if [ ! -f ".claude/settings.json" ]; then
  fetch ".claude/settings.json" ".claude/settings.json"
  info ".claude/settings.json created (SessionStart hook → scripts/session-start.sh)"
else
  info ".claude/settings.json exists — to enable the warm-up hook, add a SessionStart entry running: bash scripts/session-start.sh"
fi

# CLAUDE.md — project context for Claude Code
if [ ! -f "CLAUDE.md" ]; then
  fetch "CLAUDE.md" "CLAUDE.md"
  info "CLAUDE.md created"
fi

# scripts/
info "Installing scripts/..."
for f in git-flow.sh new-feature.sh resolve-model.sh model-profiles.sh preflight-scan.sh run-summary.sh checkpoint.sh devpilot-config.sh \
          track.sh open-pr.sh scope.sh scope-guard.sh test-guard.sh run-tests.sh generate-ci.sh protect-branches.sh notify.sh session-start.sh \
          doctor.sh status.sh audit.sh changelog.sh rollback.sh metrics.sh scope-hook.sh install-git-hooks.sh \
          deploy-dev.sh deploy-sit.sh deploy-uat.sh deploy-prd.sh \
          create-jira-ticket.sh create-jira-epic.sh \
          update-jira-status.sh update-jira-description.sh \
          add-jira-comment.sh generate-project-index.sh \
          generate-backlog-index.sh jira-sprint.sh link-jira-issues.sh \
          md-to-adf.sh jira-describe.sh; do
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

for d in requirements plans qa reviews adrs domain-models tasks; do
  touch "docs/$d/.gitkeep"
done

# .gitignore additions
if [ -f ".gitignore" ]; then
  for entry in ".devpilot/config.sh" ".devpilot/.scope-lock" ".env" ".env.local" ".devpilot/logs/" "docs/index/.state" "docs/project-index.md" "docs/index/*.md"; do
    grep -qF "$entry" .gitignore || echo "$entry" >> .gitignore
  done
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 10 — WRITE project.config.md
# ═════════════════════════════════════════════════════════════════════════════
section "Writing project.config.md..."

cat > project.config.md << CONFIGEOF
# Project Configuration
# Generated by devpilot install.sh — edit with /dp-setup wizard

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

## Claude Models — task-balanced (DevPilot runs on Claude only)
# model_mode — recommended (profile tiers) · single (one model) · per-team (edit models.*, then sync-agents)
# Tiers are picked per task by scripts/resolve-model.sh. Change: /dp-setup models <auto|balanced|save>

model_policy:
  coding_profile: $ACTIVE_PROFILE
  model_mode: $MODEL_MODE

coding_models:
  claude:
    power:    "$CL_POWER"
    standard: "$CL_STANDARD"
    lite:     "$CL_LITE"

## Model Routing — Claude team roles (tier1 syncs to .claude/agents frontmatter
## via: bash scripts/model-profiles.sh sync-agents)

models:
  ba:
    tier1: $T1_BA

  team_lead:
    tier1: $T1_LEAD

  qa:
    tier1: $T1_QA

  frontend_dev:
    tier1: $T1_FE_DEV

  backend_dev:
    tier1: $T1_BE_DEV

## Usage limits
# A run that hits a Claude usage limit checkpoints to docs/tasks/<KEY>-checkpoint.json;
# `/dp-deliver resume` continues from the exact phase once the limit resets.
CONFIGEOF

info "project.config.md written"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 12 — SYNC AGENT FRONTMATTER
# ═════════════════════════════════════════════════════════════════════════════
section "Syncing agent models..."

sync_model() {
  local file="$1" model="$2"
  [ -f "$file" ] && sed -i.bak "s/^model: .*/model: $model/" "$file" && rm -f "$file.bak" && info "$(basename $file) → $model"
}

sync_model ".claude/agents/team-lead.md"     "$T1_LEAD"
sync_model ".claude/agents/team-ba.md"       "$T1_BA"
sync_model ".claude/agents/team-qa.md"       "$T1_QA"
sync_model ".claude/agents/team-frontend.md" "$T1_FE_DEV"
sync_model ".claude/agents/team-dotnet.md"   "$T1_BE_DEV"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 13 — GIT BRANCH SETUP
# ═════════════════════════════════════════════════════════════════════════════
section "Git branch setup..."

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
# STEP 13b — CI WORKFLOW + BRANCH PROTECTION (the gate ladder, server-side)
# ═════════════════════════════════════════════════════════════════════════════
section "CI workflow & branch protection..."

CI_GENERATED=0
if [ -f ".github/workflows/devpilot-ci.yml" ]; then
  info "CI workflow exists — refresh anytime: bash scripts/generate-ci.sh --force"
  CI_GENERATED=1
else
  echo ""
  echo "  A GitHub Actions workflow enforces the gate ladder on every PR:"
  echo "  build → tests → test-guard (strict) → dependency audit."
  ask "  Generate .github/workflows/devpilot-ci.yml? [Y/n]: "; read -r CI_CHOICE
  if [[ ! "${CI_CHOICE:-Y}" =~ ^[Nn] ]]; then
    bash scripts/generate-ci.sh && CI_GENERATED=1
  else
    info "Skipped — generate later: bash scripts/generate-ci.sh"
  fi
fi

if [ "$CI_GENERATED" = 1 ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo ""
  echo "  Branch protection makes the check non-bypassable (no force-push, devpilot-ci"
  echo "  required$([ "$MERGE_POLICY" = "pr-only" ] && echo ', 1 review required'))."
  ask "  Protect '$BASE_BRANCH'$([ "$BASE_BRANCH" != main ] && echo " and 'main'")? [Y/n]: "; read -r BP_CHOICE
  if [[ ! "${BP_CHOICE:-Y}" =~ ^[Nn] ]]; then
    bash scripts/protect-branches.sh || true
  else
    info "Skipped — protect later: bash scripts/protect-branches.sh"
  fi
else
  [ "$CI_GENERATED" = 1 ] && info "Branch protection needs gh authenticated — later: gh auth login && bash scripts/protect-branches.sh"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 14 — JIRA VALIDATION (live, only when credentials were captured)
# ═════════════════════════════════════════════════════════════════════════════
if [ "$TRACKER_TYPE" = "jira" ] && [ -n "$JIRA_TOKEN_IN" ]; then
  section "Validating Jira connection..."
  # Re-installs keep an existing config.sh — push the captured values into it
  # so validation tests what was just entered, not stale credentials.
  bash scripts/devpilot-config.sh set "jira_base_url=$JIRA_URL_IN"   >/dev/null 2>&1 || true
  bash scripts/devpilot-config.sh set "jira_email=$JIRA_EMAIL_IN"    >/dev/null 2>&1 || true
  bash scripts/devpilot-config.sh set "jira_api_token=$JIRA_TOKEN_IN" >/dev/null 2>&1 || true
  if bash scripts/devpilot-config.sh validate; then
    info "Jira connection OK — tickets will be created in project '$TICKET_PREFIX'"
  else
    warn "Jira validation FAILED — fix and re-test with:"
    warn "  bash scripts/devpilot-config.sh set jira_api_token=<token>"
    warn "  bash scripts/devpilot-config.sh validate"
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
echo "  Models:         Claude · $MODEL_MODE ($ACTIVE_PROFILE)"
echo ""
echo "  Installed:"
echo "    .claude/commands/    — slash commands for Claude Code"
echo "    .claude/agents/      — agent definitions"
echo "    CLAUDE.md            — project context (Claude Code)"
echo "    .devpilot/           — rules, templates, skills"
echo "    scripts/             — git-flow, Jira, deploy helpers"
echo "    project.config.md    — team + Claude model config"
echo ""
echo "  ── Next steps ──────────────────────────────────────────"
echo ""
STEP_N=1
if [ "$TRACKER_TYPE" = "jira" ]; then
echo "  $STEP_N. Set Jira credentials (required for tracker: jira):"
echo "     bash scripts/devpilot-config.sh set jira_base_url=https://your-org.atlassian.net"
echo "     bash scripts/devpilot-config.sh set jira_api_token=<token>   # validates live"
echo ""
STEP_N=$((STEP_N + 1))
elif [ "$TRACKER_TYPE" = "github" ]; then
echo "  $STEP_N. Authenticate the GitHub CLI (required for tracker: github):"
echo "     gh auth login"
echo ""
STEP_N=$((STEP_N + 1))
fi
echo "  $STEP_N. Verify the install:    /dp-status health    (or: bash scripts/doctor.sh)"
STEP_N=$((STEP_N + 1))
echo "  $STEP_N. Commit the setup:      git add -A && git commit -m \"chore: install devpilot\""
STEP_N=$((STEP_N + 1))
echo "  $STEP_N. Optional (deploys):    edit .devpilot/config.sh → DEV/SIT/UAT/PRD URLs + GitHub secrets"
STEP_N=$((STEP_N + 1))
echo "  $STEP_N. Optional (alerts):     set NOTIFY_WEBHOOK in .devpilot/config.sh → pinged on sprint DONE / QA BLOCKED"
echo ""
echo "  Full walkthrough + recommendations: docs/setup-guide.md"
echo ""
echo "  ── Start working ───────────────────────────────────────"
echo ""

echo "  In Claude Code (CLI, desktop, IDE, or claude.ai/code):"
echo "    /dp-deliver \"your feature or bug\"        — requirement → merged into $BASE_BRANCH"
echo "    /dp-deliver \"…\" --to sit                 — …and cut the SIT release"
echo "    /dp-plan → /dp-sprint → /dp-build → /dp-pr   — the same flow, one role at a time"
echo ""

echo "  ── Change config anytime ───────────────────────────────"
echo ""
echo "    /dp-setup fix          — doctor finds missing/invalid config, fixes interactively"
echo "    /dp-setup wizard       — re-run the configuration wizard"
echo "    /dp-setup models       — switch Claude model profile (auto | balanced | save)"
echo "    Edit project.config.md directly"
echo ""

# Surface any skipped files last, so an incomplete install can't slip by unnoticed.
fetch_summary || true
