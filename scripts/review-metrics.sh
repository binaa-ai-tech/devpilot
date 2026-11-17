#!/usr/bin/env bash
# =============================================================================
# review-metrics.sh — review the reviewers: what slipped past review after a merge?
#
#   review-metrics.sh [since] [--days N] [--base <branch>]
#     since    git date (default "90 days ago")   e.g. 2026-09-01, "6 weeks ago"
#     --days   window after a merge in which a fix counts as a slip (default 14)
#     --base   branch the PRs merged into (default base_branch from project.config.md)
#
# Reads git history only, so it works on any host. A merged PR is a first-parent commit of
# <base> whose subject carries the PR number ("… (#38)", "Merge pull request #38",
# "Merged PR 38: …"). Two kinds of slip:
#   reverted   a later revert commit undoes it ("This reverts commit <sha>")
#   fixed      a later fix(…) commit within --days touches files the PR changed
# For each slip it says whether the PR's review report (docs/reviews/*.md as merged with that
# PR) mentioned the slipped file — flagged, not flagged, or no review report.
# A miss feeds the process in .devpilot/process.md → "Review the reviewers".
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

SINCE="90 days ago"; DAYS=14; BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --base) BASE="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    -h|--help) sed -n '5,9p' "$0" | sed 's/^# \{0,3\}//'; exit 0 ;;
    -*) echo "❌ unknown option: $1" >&2; exit 2 ;;
    *) SINCE="$1"; shift ;;
  esac
done
case "$DAYS" in ''|*[!0-9]*) echo "❌ --days needs a number" >&2; exit 2 ;; esac
if [ -z "$BASE" ]; then
  BASE=$(grep '^base_branch:' project.config.md 2>/dev/null | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  BASE="${BASE:-develop}"
fi
REF="$BASE"
git rev-parse --verify --quiet "origin/$BASE" >/dev/null 2>&1 && REF="origin/$BASE"
git rev-parse --verify --quiet "$REF" >/dev/null 2>&1 || { echo "❌ branch '$BASE' not found" >&2; exit 2; }
WINDOW=$((DAYS * 86400))

pr_number() {  # pr_number <subject> → PR number or empty
  local re1='Merge pull request #([0-9]+)' re2='^Merged PR ([0-9]+):' re3='\(#([0-9]+)\)[[:space:]]*$'
  if [[ "$1" =~ $re1 ]] || [[ "$1" =~ $re2 ]] || [[ "$1" =~ $re3 ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}

# All first-parent commits since SINCE, oldest first: sha<TAB>epoch<TAB>subject
COMMITS=$(git log --first-parent --reverse --since="$SINCE" --format='%H%x09%ct%x09%s' "$REF" 2>/dev/null)
# Fix and revert commits anywhere in the history of base (squashed fixes are first-parent too).
LATER=$(git log --since="$SINCE" --format='%H%x09%ct%x09%s' "$REF" 2>/dev/null | grep -E $'\t''(fix(\([^)]*\))?!?:|Revert |revert(\([^)]*\))?:)' || true)

files_of() { git diff-tree --no-commit-id --name-only -r -m --first-parent "$1" 2>/dev/null | sort -u; }

review_flag() {  # review_flag <pr-sha> <file…> → flagged | not flagged | no review report
  local sha="$1"; shift
  local reports f r
  reports=$(files_of "$sha" | grep -E '^docs/reviews/.+\.md$' || true)
  [ -z "$reports" ] && { echo "no review report"; return; }
  for f in "$@"; do
    while IFS= read -r r; do
      [ -z "$r" ] && continue
      git show "$sha:$r" 2>/dev/null | grep -qF "$f" && { echo "flagged"; return; }
      git show "$sha:$r" 2>/dev/null | grep -qF "$(basename "$f")" && { echo "flagged"; return; }
    done <<EOF
$reports
EOF
  done
  echo "not flagged"
}

ROWS=""; PRS=0; SLIPS=0; MISSED=0
while IFS="$(printf '\t')" read -r sha when subject; do
  [ -z "$sha" ] && continue
  pr=$(pr_number "$subject"); [ -z "$pr" ] && continue
  PRS=$((PRS + 1))
  pfiles=$(files_of "$sha")
  while IFS="$(printf '\t')" read -r lsha lwhen lsubject; do
    [ -z "$lsha" ] && continue
    [ "$lsha" = "$sha" ] && continue
    [ "$lwhen" -lt "$when" ] && continue
    kind=""; hit=""
    case "$lsubject" in
      Revert*|revert*)
        git log -1 --format=%B "$lsha" | grep -qE "reverts commit ${sha:0:7}" && { kind="reverted"; hit=$(printf '%s\n' "$pfiles" | head -3 | tr '\n' ' '); } ;;
      *)
        [ $((lwhen - when)) -le "$WINDOW" ] || continue
        [ "$(pr_number "$lsubject")" = "$pr" ] && continue
        hit=$(comm -12 <(printf '%s\n' "$pfiles") <(files_of "$lsha") | grep -vE '^(docs/|VERSION$|CHANGELOG\.md$)' | head -3 | tr '\n' ' ')
        [ -n "$hit" ] && kind="fixed" ;;
    esac
    [ -z "$kind" ] && continue
    SLIPS=$((SLIPS + 1))
    # shellcheck disable=SC2086  # word-split the short file list on purpose
    flag=$(review_flag "$sha" $hit)
    [ "$flag" = "flagged" ] || MISSED=$((MISSED + 1))
    days=$(( (lwhen - when) / 86400 ))
    ROWS="$ROWS| #$pr | ${subject:0:60} | $kind after ${days}d by \`${lsha:0:7}\` ${lsubject:0:50} | \`${hit% }\` | $flag |
"
  done <<EOF
$LATER
EOF
done <<EOF
$COMMITS
EOF

echo "## Review metrics — $BASE since $SINCE (fix window ${DAYS}d)"
echo ""
echo "PRs merged: $PRS · slipped: $SLIPS · not flagged by review: $MISSED"
echo ""
if [ -n "$ROWS" ]; then
  echo "| PR | Merged as | What slipped | Files | Review |"
  echo "|----|-----------|--------------|-------|--------|"
  printf '%s' "$ROWS"
  echo ""
  echo "Next (.devpilot/process.md → Review the reviewers): a miss visible on a small diff becomes a"
  echo "reliability-checklist item with Origin = that PR — once the same miss shows up in ≥ 2 PRs."
else
  echo "✅ nothing reverted or fixed after merge in this window"
fi
