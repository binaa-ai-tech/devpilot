#!/usr/bin/env bash
# =============================================================================
# protect-branches.sh — enforce the gate ladder server-side:
#   GitHub      → branch protection: require the devpilot-ci check, block force-pushes/deletions
#   Azure Repos → branch policies: devpilot-ci build validation, squash only, comments resolved
#                 (+ 1 reviewer under pr-only); pushes must go through a PR
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

# Azure Repos: branch policies via REST (azdo.sh protect). Any required policy
# also forces every change through a PR — direct and force pushes are rejected.
if [ "$(bash "$ROOT/scripts/git-host.sh" 2>/dev/null)" = "azure" ]; then
  MP=$(grep '^merge_policy:' project.config.md 2>/dev/null | head -1 | awk '{print $2}')
  BASE=$(grep '^base_branch:' project.config.md 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"'); BASE="${BASE:-develop}"
  REVIEWERS=0; [ "${MP:-auto}" = "pr-only" ] && REVIEWERS=1
  BRANCHES=("$@"); [ ${#BRANCHES[@]} -eq 0 ] && { BRANCHES=("$BASE"); [ "$BASE" != "main" ] && BRANCHES+=("main"); }
  manual() {
    echo "ℹ️  Set these branch policies on ${BRANCHES[*]} by hand (Repos → Branches → … → Branch policies):"
    echo "    • Build validation → the devpilot-ci pipeline (azure-pipelines.yml), Required"
    echo "    • Limit merge types → Squash merge only · Comment resolution → Required"
    [ "$REVIEWERS" -gt 0 ] && echo "    • Minimum number of reviewers → 1"
    echo "    Automate it: a PAT with Code (Read, write & manage) + Build (Read & execute), project admin rights,"
    echo "    then: bash scripts/protect-branches.sh"
  }
  if ! bash "$ROOT/scripts/azdo.sh" repo-id >/dev/null 2>&1; then manual; exit 0; fi
  BUILD_ID=""
  if [ -f azure-pipelines.yml ]; then
    BUILD_ID=$(bash "$ROOT/scripts/azdo.sh" pipeline-ensure devpilot-ci azure-pipelines.yml 2>/dev/null) \
      || echo "  ⚠️  devpilot-ci pipeline not created — commit azure-pipelines.yml to the default branch, then re-run"
  fi
  FAILED=0
  for BR in "${BRANCHES[@]}"; do
    git ls-remote --exit-code --heads origin "$BR" >/dev/null 2>&1 || { echo "  ⏭  $BR — not on origin, skipped"; continue; }
    bash "$ROOT/scripts/azdo.sh" protect "$BR" --reviewers "$REVIEWERS" ${BUILD_ID:+--build "$BUILD_ID"} || FAILED=1
  done
  if [ "$FAILED" = 1 ]; then echo "  ⚠️  some policies could not be applied (needs project admin rights)"; manual; fi
  echo "  DevPilot PRs use auto-complete: they merge the moment these policies pass."
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

# Features squash-merge; release/hotfix PRs need merge commits — allow both on the repo.
gh api -X PATCH "repos/$REPO_SLUG" -F allow_squash_merge=true -F allow_merge_commit=true >/dev/null 2>&1 \
  && echo "  ✅ repo allows squash (features) + merge commits (release/hotfix PRs)" \
  || echo "  ⚠️  could not update merge settings — enable 'Allow merge commits' + 'Allow squash merging' (Settings → General)"

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
