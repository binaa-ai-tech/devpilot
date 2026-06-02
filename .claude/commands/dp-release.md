# /dp-release — Promote through SIT → UAT → PRD

Usage: **/dp-release <stage> [version]**
- `/dp-release sit 1.1.0` — cut `release/1.1.0` from develop → auto-deploy SIT
- `/dp-release uat` — approve the UAT gate (after SIT verified)
- `/dp-release prd 1.1.0` — finish release → main + tag → PRD gate

One command, three stages. Parse the first token as `STAGE`, the rest as `VERSION`.

---

## STAGE = sit  (develop → SIT)

```bash
bash scripts/git-flow.sh release-start <VERSION>
```
Cuts `release/<VERSION>` from latest `develop`, bumps `package.json`, pushes. CI then runs
lint → test → build → **deploy SIT** automatically.

**Report:** release branch, SIT URL, Actions link. Next: test SIT → `/dp-release uat`.

---

## STAGE = uat  (manual approval gate)

1. Find the active release branch: `git branch -r | grep release/`
2. Confirm `Deploy → SIT` passed:
   `gh run list --branch $(git branch -r | grep release/ | tail -1 | xargs) --limit 1`
3. In GitHub Actions → the `release/*` run → **Review deployments** → tick **uat** →
   **Approve and deploy**. UAT requires a human click.

**Report:** UAT URL, Actions link. Next after sign-off: `/dp-release prd <version>`.

---

## STAGE = prd  (release → main → production) — ⚠️ real users

1. Confirm UAT is signed off (ask the user).
2. Assemble changelog:
   ```bash
   bash scripts/changelog.sh <VERSION>
   git add CHANGELOG.md && git commit -m "docs(changelog): v<VERSION>" || true
   ```
3. Finish the release:
   ```bash
   bash scripts/git-flow.sh release-finish <VERSION>
   ```
   Merges `release/<VERSION>` → `main`, tags `v<VERSION>`, merges back → `develop`, pushes,
   deletes the release branch. CI marks the commit **prd-ready** (does NOT auto-deploy).
4. Trigger the PRD deploy manually: Actions → `deploy-prd.yml` → **Run workflow** on `main`,
   type `deploy` to confirm.
5. Close Jira: `bash scripts/update-jira-status.sh <KEY> "Done"`

**Report:** production URL, tag `v<VERSION>`, Jira closed, Actions link.
