# /dp-review-fix — Address PR review comments

PR: **$ARGUMENTS** (a PR number or URL on `develop`).

Pull the open review comments, fix them on the PR's branch, and push. No new sprint.

## Flow
1. **Fetch the review threads:**
   ```bash
   gh pr view $ARGUMENTS --json number,headRefName,reviewThreads,comments
   gh pr checkout $ARGUMENTS
   ```
2. **Triage** each unresolved comment: actionable change vs. discussion. List them.
3. **Fix** on the PR branch, per the resolved engine. Read `.devpilot/skills/code-review.md`
   and `.devpilot/skills/self-heal.md`. Keep each fix scoped to its comment.
4. **Audit** the diff before pushing:
   ```bash
   bash scripts/audit.sh
   ```
5. **Commit + push:**
   ```bash
   git commit -am "fix(review): address PR #$ARGUMENTS comments"
   git push
   ```
6. **Reply** on each thread with what changed; re-request review.

**Report:** comments addressed, commit hash, push status.
