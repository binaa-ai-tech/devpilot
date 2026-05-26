# /ceo-be — Backend Agent Only

Task: **$ARGUMENTS**

Skip planning. Spawn the backend agent directly. Jira ticket + branch + code + PR.
Use when you know the change is backend-only and the scope is clear.

---

## Step 0 — Load config

Read `project.config.md`.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
IMPL_ENGINE=$(grep 'engine:' project.config.md | head -1 | sed 's/.*engine:[[:space:]]*//' | tr -d '"')
IMPL_MODEL_BE=$(grep 'model_backend:' project.config.md | head -1 | sed 's/.*model_backend:[[:space:]]*//' | tr -d '"')
```

If `agents.backend.enabled` is false in project.config.md, stop and tell the user.

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
bash scripts/add-jira-comment.sh "$KEY" "🚀 Backend task started [$START_TIME]
Command: /ceo-be \"$ARGUMENTS\"
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
command: /ceo-be
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

> Task: `$ARGUMENTS`. Branch: `<BRANCH>`. Implement the backend change. Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`. Run `dotnet build && dotnet test`. Commit with `feat|fix(<scope>): <description>`. Report: commit hash + what changed in 3 bullets.

### Engine: `opencode`

Write `docs/implementation/<SLUG>-backend.md` with the task description and scope.
Output:
```
⏸  IMPLEMENTATION HANDOFF — opencode (backend)
Branch: <BRANCH>
  opencode --model "<IMPL_MODEL_BE>" < docs/implementation/<SLUG>-backend.md
When done → run: /ceo resume
```
Stop here.

---

## Step 3 — PR + close

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')
DEV_URL=$(grep 'DEV_FRONTEND_URL\|dev_url' .devpilot/config.sh 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' || echo "see CI output")

PR_URL=$(gh pr create \
  --base "$BASE_BRANCH" \
  --title "$KEY: $ARGUMENTS" \
  --body "Backend change: $ARGUMENTS

Commits: $COMMITS" | tail -1)
PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

gh pr merge "$PR_NUM" --squash --delete-branch

MERGE_STATE=$(gh pr view "$PR_NUM" --json state --jq '.state')
if [ "$MERGE_STATE" = "MERGED" ]; then
  bash scripts/update-jira-status.sh "$KEY" "Done"
fi

bash scripts/add-jira-comment.sh "$KEY" "🏁 Done [$END_TIME]
PR: $PR_URL (merged into $BASE_BRANCH)
Commits: $COMMITS
Duration: $START_TIME → $END_TIME"

cat >> "docs/tasks/${KEY}.md" << EOF
## Result (completed: $END_TIME)
- PR: $PR_URL (merged)
- Commits: $COMMITS
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

🔗  Test on DEV:  <DEV_URL>
📁  Task log:  docs/tasks/<KEY>.md
──────────────────────────────────────────────────────
🚀  Promote when ready:
    1. DEV looks good?   → /binaa-sit <version>
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
