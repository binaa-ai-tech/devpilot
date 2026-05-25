#!/usr/bin/env bash
# =============================================================================
# binaa-ai Dev Process — Installer
#
# Run from the root of any project:
#   curl -s https://raw.githubusercontent.com/binaa-ai-tech/dev-process/main/install.sh | bash
# =============================================================================
set -euo pipefail

REPO="https://raw.githubusercontent.com/binaa-ai-tech/dev-process/main"
PROJECT_ROOT=$(pwd)

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

info()  { echo -e "${GREEN}[install]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[install]${RESET} $*"; }

echo ""
echo "Installing binaa-ai dev process into: $PROJECT_ROOT"
echo ""

# ── Create directories ────────────────────────────────────────────────────────
mkdir -p .aidev/{prompts,templates,checklists,impact-maps}
mkdir -p scripts
mkdir -p .github/workflows
mkdir -p .github
mkdir -p .claude/commands

# ── .aidev core files ─────────────────────────────────────────────────────────
info "Downloading .aidev files..."
for f in README.md rules.md config.sh; do
  curl -fsSL "$REPO/.aidev/$f" -o ".aidev/$f"
done

for f in 0-start-work.md 1-triage.md 2-investigate.md \
          4-copilot-implement.md 4-implement-feature.md \
          4-implement-bugfix.md 4-implement-refactor.md \
          5-self-review.md 6-env-diff.md 6-generate-tests.md \
          7-pr-description.md; do
  curl -fsSL "$REPO/.aidev/prompts/$f" -o ".aidev/prompts/$f"
done

for f in impact-map.md pr-description.md ticket.md changelog-entry.md; do
  curl -fsSL "$REPO/.aidev/templates/$f" -o ".aidev/templates/$f"
done

for f in feature.md bugfix.md hotfix.md; do
  curl -fsSL "$REPO/.aidev/checklists/$f" -o ".aidev/checklists/$f"
done

touch .aidev/impact-maps/.gitkeep

# ── Scripts ───────────────────────────────────────────────────────────────────
info "Downloading scripts..."
for f in git-flow.sh new-feature.sh \
          deploy-dev.sh deploy-sit.sh deploy-uat.sh deploy-prd.sh \
          create-jira-ticket.sh update-jira-status.sh; do
  curl -fsSL "$REPO/scripts/$f" -o "scripts/$f" 2>/dev/null || \
    warn "scripts/$f not found in repo — skipping"
  chmod +x "scripts/$f" 2>/dev/null || true
done

# ── GitHub Actions CI/CD workflows ───────────────────────────────────────────
info "Downloading CI/CD workflows..."
curl -fsSL "$REPO/.github/workflows/ci.yml" -o ".github/workflows/ci.yml"
curl -fsSL "$REPO/.github/workflows/deploy-prd.yml" -o ".github/workflows/deploy-prd.yml"

# ── GitHub docs ───────────────────────────────────────────────────────────────
info "Downloading GitHub docs..."
for f in BRANCH_NAMING.md COMMIT_CONVENTION.md pull_request_template.md; do
  curl -fsSL "$REPO/.github/$f" -o ".github/$f" 2>/dev/null || \
    warn ".github/$f not found — skipping"
done

# ── Commitlint config ─────────────────────────────────────────────────────────
if [ ! -f ".commitlintrc.json" ]; then
  curl -fsSL "$REPO/.commitlintrc.json" -o ".commitlintrc.json"
  info "Downloaded .commitlintrc.json"
else
  warn ".commitlintrc.json already exists — skipping (keep your project scopes)"
fi

# ── Claude Code commands ──────────────────────────────────────────────────────
info "Downloading Claude Code commands..."
for f in binaa.md binaa-dev.md binaa-sit.md binaa-uat.md binaa-prd.md binaa-hotfix.md \
          team-task.md team-ba.md team-lead.md team-frontend.md team-dotnet.md team-qa.md; do
  curl -fsSL "$REPO/.claude/commands/$f" -o ".claude/commands/$f"
done

# ── AI team agent prompts ─────────────────────────────────────────────────────
info "Downloading AI team prompts..."
mkdir -p .aidev/prompts/team .aidev/templates/team .aidev/skills
for f in ba-agent.md lead-plan.md lead-review.md frontend-agent.md dotnet-agent.md qa-agent.md; do
  curl -fsSL "$REPO/.aidev/prompts/team/$f" -o ".aidev/prompts/team/$f"
done
for f in requirements.md implementation-plan.md qa-report.md review-report.md adr.md domain-model.md; do
  curl -fsSL "$REPO/.aidev/templates/team/$f" -o ".aidev/templates/team/$f"
done

# ── AI team power skills ──────────────────────────────────────────────────────
info "Downloading AI team skills..."
for f in get-shit-done.md security-scan.md performance-review.md architecture-guard.md self-heal.md definition-of-done.md; do
  curl -fsSL "$REPO/.aidev/skills/$f" -o ".aidev/skills/$f"
done

# ── Docs structure for task outputs ──────────────────────────────────────────
info "Creating docs structure..."
mkdir -p docs/{requirements,plans,qa,reviews,team,adrs,domain-models}
for d in requirements plans qa reviews adrs domain-models; do
  touch "docs/$d/.gitkeep"
done
curl -fsSL "$REPO/docs/team/README.md" -o "docs/team/README.md"

# ── CLAUDE.md ─────────────────────────────────────────────────────────────────
if [ ! -f "CLAUDE.md" ]; then
  curl -fsSL "$REPO/CLAUDE.md" -o "CLAUDE.md"
  info "Downloaded CLAUDE.md"
else
  info "CLAUDE.md already exists — skipping (keep your project-specific content)"
fi

# ── .gitignore additions ──────────────────────────────────────────────────────
GITIGNORE_ENTRIES=(
  ".aidev/config.sh"
  ".env.local"
  ".env.*.local"
)
if [ -f ".gitignore" ]; then
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qF "$entry" .gitignore; then
      echo "$entry" >> .gitignore
      info "Added $entry to .gitignore"
    fi
  done
fi

# ── Git: create develop branch ───────────────────────────────────────────────
if git rev-parse --git-dir > /dev/null 2>&1; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

  if ! git show-ref --verify --quiet refs/heads/develop; then
    info "Creating develop branch from ${CURRENT_BRANCH}..."
    git checkout -b develop
    git push -u origin develop 2>/dev/null || \
      warn "Could not push develop to origin — push manually: git push -u origin develop"
    git checkout "${CURRENT_BRANCH}"
  else
    info "develop branch already exists ✅"
  fi
else
  warn "Not a git repo — skipping branch setup"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅  binaa-ai dev process installed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " Next steps:"
echo ""
echo "  1. Edit .aidev/config.sh"
echo "     → Fill in Jira URL, email, token, project key"
echo "     → Set GITHUB_ORG, GITHUB_REPO, TICKET_PREFIX"
echo "     → Set DEV/SIT/UAT/PRD URLs"
echo ""
echo "  2. Add GitHub Secrets (Settings → Secrets → Actions):"
echo "     DEPLOY_HOOK_DEV, DEPLOY_HOOK_SIT, DEPLOY_HOOK_UAT, DEPLOY_HOOK_PRD"
echo ""
echo "  3. Add GitHub Variables (Settings → Secrets → Variables):"
echo "     DEV_URL, SIT_URL, UAT_URL, PRD_URL"
echo ""
echo "  4. Create GitHub Environments: dev, sit, uat, prd"
echo "     Add Required Reviewers to uat + prd (needs GitHub Team plan)"
echo ""
echo "  5. Start working:"
echo "     /team-task feat: your feature description   ← full AI team workflow"
echo "     /binaa-dev feat: your feature description   ← classic single-agent workflow"
echo ""
echo " Docs: .aidev/README.md | docs/team/README.md"
echo ""
