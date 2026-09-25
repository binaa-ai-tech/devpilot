#!/usr/bin/env bash
# =============================================================================
# protect-branches.sh — enforce the gate ladder server-side via GitHub branch
# protection: require the devpilot-ci check, block force-pushes and deletions.
#
#   bash scripts/protect-branches.sh                  # protects base_branch + main
#   bash scripts/protect-branches.sh develop release  # explicit branches
#
# merge_policy aware: pr-only → 1 approving review required; auto → reviews not
# required (the devpilot review gate runs in-flow), checks still required.
# Needs gh authenticated with admin rights on the repo; otherwise prints what
# to do and exits 0 (never blocks an install).
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

# Azure Repos: branch policies (set once per repo, by a project admin).
if [ "$(bash "$ROOT/scripts/git-host.sh" 2>/dev/null)" = "azure" ]; then
  MP=$(grep '^merge_policy:' project.config.md 2>/dev/null | head -1 | awk '{print $2}')
  echo "ℹ️  Azure Repos — set these branch policies on develop and main"
  echo "    (Repos → Branches → … → Branch policies):"
  echo "    • Build validation → pipeline from azure-pipelines.yml (devpilot-ci), Required, expire on push"
  echo "    • Limit merge types → Squash merge only · Check for linked work items → Optional"
  [ "${MP:-auto}" = "pr-only" ] && echo "    • Require a minimum number of reviewers → 1"
  echo "    • Security → deny 'Force push' for Contributors"
  echo "    DevPilot's PRs use auto-complete, so they merge the moment these policies pass."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "ℹ️  gh CLI not available/authenticated — protect branches manually:"
  echo "    GitHub → Settings → Branches → Add rule → require status check 'devpilot-ci',"
  echo "    block force pushes. Or: gh auth login && bash scripts/protect-branches.sh"
  exit 0
fi

REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO_SLUG" ]; then
  echo "ℹ️  No GitHub repo detected (no origin remote?) — skipping branch protection."
  exit 0
fi

BASE=$(grep '^base_branch:' project.config.md 2>/dev/null | head -1 | sed 's/base_branch:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')
BASE="${BASE:-develop}"
MERGE_POLICY=$(grep '^merge_policy:' project.config.md 2>/dev/null | head -1 | sed 's/merge_policy:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')

BRANCHES=("$@")
[ ${#BRANCHES[@]} -eq 0 ] && { BRANCHES=("$BASE"); [ "$BASE" != "main" ] && BRANCHES+=("main"); }

REVIEWS='null'
[ "${MERGE_POLICY:-auto}" = "pr-only" ] && REVIEWS='{"required_approving_review_count":1}'

RC=0
for BR in "${BRANCHES[@]}"; do
  if ! git ls-remote --exit-code --heads origin "$BR" >/dev/null 2>&1; then
    echo "  ⏭  $BR — not on origin, skipped"
    continue
  fi
  if gh api -X PUT "repos/$REPO_SLUG/branches/$BR/protection" --input - >/dev/null 2>&1 <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ["devpilot-ci"] },
  "enforce_admins": false,
  "required_pull_request_reviews": $REVIEWS,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
  then
    echo "  ✅ $BR — protected (requires devpilot-ci$([ "$REVIEWS" != null ] && echo ' + 1 review'); no force-push)"
  else
    echo "  ⚠️  $BR — could not apply protection (needs admin rights, or a private-repo plan without protection)"
    RC=0   # advisory, never fail the caller
  fi
done
exit "$RC"
