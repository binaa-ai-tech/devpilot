# /ceo-fix — Fast Bug Fix

Bug: **$ARGUMENTS**

Team Lead scopes the fix directly. No BA, no formal requirements, no QA docs.
Implement → commit → PR. Done.

---

## Step 0 — Load config

Read `project.config.md`. Extract `base_branch`, `implementation.engine`, active agents.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
IMPL_ENGINE=$(grep 'engine:' project.config.md | head -1 | sed 's/.*engine:[[:space:]]*//' | tr -d '"')
IMPL_MODEL_BE=$(grep 'model_backend:'     project.config.md | head -1 | sed 's/.*model_backend:[[:space:]]*//'  | tr -d '"')
IMPL_MODEL_FE=$(grep 'model_frontend:'    project.config.md | head -1 | sed 's/.*model_frontend:[[:space:]]*//' | tr -d '"')
IMPL_MODEL_DB=$(grep 'model_db:'          project.config.md | head -1 | sed 's/.*model_db:[[:space:]]*//'       | tr -d '"')
```

---

## Step 1 — Team Lead: Scope the fix

**Adopt Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md`.

1. Ensure project index is fresh:
   ```bash
   if find docs/project-index.md -mmin -120 2>/dev/null | grep -q .; then
     echo "Project index is fresh — skipping"
   else
     bash scripts/generate-project-index.sh
   fi
   ```
   Read `docs/project-index.md` to identify affected files.

2. Read the 2-4 most relevant source files to understand root cause.

3. Write a short scope (no file needed — keep in context):
   - Root cause: `<what is broken and why>`
   - Fix: `<exactly what to change, which files>`
   - Risk: `<any side effects>`
   - Agent: `<frontend | backend | db | integration | multiple>`

4. Derive slug: lowercase, hyphens, max 5 words from `$ARGUMENTS`
   Example: "sessions table not created" → `fix-sessions-table-not-created`

---

## Step 2 — Create Jira ticket + branch

```bash
KEY=$(bash scripts/create-jira-ticket.sh "fix: <one-line summary>" "<root cause and fix — 2 sentences>" "Task")
bash scripts/update-jira-status.sh "$KEY" "In Progress"

TICKET_NUM=$(echo "$KEY" | grep -oE '[0-9]+')
bash scripts/git-flow.sh feature-start "$TICKET_NUM" "$SLUG"
BRANCH=$(git branch --show-current)
```

Log start:
```bash
bash scripts/add-jira-comment.sh "$KEY" "🚀 Bug fix started [$START_TIME]
Command: /ceo-fix \"$ARGUMENTS\"
Branch: $BRANCH
Root cause: <root cause>
Fix: <what will be changed>"
```

Initialize task log:
```bash
mkdir -p docs/tasks
cat > "docs/tasks/${KEY}.md" << EOF
---
key: $KEY
slug: <SLUG>
command: /ceo-fix
branch: $BRANCH
base_branch: $BASE_BRANCH
started: $START_TIME
status: in-progress
---

## Bug
$ARGUMENTS

## Root Cause
<root cause>

## Fix
<what was changed>

## Timeline
| Time | Event |
|------|-------|
| $START_TIME | Started · Branch: $BRANCH |

## Commits
(updated at completion)
EOF
```

---

## Step 3 — Implementation

Determine which agent owns the fix based on scope analysis in Step 1.
Spawn only the relevant agent(s) — **do not spawn agents that have no work**.

### Engine: `claude`

**Backend fix** → spawn `subagent_type: "team-dotnet"`:
> Bug fix: `<$ARGUMENTS>`. Branch: `<BRANCH>`. Root cause: `<root cause>`. Fix: `<exact change>`. Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`. Make only the minimal required change. Run build + tests. Commit with `fix(<scope>): <description>`. Report the commit hash and what changed.

**Frontend fix** → spawn `subagent_type: "team-frontend"`:
> Bug fix: `<$ARGUMENTS>`. Branch: `<BRANCH>`. Root cause: `<root cause>`. Fix: `<exact change>`. Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`. Make only the minimal required change. Run lint + build. Commit with `fix(<scope>): <description>`. Report the commit hash and what changed.

**DB fix** → spawn `subagent_type: "team-dotnet"`:
> DB bug fix: `<$ARGUMENTS>`. Branch: `<BRANCH>`. Fix: `<exact migration or query change>`. Minimal change only. Commit. Report hash.

### Engine: `opencode`

Write `docs/implementation/<SLUG>-<agent>.md` (minimal brief — root cause + exact fix only).
Output:
```
⏸  IMPLEMENTATION HANDOFF — opencode
Branch: <BRANCH>
  opencode --model "<MODEL>" < docs/implementation/<SLUG>-<agent>.md
When done → run: /ceo resume
```
Stop here.

---

## Step 4 — Implementation verify + log

After agent completes:
```bash
git log ${BASE_BRANCH}..HEAD --oneline   # confirm commit exists
IMPL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | tr '\n' ' ')
bash scripts/add-jira-comment.sh "$KEY" "⚙️ Fix implemented [$IMPL_TIME]
Commits: $COMMITS"
```

---

## Step 5 — QA

Spawn with `subagent_type: "team-qa"`:

> Bug fix QA for `$ARGUMENTS`. Branch: `<BRANCH>`. Verify the fix works correctly, the broken behavior is resolved, and no regressions introduced. Write QA report to `docs/qa/<SLUG>.md`. Verdict: PASS or BLOCKED.

```bash
QA_TIME=$(date '+%Y-%m-%d %H:%M:%S')
# PASS:
bash scripts/add-jira-comment.sh "$KEY" "✅ QA passed [$QA_TIME] — fix verified. Report: docs/qa/<SLUG>.md"
# BLOCKED:
bash scripts/add-jira-comment.sh "$KEY" "🚫 QA BLOCKED [$QA_TIME] — see docs/qa/<SLUG>.md"
```

If BLOCKED: fix the issue, then re-run QA.

---

## Step 6 — Create PR + auto-merge into develop

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
ALL_COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline 2>/dev/null | awk '{print $1}' | head -10 | tr '\n' ' ')

PR_URL=$(gh pr create \
  --base "$BASE_BRANCH" \
  --title "$KEY: fix: <summary>" \
  --body "## Bug Fix: $ARGUMENTS

**Root cause:** <root cause>
**Fix:** <what changed>
**Risk:** <side effects or none>
**QA:** PASS — docs/qa/<SLUG>.md

Commits: $ALL_COMMITS" | tail -1)
PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

# Auto-merge into develop — production (main) requires /binaa-prd with human sign-off
if gh pr merge "$PR_NUM" --squash 2>&1; then
  bash scripts/update-jira-status.sh "$KEY" "Done"
  bash scripts/add-jira-comment.sh "$KEY" "✅ Merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
QA: PASS · Commits: $ALL_COMMITS
Duration: $START_TIME → $END_TIME
→ Promote: /binaa-sit <version>"
else
  bash scripts/update-jira-status.sh "$KEY" "In Review"
  echo "⚠️  Auto-merge failed — merge $PR_URL manually, then: bash scripts/update-jira-status.sh $KEY Done"
fi
```

Update task log:
```bash
cat >> "docs/tasks/${KEY}.md" << EOF

## Result (merged: $END_TIME)
- PR: $PR_URL (merged into $BASE_BRANCH)
- Jira: $KEY → Done
- Commits: $ALL_COMMITS
EOF
```

---

## Final Output — DONE Block

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  DONE — Merged into <BASE_BRANCH>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  Jira:    <KEY> → Done
🔀  Merged:  <PR URL> → <BASE_BRANCH>
⏱  Time:    <START_TIME> → <END_TIME>
🔖  Commits: <hash1> · <hash2>

📦  What was fixed:
    • Root cause: <root cause>
    • Changed: <files/what changed>
    • QA: PASS

🔗  DEV deploys automatically from <BASE_BRANCH> after CI passes (~5 min)
📁  Task log:  docs/tasks/<KEY>.md
──────────────────────────────────────────────────────
🚀  Promote to production when ready:
    1. DEV ready?        → /binaa-sit <version>
       Tip: bug fixes bump PATCH (1.0.0 → 1.0.1)
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
         ↑ Production PR opens here — requires your review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
