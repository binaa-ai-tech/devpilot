# /ceo-db — DB Agent Only

Task: **$ARGUMENTS**

Skip planning. Spawn the DB agent directly for migrations, schema changes, or SQL fixes.
Jira ticket + branch + migration + PR.

---

## Step 0 — Load config

Read `project.config.md`.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
IMPL_ENGINE=$(grep 'engine:' project.config.md | head -1 | sed 's/.*engine:[[:space:]]*//' | tr -d '"')
IMPL_MODEL_DB=$(grep 'model_db:' project.config.md | head -1 | sed 's/.*model_db:[[:space:]]*//' | tr -d '"')
```

If `agents.db.enabled` is false in project.config.md, stop and tell the user.

---

## Step 1 — Derive slug + create Jira ticket + branch

```bash
SLUG="<derived from $ARGUMENTS — lowercase, hyphens, max 5 words>"

KEY=$(bash scripts/create-jira-ticket.sh "<summary>" "$ARGUMENTS" "Task")
bash scripts/update-jira-status.sh "$KEY" "In Progress"

TICKET_NUM=$(echo "$KEY" | grep -oE '[0-9]+')
bash scripts/git-flow.sh feature-start "$TICKET_NUM" "$SLUG"
BRANCH=$(git branch --show-current)
```

Log start:
```bash
bash scripts/add-jira-comment.sh "$KEY" "🚀 DB task started [$START_TIME]
Command: /ceo-db \"$ARGUMENTS\"
Branch: $BRANCH
Engine: $IMPL_ENGINE"
```

Initialize task log:
```bash
mkdir -p docs/tasks
cat > "docs/tasks/${KEY}.md" << EOF
---
key: $KEY
slug: $SLUG
command: /ceo-db
branch: $BRANCH
base_branch: $BASE_BRANCH
started: $START_TIME
status: in-progress
---
## Task
$ARGUMENTS
## Commits
(updated at completion)
EOF
```

---

## Step 2 — Implementation

### Engine: `claude`

Spawn `subagent_type: "team-dotnet"`:

> DB task: `$ARGUMENTS`. Branch: `<BRANCH>`. Implement the required migration or schema change. Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`. Use EF Core migrations (add migration + update model snapshot). Verify migration runs without errors. Commit with `feat|fix(db): <description>`. Report: migration name + commit hash + what changed.

### Engine: `opencode`

Write `docs/implementation/<SLUG>-db.md` with the task description and schema change details.
Output:
```
⏸  IMPLEMENTATION HANDOFF — opencode (db)
Branch: <BRANCH>
  opencode --model "<IMPL_MODEL_DB>" < docs/implementation/<SLUG>-db.md
When done → run: /ceo resume
```
Stop here.

---

## Step 3 — QA

Spawn with `subagent_type: "team-qa"`:

> DB QA for `$ARGUMENTS`. Branch: `<BRANCH>`. Verify the migration runs without errors, schema changes are correct, no data regressions. Write QA report to `docs/qa/<SLUG>.md`. Verdict: PASS or BLOCKED.

```bash
QA_TIME=$(date '+%Y-%m-%d %H:%M:%S')
bash scripts/add-jira-comment.sh "$KEY" "✅ QA passed [$QA_TIME] — docs/qa/<SLUG>.md"
```

If BLOCKED: fix the issue, then re-run QA.

---

## Step 4 — Create PR + auto-merge into develop

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')

PR_URL=$(gh pr create \
  --base "$BASE_BRANCH" \
  --title "$KEY: $ARGUMENTS" \
  --body "DB change: $ARGUMENTS

QA: PASS — docs/qa/<SLUG>.md
Commits: $COMMITS" | tail -1)
PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

# Auto-merge into develop — production (main) requires /binaa-prd with human sign-off
if gh pr merge "$PR_NUM" --squash 2>&1; then
  bash scripts/update-jira-status.sh "$KEY" "Done"
  bash scripts/add-jira-comment.sh "$KEY" "✅ Merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
QA: PASS · Commits: $COMMITS
Duration: $START_TIME → $END_TIME
→ Promote: /binaa-sit <version>"
else
  bash scripts/update-jira-status.sh "$KEY" "In Review"
  echo "⚠️  Auto-merge failed — merge $PR_URL manually, then: bash scripts/update-jira-status.sh $KEY Done"
fi

cat >> "docs/tasks/${KEY}.md" << EOF
## Result (merged: $END_TIME)
- PR: $PR_URL (merged into $BASE_BRANCH)
- Jira: $KEY → Done
- Commits: $COMMITS
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

📦  What was built:
    • Migration: <migration name>
    • Changed: <tables / columns affected>
    • QA: PASS

🔗  DEV deploys automatically from <BASE_BRANCH> after CI passes
📁  Task log:  docs/tasks/<KEY>.md
──────────────────────────────────────────────────────
🚀  Promote to production when ready:
    1. DEV ready?        → /binaa-sit <version>
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
         ↑ Production PR opens here — requires your review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
