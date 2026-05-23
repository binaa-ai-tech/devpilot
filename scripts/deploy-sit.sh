#!/bin/bash
set -e

source "$(dirname "$0")/../.aidev/config.sh"

echo "Deploying $MAIN_BRANCH → $SIT_BRANCH..."

git checkout "$SIT_BRANCH"
git merge "$MAIN_BRANCH" --no-edit
git push origin "$SIT_BRANCH"
git checkout "$MAIN_BRANCH"

echo ""
echo "Done. GitHub Actions is building and deploying."
echo "Watch:  https://github.com/$GITHUB_ORG/$GITHUB_REPO/actions"
echo "Test:   $SIT_FRONTEND_URL"
