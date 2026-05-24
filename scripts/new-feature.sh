#!/usr/bin/env bash
# =============================================================================
# new-feature.sh — Create a feature/fix branch from develop
#
# Usage: ./scripts/new-feature.sh <TICKET-KEY> <short-slug>
# Example: ./scripts/new-feature.sh MSK-101 otp-retry-limit
#
# Prefer using git-flow.sh instead:
#   bash scripts/git-flow.sh feature-start 101 otp-retry-limit
# =============================================================================
set -euo pipefail

source "$(dirname "$0")/../.aidev/config.sh"

KEY="${1:-}"
SLUG="${2:-}"

if [ -z "$KEY" ] || [ -z "$SLUG" ]; then
  echo "Usage: $0 <TICKET-KEY> <short-slug>"
  echo "Example: $0 MSK-101 otp-retry-limit"
  exit 1
fi

BRANCH="feature/${TICKET_PREFIX:-mas}-${KEY}-${SLUG}"

git checkout "${DEVELOP_BRANCH:-develop}"
git pull origin "${DEVELOP_BRANCH:-develop}"
git checkout -b "$BRANCH"

# Scaffold impact map
IMPACT_MAP=".aidev/impact-maps/${KEY}.md"
cp .aidev/templates/impact-map.md "$IMPACT_MAP"
sed -i.bak "s/TICKET_KEY/$KEY/g" "$IMPACT_MAP" && rm "${IMPACT_MAP}.bak"

echo "Branch '$BRANCH' created from ${DEVELOP_BRANCH:-develop}."
echo "Impact map scaffolded at $IMPACT_MAP"
echo ""
echo "Next: fill in $IMPACT_MAP then run opencode to implement."
