#!/usr/bin/env bash
# =============================================================================
# preflight-scan.sh — context enrichment before work starts.
#
# Incoming tickets are often thin. This scan reads the local repo state
# (recent commits, working-tree diff, changed-file tree, optional app logs)
# and emits a Markdown brief the orchestrator can use to infer missing
# technical detail. It does NOT call any LLM — it just gathers signal.
#
# Usage:
#   bash scripts/preflight-scan.sh "<task or ticket text>" [slug]
#
# Writes docs/preflight/<slug>.md and echoes the path on stdout.
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

TASK="${1:-}"
SLUG="${2:-}"
if [ -z "$SLUG" ]; then
  SLUG=$(printf '%s' "${TASK:-preflight}" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' | cut -c1-40)
  [ -z "$SLUG" ] && SLUG="preflight"
fi

BASE=$(grep -E '^base_branch:' project.config.md 2>/dev/null | head -1 \
  | sed 's/base_branch:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')
[ -z "$BASE" ] && BASE="develop"

OUT_DIR="docs/preflight"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/${SLUG}.md"

# Keyword hints pulled from the task text — helps localize relevant files.
HINTS=$(printf '%s' "$TASK" | tr ' ' '\n' \
  | grep -oE '[A-Za-z][A-Za-z0-9_]{3,}' | sort -u | head -8 | tr '\n' '|' | sed 's/|$//')

{
  echo "# Pre-flight scan — ${SLUG}"
  echo ""
  echo "> Generated $(date '+%Y-%m-%d %H:%M:%S') · base branch: \`${BASE}\`"
  echo ""
  echo "## Task as given"
  echo "${TASK:-_(none provided)_}"
  echo ""

  echo "## Recent history (last 10 commits)"
  echo '```'
  git log --oneline -10 2>/dev/null || echo "(no git history)"
  echo '```'
  echo ""

  echo "## Uncommitted working-tree changes"
  if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    echo "_Clean working tree._"
  else
    echo '```'
    git status --short 2>/dev/null
    echo '```'
    echo ""
    echo "<details><summary>diff stat</summary>"
    echo ""
    echo '```'
    git diff --stat HEAD 2>/dev/null | tail -40
    echo '```'
    echo ""
    echo "</details>"
  fi
  echo ""

  echo "## Files likely in scope"
  if [ -n "$HINTS" ]; then
    echo "Matched against task keywords: \`${HINTS}\`"
    echo '```'
    git ls-files 2>/dev/null | grep -iE "$HINTS" | head -25 || echo "(no path matches — broaden manually)"
    echo '```'
  else
    echo "_No usable keywords in the task text._"
  fi
  echo ""

  echo "## Recently changed areas (last 20 commits, by directory)"
  echo '```'
  git log --name-only --pretty=format: -20 2>/dev/null \
    | grep -v '^$' | sed 's#/[^/]*$##' | sort | uniq -c | sort -rn | head -12 \
    || echo "(unavailable)"
  echo '```'
  echo ""

  echo "## Inferred gaps to confirm before coding"
  echo "- [ ] Which layer(s) does this touch (FE / BE / DB / integration)?"
  echo "- [ ] Acceptance criteria not stated in the ticket"
  echo "- [ ] Any migration or data backfill implied?"
  echo "- [ ] Reproduction steps (for bugs) — confirmed locally?"
} > "$OUT"

echo "$OUT"
