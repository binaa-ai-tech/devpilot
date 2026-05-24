# Start Work — Full Automated Flow

When the user describes a task, execute all stages without stopping unless a
stop condition is hit.

---

## Stages (run in order, no approval pauses unless stated)

### 1. Create Jira ticket

```bash
./scripts/create-jira-ticket.sh "<summary>" "<description>" "<Story|Bug|Task>"
```

Note the ticket key (e.g. MSK-8).

---

### 2. Triage + Impact map

- Read all files relevant to the task
- Write `.aidev/impact-maps/<KEY>.md` using `.aidev/templates/impact-map.md`
- Follow `.aidev/rules.md`

---

### 3. Create feature branch (from develop)

```bash
bash scripts/git-flow.sh feature-start <ticket-number> <short-slug>
# e.g. bash scripts/git-flow.sh feature-start 42 map-filters

./scripts/update-jira-status.sh <KEY> "In Progress"
```

> For hotfixes: `bash scripts/git-flow.sh hotfix-start <n> <slug>` (branches from main)

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

### 7. Pipeline — walk through environments

#### 7a. DEV (automatic)
After the PR merges to `develop`, CI triggers automatically:
- lint → test → build → **deploy DEV**

#### 7b. Cut release branch → SIT (automatic)
When ready to ship:
```bash
bash scripts/git-flow.sh release-start <X.Y.Z>
```
CI triggers on the `release/X.Y.Z` push → **deploy SIT**

#### 7c. UAT (manual approval)
After SIT passes, approve in GitHub Actions:
1. Open the Actions tab for the `release/X.Y.Z` workflow run
2. Click **Review deployments → uat → Approve**

#### 7d. Merge to main → PRD (manual approval)
```bash
bash scripts/git-flow.sh release-finish <X.Y.Z>
```
CI triggers on `main` push → approve **PRD** in GitHub Actions the same way.

#### 7e. Close ticket
```bash
./scripts/update-jira-status.sh <KEY> "Done"
```

---

## Hotfix flow

```bash
bash scripts/git-flow.sh hotfix-start <n> <slug>
# implement + commit
bash scripts/git-flow.sh hotfix-finish <X.Y.Z>
# CI on main → approve PRD in GitHub Actions
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
