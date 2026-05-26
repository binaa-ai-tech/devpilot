# /ceo-int — Integration Agent Only

Task: **$ARGUMENTS**

Skip planning. Spawn the integration agent directly for messaging, external services,
APIs, or infrastructure connections. Jira ticket + branch + code + PR.

---

## Step 0 — Load config

Read `project.config.md`.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
IMPL_ENGINE=$(grep 'engine:' project.config.md | head -1 | sed 's/.*engine:[[:space:]]*//' | tr -d '"')
IMPL_MODEL_INT=$(grep 'model_integration:' project.config.md | head -1 | sed 's/.*model_integration:[[:space:]]*//' | tr -d '"')
```

If `agents.integration.enabled` is false in project.config.md, stop and tell the user.

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
bash scripts/add-jira-comment.sh "$KEY" "🚀 Integration task started [$START_TIME]
Command: /ceo-int \"$ARGUMENTS\"
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
command: /ceo-int
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

> Integration task: `$ARGUMENTS`. Branch: `<BRANCH>`. Implement the integration change (messaging / external service / API connector). Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`. Run build + integration tests if available. Commit with `feat|fix(integration): <description>`. Report: commit hash + what service was integrated + what changed in 3 bullets.

### Engine: `opencode`

Write `docs/implementation/<SLUG>-integration.md` with the task description and integration scope.
Output:
```
⏸  IMPLEMENTATION HANDOFF — opencode (integration)
Branch: <BRANCH>
  opencode --model "<IMPL_MODEL_INT>" < docs/implementation/<SLUG>-integration.md
When done → run: /ceo resume
```
Stop here.

---

## Step 3 — QA

Spawn with `subagent_type: "team-qa"`:

> Integration QA for `$ARGUMENTS`. Branch: `<BRANCH>`. Verify the integration works correctly, external service connectivity is sound, no regressions. Write QA report to `docs/qa/<SLUG>.md`. Verdict: PASS or BLOCKED.

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

PR_URL=$(gh pr create \
  --base "$BASE_BRANCH" \
  --title "$KEY: $ARGUMENTS" \
  --body "Integration change: $ARGUMENTS

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
