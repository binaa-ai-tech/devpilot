#!/usr/bin/env bash
# =============================================================================
# open-pr.sh — open (and, per merge_policy, squash-merge) a PR on GitHub or Azure Repos.
#
#   open-pr.sh <base-branch> <title> <body-file|text> [--no-merge] [--items "KEY1 KEY2"]
#
# --items links the tracker items (Azure: work item links on the PR).
# Prints the PR URL (or a compare URL) on stdout.
# Exit: 0 created + merged · 3 open, not merged yet (pr-only, waiting on policies/checks,
#       or no gh → finish with the GitHub MCP tools) · 1 error
# =============================================================================
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

BASE="${1:-}"; TITLE="${2:-}"; BODY_SRC="${3:-}"
if [ -z "$BASE" ] || [ -z "$TITLE" ]; then
  echo "Usage: open-pr.sh <base> <title> <body-file|text> [--no-merge] [--items \"KEY1 KEY2\"]" >&2
  exit 1
fi
shift 3 || shift $#
MERGE=1; ITEMS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-merge) MERGE=0; shift ;;
    --items)    ITEMS="${2:-}"; shift 2 ;;
    *)          shift ;;
  esac
done

# shellcheck source=devpilot-lib.sh
. "$DIR/devpilot-lib.sh"
[ "$(dp_cfg merge_policy)" = "pr-only" ] && MERGE=0

BRANCH=$(git branch --show-current)
git push -u origin "$BRANCH" >/dev/null 2>&1 || echo "⚠️  push of $BRANCH failed — PR may not open" >&2

case "$(bash "$DIR/git-host.sh")" in
  azure)
    PR_URL=$(bash "$DIR/azdo.sh" pr-create "$BASE" "$TITLE" "$BODY_SRC" --items "$ITEMS") || exit 1
    echo "$PR_URL"
    [ "$MERGE" = 1 ] || exit 3
    bash "$DIR/azdo.sh" pr-complete "${PR_URL##*/}" >&2
    exit $?   # 0 merged · 3 auto-complete armed · 1 conflicts/error
    ;;
  github)
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      if [ -f "$BODY_SRC" ]; then BODY=$(cat "$BODY_SRC"); else BODY="${BODY_SRC:-_(opened by DevPilot)_}"; fi
      PR_URL=$(gh pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body "$BODY" 2>/dev/null | tail -1)
      [ -z "$PR_URL" ] && PR_URL=$(gh pr view --json url -q .url 2>/dev/null)
      [ -z "$PR_URL" ] && { echo "ERROR: could not create PR for $BRANCH → $BASE" >&2; exit 1; }
      echo "$PR_URL"
      [ "$MERGE" = 1 ] || exit 3
      gh pr merge "${PR_URL##*/}" --squash --delete-branch >/dev/null 2>&1 && exit 0
      # Required checks still running → arm auto-merge instead of failing.
      gh pr merge "${PR_URL##*/}" --squash --delete-branch --auto >/dev/null 2>&1 \
        && echo "ℹ️  auto-merge armed — merges when required checks pass" >&2
      exit 3
    fi
    REPO_PATH=$(dp_remote_url | sed -E 's#.*github\.com[:/]##; s/\.git$//')
    echo "https://github.com/${REPO_PATH}/compare/${BASE}...${BRANCH}?expand=1"
    echo "ℹ️  gh not available — create/merge the PR with the GitHub MCP tools (title: $TITLE)." >&2
    exit 3
    ;;
  *)
    echo "ℹ️  unknown git host — open a PR $BRANCH → $BASE by hand (set git_host in project.config.md)." >&2
    exit 3
    ;;
esac
