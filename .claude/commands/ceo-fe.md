# /ceo-fe — Frontend Agent Only

Task: **$ARGUMENTS**

Skip planning. Spawn the frontend agent directly. Jira ticket + branch + code + PR.
Use when you know the change is frontend-only and the scope is clear.

---

## Step 0 — Load config

Read `project.config.md`.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')

IMPL_ENGINE=$(grep -A 10 '^engines:' project.config.md | grep '^\s*coding:' | head -1 | sed 's/.*coding:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
[ -z "$IMPL_ENGINE" ] && IMPL_ENGINE="claude"

IMPL_MODEL_FE=$(grep -A 20 "^  ${IMPL_ENGINE}:" project.config.md 2>/dev/null \
  | grep '    frontend:' | head -1 | sed 's/.*frontend:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
```

If `agents.frontend.enabled` is false in project.config.md, stop and tell the user.
If `project.config.md` is missing, stop and tell the user to run `bash install.sh`.

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

⚠️ **CRITICAL: Use the Bash tool to run the engine command directly. NEVER output a HANDOFF block. NEVER ask the user to run anything manually.**

Write `docs/implementation/<SLUG>-frontend.md` with the task description and scope.
Then immediately run via Bash tool:
```bash
$IMPL_ENGINE --model "$IMPL_MODEL_FE" < "docs/implementation/${SLUG}-frontend.md"
```
Proceed to QA when it exits 0.

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

## Step 4 — Create PR + auto-merge into develop

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')

PR_URL=$(gh pr create \
  --base "$BASE_BRANCH" \
  --title "$KEY: $ARGUMENTS" \
  --body "Frontend change: $ARGUMENTS

QA: PASS — docs/qa/<SLUG>.md
Commits: $COMMITS" | tail -1)
PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

# Auto-merge into develop — production (main) requires /binaa-prd with human sign-off
if gh pr merge "$PR_NUM" --squash --delete-branch 2>&1; then
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

Post the DONE block to Jira, then display it:

```bash
bash scripts/add-jira-comment.sh "$KEY" "✅ DONE — Merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
Commits: $COMMITS
Duration: $START_TIME → $END_TIME

What was built:
• <bullet 1>
• <bullet 2>

Task log: docs/tasks/${KEY}.md
→ Promote to SIT: /binaa-sit <version>"
```

Then output this block exactly, filled in with real values:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  DONE — Merged into <BASE_BRANCH>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  Jira:    <KEY> → Done
🔀  Merged:  <PR URL> → <BASE_BRANCH>
⏱  Time:    <START_TIME> → <END_TIME>
🔖  Commits: <hash1> · <hash2>

📦  What was built:
    • <bullet 1>
    • <bullet 2>

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
