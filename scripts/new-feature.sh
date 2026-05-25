#!/usr/bin/env bash
# Stage 3 — Branch + scaffold
# Usage: ./scripts/new-feature.sh KEY-101 "short description of work"
set -euo pipefail

TICKET=${1:?"Usage: $0 <TICKET-KEY> \"<short description>\""}
DESC=${2:?"Usage: $0 <TICKET-KEY> \"<short description>\""}

# Normalise description → kebab-case slug
SLUG=$(echo "$DESC" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/-/g' \
  | sed 's/--*/-/g' \
  | sed 's/^-//;s/-$//')

BRANCH="feature/${TICKET}-${SLUG}"

echo "→ Syncing main..."
git checkout main
git pull origin main

echo "→ Creating branch: $BRANCH"
git checkout -b "$BRANCH"
git push -u origin "$BRANCH"

echo ""
echo "→ Creating impact map scaffold..."
IMPACT_MAP=".aidev/impact-maps/${TICKET}.md"
if [ ! -f "$IMPACT_MAP" ]; then
  cp .aidev/templates/impact-map.md "$IMPACT_MAP"
  sed -i.bak "s/<TICKET-KEY>/$TICKET/g" "$IMPACT_MAP" && rm -f "${IMPACT_MAP}.bak"
  git add "$IMPACT_MAP"
  git commit -m "chore($TICKET): scaffold impact map"
  git push
  echo "→ Impact map created: $IMPACT_MAP"
else
  echo "→ Impact map already exists: $IMPACT_MAP"
fi

echo ""
echo "✅ Ready."
echo "   Branch : $BRANCH"
echo "   Next   : Run prompt 2-investigate with ticket $TICKET, then fill in $IMPACT_MAP"
echo "            Get your plan approved, then run prompt 4-implement-feature."
