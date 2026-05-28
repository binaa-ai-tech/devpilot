#!/usr/bin/env bash
# =============================================================================
# open-pr.sh — create (and optionally squash-merge) a pull request, tool-agnostic.
#
# Usage:
#   open-pr.sh <base-branch> <title> <body-file-or-text> [--no-merge]
#
# Prints the PR (or compare) URL on stdout.
# Exit codes:
#   0  — PR created and squash-merged
#   3  — PR created/opened but NOT merged (merge skipped, failed, or no gh CLI)
#   1  — error (bad args / could not create)
#
# Uses the `gh` CLI when available + authenticated; otherwise pushes the branch
# and prints a compare URL so the PR can be opened manually or via GitHub MCP.
# =============================================================================
set -uo pipefail

BASE="${1:-}"; TITLE="${2:-}"; BODY_SRC="${3:-}"; MERGE="${4:---merge}"
if [ -z "$BASE" ] || [ -z "$TITLE" ]; then
  echo "Usage: open-pr.sh <base> <title> <body-file|text> [--no-merge]" >&2
  exit 1
fi

if [ -f "$BODY_SRC" ]; then BODY=$(cat "$BODY_SRC"); else BODY="${BODY_SRC:-_(opened by devpilot)_}"; fi
BRANCH=$(git branch --show-current)

# Honor merge_policy from project.config.md: pr-only never auto-merges.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
POLICY=$(grep -E '^[[:space:]]*merge_policy:' "$ROOT/project.config.md" 2>/dev/null | head -1 \
  | sed 's/.*merge_policy:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
[ "$POLICY" = "pr-only" ] && MERGE="--no-merge"

push_branch() { git push -u origin "$BRANCH" >/dev/null 2>&1 || true; }

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  push_branch
  PR_URL=$(gh pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body "$BODY" 2>/dev/null | tail -1)
  [ -z "$PR_URL" ] && PR_URL=$(gh pr view --json url -q .url 2>/dev/null)
  if [ -z "$PR_URL" ]; then echo "ERROR: could not create PR for $BRANCH → $BASE" >&2; exit 1; fi
  echo "$PR_URL"
  if [ "$MERGE" != "--no-merge" ]; then
    PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')
    if gh pr merge "$PR_NUM" --squash --delete-branch >/dev/null 2>&1; then
      exit 0
    fi
    echo "WARN: auto-merge failed — merge manually: $PR_URL" >&2
    exit 3
  fi
  exit 3
fi

# No usable gh CLI — push and emit a compare URL for manual / MCP completion.
push_branch
REPO_PATH=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]##; s/\.git$//')
echo "https://github.com/${REPO_PATH}/compare/${BASE}...${BRANCH}?expand=1"
echo "ℹ️  gh CLI not available — open the PR via the URL above or the GitHub MCP tools." >&2
echo "   Title: $TITLE" >&2
exit 3
