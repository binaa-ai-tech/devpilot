# /binaa-uat — Approve UAT deployment

Approves the UAT gate in GitHub Actions after SIT has been verified.

*(No arguments needed — run this when SIT testing is complete)*

---

## What this command does

1. **Check which release branch is active**:
   ```bash
   git branch -r | grep release/
   ```

2. **Check SIT deploy status** — confirm the `Deploy → SIT` job passed:
   ```bash
   gh run list --branch $(git branch -r | grep release/ | tail -1 | xargs) --limit 1
   ```

3. **Print the UAT approval link**:
   - Open: https://github.com/binaa-ai-tech/maskan/actions
   - Find the workflow run for the `release/*` branch
   - Click **"Review deployments"** → tick **uat** → **Approve and deploy**

4. **Wait for UAT deploy** — confirm `Deploy → UAT` job passes ✅

5. **Report UAT URL** for final testing before production

## ⚠️ Manual approval gate
UAT requires a human click in GitHub Actions before deploying.
Required reviewers can be enforced in **Settings → Environments → uat**
(needs GitHub Team plan on private repos).

## When done, report:
- UAT environment URL
- GitHub Actions link
- Next command after UAT sign-off: `/binaa-prd <version>`
