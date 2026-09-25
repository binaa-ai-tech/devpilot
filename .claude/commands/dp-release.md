# /dp-release — DevOps: promote DEV → SIT → UAT → PRD, or roll back

Usage: **/dp-release <stage> [version]**
- `/dp-release sit` — cut `release/<version>` from develop; the CD pipeline builds it **once** and
  deploys that artifact to SIT. The version defaults to the one develop already carries (every
  `/dp-deliver` merge bumped it).
- `/dp-release uat` — confirm SIT is green; the same run is now waiting at the **UAT approval**.
- `/dp-release prd` — confirm UAT is green; after a human approves **PRD**, verify the deploy,
  then finish the release (merge → `main`, tag `v<version>`, merge back → develop).
- `/dp-release rollback [version]` — redeploy a previous tag to production (approval-gated).

Governing skill: `.devpilot/skills/release-ops.md` — build once, promote the same artifact,
never skip an environment, production always approved by a human. DevPilot **never approves a
deployment itself**; it tells the user exactly what to approve and verifies the result.

The pipeline is `devpilot-cd` (`.github/workflows/devpilot-cd.yml` or `azure-pipelines-cd.yml`,
from `scripts/generate-ci.sh`); environments + approvals come from `scripts/setup-environments.sh`.
Missing either → run `/dp-setup pipelines` first.

> **Reading the pipeline** — `HOST=$(bash scripts/git-host.sh)`
> - GitHub: `gh run list --workflow devpilot-cd --branch <branch> --limit 1 --json databaseId,status,conclusion,url`,
>   then `gh run view <id> --json jobs` (per-environment job status); without `gh`,
>   `mcp__github__actions_list` / `mcp__github__actions_get`.
> - Azure: `bash scripts/azdo.sh ci <branch>` (latest run + status; `--log` for failed steps).
>
> A job/stage **waiting** = pending approval. **Failed** = stop, show the failed step's log, and never
> ask anyone to approve the next stage.

---

## STAGE = sit  (develop → release branch → SIT)

```bash
bash scripts/git-flow.sh release-start ${VERSION:-}     # default: the version develop carries
```
Pushing `release/<version>` starts `devpilot-cd`: **build once** (Angular dist + `dotnet publish`
+ idempotent EF migration script, stamped with the version) → **SIT** deploy → smoke test.
Wait for the SIT job/stage and report its result.

**Report:** release branch, pipeline run link, SIT URL, smoke result. Next: `/dp-release uat`.

---

## STAGE = uat  (SIT → UAT)

1. Active release: `git branch -r | grep 'origin/release/' | sort -V | tail -1`.
2. SIT green on the latest run of that branch. Red → stop, report the log.
3. Tell the user to **approve UAT** — GitHub: run page → *Review deployments* → `uat` → Approve;
   Azure: run → stage **UAT** → *Review* → Approve. Only configured approvers can.
4. After approval, wait for the UAT job and its smoke test; report.

**Report:** UAT URL, run link. Next, after stakeholder sign-off: `/dp-release prd`.

---

## STAGE = prd  (UAT → PRODUCTION) — ⚠️ real users

1. UAT green on the same run, and the user confirms **UAT sign-off** (the one question asked here).
2. Tell the user to **approve PRD** on that run. Wait for the PRD job + smoke test.
   PRD failed → stop, do not tag; offer `/dp-release rollback`.
3. PRD green → finish the release so `main` and the tag match exactly what is live:
   ```bash
   bash scripts/changelog.sh <VERSION>          # docs/changes/* entries → "## v<VERSION>" section
   git add -A CHANGELOG.md docs/changes && git commit -m "docs(changelog): v<VERSION>" || true
   bash scripts/git-flow.sh release-finish <VERSION>
   ```
   `main` and `develop` are protected, so this goes **through PRs**: release → `main` (merge commit)
   → tag `v<VERSION>` on main → release → `develop` (merge commit) → delete the branch. Exit 3 = a PR
   is open but not merged yet (checks running, an approval, or no `gh` — then merge it with
   `mcp__github__merge_pull_request`, `merge_method: "merge"`); re-run the same command once it
   merged — finished steps are skipped. A conflict on the back-merge → `/dp-pr <PR>`.
4. Release notes on the shipped items (they were closed at merge time) — the changelog knows them:
   ```bash
   for KEY in $(bash scripts/changelog.sh keys <VERSION>); do
     bash scripts/tracker.sh comment "$KEY" "🚀 Released to production in v<VERSION>"
   done
   ```

**Report:** production URL, tag `v<VERSION>`, run link, items noted.

---

## STAGE = rollback  (production → a previous tag)

Conservative: show the plan first, act on confirmation, never force-push or rewrite history.
1. Target = `[version]`, or the tag before the current one: `git tag -l 'v*' --sort=-version:refname | sed -n 2p`.
2. Confirm with the user: "Redeploy v<target> to PRD (currently v<current>)?"
3. Run the pipeline **on that tag** for one environment — it builds from the tag and still waits
   for the PRD approval:
   - GitHub: `gh workflow run devpilot-cd --ref v<target> -f environment=prd`
     (or `mcp__github__actions_run_trigger`)
   - Azure: Pipelines → devpilot-cd → *Run pipeline* → tag `v<target>`, parameter `environment = prd`.
4. Tell the user to approve PRD; verify the smoke test.
5. Code follow-up: `bash scripts/rollback.sh <target>` (dry run) → `CONFIRM=1 …` creates
   `rollback/<target>`; open a PR to `main` with
   `bash scripts/open-pr.sh main "Rollback to v<target>" "<why>" --no-merge`.
   Every production rollback gets a postmortem (`release-ops.md` → Incidents & postmortems).

**Report:** rolled back to v<target>, run link, smoke result, postmortem path.
