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

Spawn `subagent_type: "team-backend"`:

> Integration task: `$ARGUMENTS`. Branch: `<BRANCH>`. Implement the integration change (messaging / external service / API connector). Read `.devpilot/skills/core-rules.md` and your backend stack snippet in `.devpilot/rules/`; read `.devpilot/skills/self-heal.md` if a step fails. Run build + integration tests if available. Commit with `feat|fix(integration): <description>`. Report: commit hash + what service was integrated + what changed in 3 bullets.

### Engine: `opencode`

⚠️ **CRITICAL: Use the Bash tool to run the engine command directly. NEVER output a HANDOFF block. NEVER ask the user to run anything manually.**

Write `docs/implementation/<SLUG>-integration.md` with the task description and integration scope.
Then immediately run via Bash tool:
```bash
$IMPL_ENGINE --model "$IMPL_MODEL_INT" < "docs/implementation/${SLUG}-integration.md"
```
Proceed to QA when it exits 0.

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

## Step 4 — Create PR + auto-merge into develop

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')

cat > /tmp/devpilot-pr-body.md << EOF
Integration change: $ARGUMENTS

QA: PASS — docs/qa/<SLUG>.md
Commits: $COMMITS
EOF

# Auto-merge into develop — production (main) requires /binaa-prd with human sign-off
PR_URL=$(bash scripts/open-pr.sh "$BASE_BRANCH" "$KEY: $ARGUMENTS" /tmp/devpilot-pr-body.md)
if [ $? -eq 0 ]; then
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
