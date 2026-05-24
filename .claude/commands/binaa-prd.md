# /binaa-prd — Finish release → main → PRD

Merges the release branch into `main`, creates the version tag, and triggers the PRD deployment pipeline.

Version: **$ARGUMENTS**  
*(e.g. `/binaa-prd 1.1.0`)*

---

## What this command does

1. **Confirm UAT is signed off** — ask user to confirm UAT testing is complete before proceeding

2. **Finish the release**:
   ```bash
   bash scripts/git-flow.sh release-finish $ARGUMENTS
   ```
   This will:
   - Merge `release/$ARGUMENTS` → `main`
   - Tag `v$ARGUMENTS`
   - Merge `release/$ARGUMENTS` back → `develop`
   - Push `main`, `develop`, and `v$ARGUMENTS` tag
   - Delete the release branch

3. **CI triggers automatically** on the `main` push:
   - lint → test → build → **(manual approval gate)** → **deploy PRD**

4. **Print the PRD approval link**:
   - Open: https://github.com/binaa-ai-tech/maskan/actions
   - Find the workflow run on `main`
   - Click **"Review deployments"** → tick **prd** → **Approve and deploy**

5. **Close Jira ticket**:
   ```bash
   ./scripts/update-jira-status.sh <KEY> "Done"
   ```

## ⚠️ This deploys to PRODUCTION — real users, real data
- Only run after UAT sign-off
- The manual approval gate in GitHub Actions is the last safety check

## When done, report:
- Production URL
- Git tag created: `v$ARGUMENTS`
- Jira ticket closed
- GitHub Actions link
