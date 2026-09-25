# /dp-release — DevOps: promote SIT → UAT → PRD, or roll back

Usage: **/dp-release <stage> [version]**
- `/dp-release sit 1.1.0` — cut `release/1.1.0` from develop → auto-deploy SIT
- `/dp-release uat` — promote the verified SIT build to UAT
- `/dp-release prd 1.1.0` — finish release → `main` + tag → production (human approval)
- `/dp-release rollback [version]` — roll production back to a previous tag

Parse the first token as `STAGE`, the rest as `VERSION`. Governing skill:
`.devpilot/skills/release-ops.md` (build once, promote the same artifact, never skip an
environment, PRD always gated by a human).

---

## STAGE = sit  (develop → SIT)

```bash
bash scripts/git-flow.sh release-start <VERSION>
```
Cuts `release/<VERSION>` from latest `develop`, bumps the version, pushes. CI then runs
lint → test → build → **deploy SIT** automatically.

**Report:** release branch, SIT URL, Actions link. Next: `/dp-release uat`.

---

## STAGE = uat  (SIT → UAT)

1. Find the active release branch: `git branch -r | grep release/ | tail -1`.
2. Confirm the SIT deploy and its smoke tests passed on that branch (`gh run list --branch
   <release-branch> --limit 1`, or `mcp__github__actions_list` without `gh`). Red → stop and
   report; never promote a failed build.
3. Approve the `uat` environment in GitHub Actions (**Review deployments → uat → Approve**).
   Environment protection rules decide who may approve; DevPilot never bypasses them.

**Report:** UAT URL, Actions link. Next, after stakeholder sign-off: `/dp-release prd <version>`.

---

## STAGE = prd  (release → main → production) — ⚠️ real users

1. Confirm UAT is signed off (ask the user — the one deliberate human gate in the pipeline).
2. Assemble the changelog:
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
4. Production deploy: Actions → `deploy-prd.yml` → **Run workflow** on `main` (protected
   `production` environment approval).
5. Close the release's Stories: `bash scripts/update-jira-status.sh <KEY> "Done"`.

**Report:** production URL, tag `v<VERSION>`, Stories closed, Actions link.

---

## STAGE = rollback  (production → previous tag)

Conservative by design: shows the plan first, creates the rollback branch only on confirm.
Never force-pushes or rewrites production history.

```bash
bash scripts/rollback.sh <VERSION>              # dry run — see the plan
CONFIRM=1 bash scripts/rollback.sh <VERSION>    # create + push rollback/<version>
```
Then open a PR from `rollback/<version>` → `main`, get it approved, and redeploy that tag via
`/dp-release prd <version>`. Every production rollback gets a postmortem
(`release-ops.md` → Incidents & postmortems).
