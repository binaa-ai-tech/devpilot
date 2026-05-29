#!/usr/bin/env bash
# =============================================================================
# run-summary.sh — generate a concise execution summary for one devpilot run
# and (optionally) append it to the active tracker ticket.
#
# Usage:
#   run-summary.sh <KEY> <slug> "<root-cause>" "<tests-result>" [base-branch] [--post]
#
# Behavior:
#   • Collects commits + changed files since <base-branch> (default: base_branch
#     from project.config.md, else develop).
#   • Writes docs/summaries/<slug>.md and echoes the path on stdout.
#   • With --post, appends a condensed version to the ticket via track.sh
#     (works for local | github | jira — no Jira coupling here).
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

KEY="${1:-}"; SLUG="${2:-}"; ROOT_CAUSE="${3:-}"; TESTS="${4:-}"
BASE="${5:-}"
POST=0
for a in "$@"; do [ "$a" = "--post" ] && POST=1; done
# --post may have been passed in the base slot; normalize.
[ "$BASE" = "--post" ] && BASE=""

if [ -z "$KEY" ] || [ -z "$SLUG" ]; then
  echo "Usage: run-summary.sh <KEY> <slug> \"<root-cause>\" \"<tests>\" [base-branch] [--post]" >&2
  exit 1
fi

if [ -z "$BASE" ]; then
  BASE=$(grep -E '^base_branch:' project.config.md 2>/dev/null | head -1 \
    | sed 's/base_branch:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')
  [ -z "$BASE" ] && BASE="develop"
fi

BRANCH=$(git branch --show-current 2>/dev/null || echo "?")
RANGE="${BASE}..HEAD"

COMMITS=$(git log "$RANGE" --oneline 2>/dev/null || echo "")
COMMIT_HASHES=$(printf '%s\n' "$COMMITS" | awk 'NF{print $1}' | tr '\n' ' ' | sed 's/ $//')
FILES=$(git diff --name-status "$RANGE" 2>/dev/null || echo "")
STAT=$(git diff --stat "$RANGE" 2>/dev/null | tail -1)

OUT_DIR="docs/summaries"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/${SLUG}.md"

{
  echo "# Run summary — ${KEY} (${SLUG})"
  echo ""
  echo "- Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- Branch: \`${BRANCH}\` → \`${BASE}\`"
  echo ""
  echo "## Root cause / rationale"
  echo "${ROOT_CAUSE:-_(not provided)_}"
  echo ""
  echo "## What changed"
  if [ -n "$FILES" ]; then
    echo '```'
    printf '%s\n' "$FILES"
    echo '```'
    [ -n "$STAT" ] && echo "_${STAT}_"
  else
    echo "_No file changes detected against ${BASE}._"
  fi
  echo ""
  echo "## Commits"
  if [ -n "$COMMITS" ]; then
    echo '```'
    printf '%s\n' "$COMMITS"
    echo '```'
  else
    echo "_None since ${BASE}._"
  fi
  echo ""
  echo "## Test results"
  echo "${TESTS:-_(not provided)_}"
  echo ""
  echo "## Engines / models used"
  if [ -n "${DEVPILOT_ENGINES:-}" ]; then
    # newline- or semicolon-separated "layer: engine (model)" entries
    printf '%s\n' "${DEVPILOT_ENGINES}" | tr ';' '\n' | sed 's/^[[:space:]]*/- /'
  else
    echo "- $(bash "$ROOT/scripts/resolve-engine.sh" effective 2>/dev/null | tr '\n' ' ')"
  fi
} > "$OUT"

# Optionally post a condensed version to the tracker.
if [ "$POST" = "1" ]; then
  CHANGED_COUNT=$(printf '%s\n' "$FILES" | awk 'NF' | wc -l | tr -d ' ')
  COMMENT="📝 Run summary — ${SLUG}
Root cause: ${ROOT_CAUSE:-n/a}
Changed: ${CHANGED_COUNT} file(s)${STAT:+ ($STAT)}
Commits: ${COMMIT_HASHES:-none}
Engines: ${DEVPILOT_ENGINES:-$(bash "$ROOT/scripts/resolve-engine.sh" effective 2>/dev/null | tr '\n' ' ')}
Tests: ${TESTS:-n/a}
Detail: ${OUT}"
  bash "$ROOT/scripts/track.sh" comment "$KEY" "$COMMENT" >/dev/null 2>&1 \
    && echo "📌 summary posted to $KEY" >&2 \
    || echo "⚠️  could not post summary to $KEY (tracker unavailable)" >&2
fi

echo "$OUT"
