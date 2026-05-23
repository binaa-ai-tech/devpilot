#!/bin/bash
# =============================================================================
# binaa-ai Dev Process — Installer
# Run from the root of any project:
#   curl -s https://raw.githubusercontent.com/binaa-ai/dev-process/main/install.sh | bash
# =============================================================================
set -e

REPO="https://raw.githubusercontent.com/binaa-ai/dev-process/main"
PROJECT_ROOT=$(pwd)

echo "Installing binaa-ai dev process into: $PROJECT_ROOT"
echo ""

# Create directories
mkdir -p .aidev/{prompts,templates,checklists,impact-maps}
mkdir -p scripts
mkdir -p .github/workflows
mkdir -p docs

# Download .aidev files
echo "Downloading .aidev files..."
for f in rules.md config.sh; do
  curl -fsSL "$REPO/.aidev/$f" -o ".aidev/$f"
done

for f in 0-start-work.md 4-copilot-implement.md 4-implement-feature.md \
          4-implement-bugfix.md 4-implement-refactor.md 5-self-review.md \
          6-env-diff.md 6-generate-tests.md 7-pr-description.md; do
  curl -fsSL "$REPO/.aidev/prompts/$f" -o ".aidev/prompts/$f"
done

for f in impact-map.md pr-description.md ticket.md changelog-entry.md; do
  curl -fsSL "$REPO/.aidev/templates/$f" -o ".aidev/templates/$f"
done

for f in feature.md bugfix.md hotfix.md; do
  curl -fsSL "$REPO/.aidev/checklists/$f" -o ".aidev/checklists/$f"
done

touch .aidev/impact-maps/.gitkeep

# Download scripts
echo "Downloading scripts..."
for f in new-feature.sh deploy-sit.sh create-jira-ticket.sh; do
  curl -fsSL "$REPO/scripts/$f" -o "scripts/$f"
  chmod +x "scripts/$f"
done

# Download workflow
echo "Downloading GitHub Actions workflow..."
curl -fsSL "$REPO/.github/workflows/sit-deploy.yml" \
  -o ".github/workflows/sit-deploy.yml"

# Download docs
curl -fsSL "$REPO/docs/dev-flow.md" -o "docs/dev-flow.md"

# Add .aidev/config.sh to .gitignore if not already there
if [ -f ".gitignore" ]; then
  if ! grep -q ".aidev/config.sh" .gitignore; then
    echo ".aidev/config.sh" >> .gitignore
    echo "Added .aidev/config.sh to .gitignore"
  fi
fi

echo ""
echo "Done! Next steps:"
echo ""
echo "  1. Edit .aidev/config.sh — fill in your Jira URL, email, token, project key"
echo "  2. Add GitHub secrets: API_DEPLOY_HOOK_URL, WEB_DEPLOY_HOOK_URL (under SIT environment)"
echo "  3. Create a 'sit' branch: git checkout -b sit && git push origin sit"
echo "  4. Start working: tell Claude your task"
echo ""
echo "Docs: docs/dev-flow.md"
