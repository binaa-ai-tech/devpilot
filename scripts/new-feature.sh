#!/bin/bash
# Usage: ./scripts/new-feature.sh MSK-101 short-description
set -e

source "$(dirname "$0")/../.aidev/config.sh"

KEY="$1"
SLUG="$2"

if [ -z "$KEY" ] || [ -z "$SLUG" ]; then
  echo "Usage: $0 <TICKET-KEY> <short-slug>"
  echo "Example: $0 MSK-101 otp-retry-limit"
  exit 1
fi

BRANCH="feat/${KEY}-${SLUG}"

git checkout "$MAIN_BRANCH"
git pull origin "$MAIN_BRANCH"
git checkout -b "$BRANCH"

# Scaffold impact map
IMPACT_MAP=".aidev/impact-maps/${KEY}.md"
cp .aidev/templates/impact-map.md "$IMPACT_MAP"
sed -i.bak "s/TICKET_KEY/$KEY/g" "$IMPACT_MAP" && rm "${IMPACT_MAP}.bak"

echo "Branch '$BRANCH' created."
echo "Impact map scaffolded at $IMPACT_MAP"
echo ""
echo "Next: fill in $IMPACT_MAP then run opencode to implement."
