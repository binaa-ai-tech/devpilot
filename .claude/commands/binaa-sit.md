# /binaa-sit — Cut release branch → SIT

Promotes the current `develop` state to the SIT environment.

Version: **$ARGUMENTS**  
*(e.g. `/binaa-sit 1.1.0`)*

---

## What this command does

1. **Verify develop is green** — check latest CI run on `develop` passes
2. **Cut release branch**:
   ```bash
   bash scripts/git-flow.sh release-start $ARGUMENTS
   ```
   This will:
   - Checkout `develop`, pull latest
   - Create `release/$ARGUMENTS`
   - Bump `package.json` version to `$ARGUMENTS`
   - Push `release/$ARGUMENTS` to origin

3. **CI triggers automatically** on the push:
   - lint → test → build → **deploy SIT** (auto)

4. **Watch and confirm**:
   - Open: https://github.com/binaa-ai-tech/maskan/actions
   - Wait for the `Deploy → SIT` job to show ✅

## When done, report:
- Release branch name: `release/$ARGUMENTS`
- SIT environment URL to test
- GitHub Actions link
- Next step: test on SIT, then run `/binaa-uat` to approve UAT
