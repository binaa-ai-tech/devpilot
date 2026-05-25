# Start Work — Full Automated Flow

When the user describes a task, execute all stages without stopping unless a
stop condition is hit.

---

## Stages (run in order, no approval pauses unless stated)

### 1. Create Jira ticket

```bash
./scripts/create-jira-ticket.sh "<summary>" "<description>" "<Story|Bug|Task>"
```

Note the ticket key (e.g. KEY-8).

---

### 2. Triage + Impact map

- Read all files relevant to the task
- Write `.aidev/impact-maps/<KEY>.md` using `.aidev/templates/impact-map.md`
- Follow `.aidev/rules.md`

---

### 3. Create feature branch (from develop)

```bash
bash scripts/git-flow.sh feature-start <ticket-number> <short-slug>
# e.g. bash scripts/git-flow.sh feature-start 8 search-reranking

./scripts/update-jira-status.sh <KEY> "In Progress"
```

> For hotfixes: use `bash scripts/git-flow.sh hotfix-start <n> <slug>` (branches from main)

---

### 4. Implement with opencode

Build the implementation prompt from the relevant `.aidev/prompts/4-implement-*.md`
file (bugfix / feature / refactor). Substitute the ticket key and impact map
content. Save to `/tmp/opencode-prompt.txt`, then run:

```bash
opencode run \
  -m "github-copilot/gpt-5.3-codex" \
  --dangerously-skip-permissions \
  "$(cat /tmp/opencode-prompt.txt)"
```

Wait for opencode to finish before continuing.

---

### 5. Self-review

```bash
git diff develop...HEAD
```

Run review against `.aidev/rules.md` per `5-self-review.md`.

- ✅ or ⚠️ (warnings only) → continue
- ❌ BLOCKERS → fix then re-review before continuing

---

### 6. Commit, push, open PR → develop

```bash
git add -A
git commit -m "<type>(<scope>): <description>"
git push origin <branch>

# PR targets develop (not main)
gh pr create \
  --base develop \
  --title "<KEY>: <description>" \
  --body "$(cat .aidev/templates/pr-description.md)"

gh pr merge --auto --squash --delete-branch
```

---

### 7. Pipeline — wait for CI, then walk through environments

#### 7a. DEV (automatic)
After the PR merges to `develop`, CI triggers automatically:
- lint → test → build → **deploy DEV**

Watch: https://github.com/<org>/<repo>/actions

#### 7b. Cut release branch → SIT (automatic)
When the feature is ready to ship:

```bash
bash scripts/git-flow.sh release-start <X.Y.Z>
```

CI triggers automatically on the `release/X.Y.Z` push:
- lint → test → build → **deploy SIT**

#### 7c. UAT (manual approval required)
After SIT deploys, CI waits for a human to approve UAT in GitHub Actions:

1. Go to https://github.com/<org>/<repo>/actions
2. Find the running workflow for `release/X.Y.Z`
3. Click **Review deployments → uat → Approve**

CI then deploys to UAT automatically.

> ⚠ Manual approval requires GitHub Team plan. On the free plan, UAT deploys
> automatically after SIT — add a required reviewer in
> **Settings → Environments → uat** once you upgrade.

#### 7d. Merge to main → PRD (manual approval required)
After UAT sign-off, finish the release:

```bash
bash scripts/git-flow.sh release-finish <X.Y.Z>
# merges release/X.Y.Z → main, tags vX.Y.Z, merges back → develop
```

CI triggers on the `main` push:
- lint → test → build → **(manual approval)** → **deploy PRD**

Approve in GitHub Actions the same way as UAT.

#### 7e. Close ticket

```bash
./scripts/update-jira-status.sh <KEY> "Done"
```

---

## Hotfix flow (skip to here for production emergencies)

```bash
bash scripts/git-flow.sh hotfix-start <n> <slug>
# implement fix
bash scripts/git-flow.sh hotfix-finish <X.Y.Z>
# CI runs on main → approve PRD deployment in GitHub Actions
./scripts/update-jira-status.sh <KEY> "Done"
```

---

## Stop conditions (only these cause a pause)

- ❌ Blockers in self-review that cannot be auto-fixed
- Build or lint failure that cannot be resolved automatically
- Ambiguity that changes the scope significantly

---

## Done — report to user

- Jira ticket URL
- PR URL
- What was implemented (3 bullet points max)
- Current pipeline stage (DEV / SIT / UAT / awaiting PRD approval)
