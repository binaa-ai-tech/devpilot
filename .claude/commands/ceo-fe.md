# /ceo-fe — Frontend Agent Only

Task: **$ARGUMENTS**

Skip planning. Spawn the frontend agent directly. Jira ticket + branch + code + PR.
Use when you know the change is frontend-only and the scope is clear.

---

## Step 0 — Load config

Read `project.config.md`.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
IMPL_ENGINE=$(grep 'engine:' project.config.md | head -1 | sed 's/.*engine:[[:space:]]*//' | tr -d '"')
IMPL_MODEL_FE=$(grep 'model_frontend:' project.config.md | head -1 | sed 's/.*model_frontend:[[:space:]]*//' | tr -d '"')
```

If `agents.frontend.enabled` is false in project.config.md, stop and tell the user.

---

## Step 1 — Derive slug + create Jira ticket + branch

```bash
# Derive SLUG from $ARGUMENTS (lowercase, hyphens, max 5 words)
SLUG="<derived-slug>"

KEY=$(bash scripts/create-jira-ticket.sh "<summary>" "$ARGUMENTS" "Task")
bash scripts/update-jira-status.sh "$KEY" "In Progress"

TICKET_NUM=$(echo "$KEY" | grep -oE '[0-9]+')
bash scripts/git-flow.sh feature-start "$TICKET_NUM" "$SLUG"
BRANCH=$(git branch --show-current)
```

Log start:
```bash
bash scripts/add-jira-comment.sh "$KEY" "🚀 Frontend task started [$START_TIME]
Command: /ceo-fe \"$ARGUMENTS\"
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
command: /ceo-fe
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

Spawn `subagent_type: "team-frontend"`:

> Task: `$ARGUMENTS`. Branch: `<BRANCH>`. Implement the frontend change. Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`. Run lint + build. Commit with `feat|fix(<scope>): <description>`. Report: commit hash + what changed in 3 bullets.

### Engine: `opencode`

Write `docs/implementation/<SLUG>-frontend.md` with the task description and scope.
Output:
```
⏸  IMPLEMENTATION HANDOFF — opencode (frontend)
Branch: <BRANCH>
  opencode --model "<IMPL_MODEL_FE>" < docs/implementation/<SLUG>-frontend.md
When done → run: /ceo resume
```
Stop here.

---

## Step 3 — QA

Spawn with `subagent_type: "team-qa"`:

> Frontend QA for `$ARGUMENTS`. Branch: `<BRANCH>`. Verify the change works correctly, UI renders as expected, no regressions. Write QA report to `docs/qa/<SLUG>.md`. Verdict: PASS or BLOCKED.

```bash
QA_TIME=$(date '+%Y-%m-%d %H:%M:%S')
bash scripts/add-jira-comment.sh "$KEY" "✅ QA passed [$QA_TIME] — docs/qa/<SLUG>.md"
```

If BLOCKED: fix the issue, then re-run QA.

---

## Step 4 — Open PR (do NOT merge)

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')
DEV_URL=$(grep 'DEV_FRONTEND_URL\|dev_url' .devpilot/config.sh 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' || echo "see CI output")

PR_URL=$(gh pr create \
  --base "$BASE_BRANCH" \
  --title "$KEY: $ARGUMENTS" \
  --body "Frontend change: $ARGUMENTS

QA: PASS — docs/qa/<SLUG>.md
Commits: $COMMITS" | tail -1)

bash scripts/update-jira-status.sh "$KEY" "In Review"
bash scripts/add-jira-comment.sh "$KEY" "👀 PR open [$END_TIME]
PR: $PR_URL
QA: PASS · Commits: $COMMITS
Duration: $START_TIME → $END_TIME
→ After merge: bash scripts/update-jira-status.sh $KEY Done"

cat >> "docs/tasks/${KEY}.md" << EOF
## Result (PR open: $END_TIME)
- PR: $PR_URL (awaiting review)
- Jira: $KEY → In Review
- Commits: $COMMITS
- After merge: bash scripts/update-jira-status.sh $KEY Done
EOF
```

---

## Final Output — DONE Block

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  DONE — Ready for your review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  Jira:    <KEY> → Done
🔀  PR:      <PR URL> (merged into <BASE_BRANCH>)
⏱  Time:    <START_TIME> → <END_TIME>
🔖  Commits: <hash1> · <hash2>

📦  What was built:
    • <bullet 1>
    • <bullet 2>

👀  PR open — review and merge when ready:
    <PR URL>

    After merging:
    bash scripts/update-jira-status.sh <KEY> Done

🔗  DEV deploys automatically after merge + CI passes
📁  Task log:  docs/tasks/<KEY>.md
──────────────────────────────────────────────────────
🚀  Promote when ready:
    1. DEV looks good?   → /binaa-sit <version>
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
