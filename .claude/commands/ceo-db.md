# /ceo-db — DB Agent Only

Task: **$ARGUMENTS**

Skip planning. Spawn the DB agent directly for migrations, schema changes, or SQL fixes.
Jira ticket + branch + migration + PR.

---

## Step 0 — Load config

Read `project.config.md`.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//; s/#.*//' | tr -d '"' | awk '{print $1}')

# Resolve engine + model for the DB layer. resolve-engine.sh applies the
# Claude-entry coupling and any layer_overrides — single source of truth.
eval "$(bash scripts/resolve-engine.sh layer db)"
IMPL_ENGINE="$LAYER_ENGINE"; IMPL_MODEL_DB="$LAYER_MODEL"
[ -z "$IMPL_ENGINE" ] && IMPL_ENGINE="claude"
```

If `agents.db.enabled` is false in project.config.md, stop and tell the user.

---

## Step 1 — Derive slug + create Jira ticket + branch

```bash
SLUG="<derived from $ARGUMENTS — lowercase, hyphens, max 5 words>"

# Pre-flight scan — enrich a thin ticket with local signal (read-only, no LLM).
PREFLIGHT=$(bash scripts/preflight-scan.sh "$ARGUMENTS" "$SLUG")

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

Spawn `subagent_type: "team-backend"`:

> DB task: `$ARGUMENTS`. Branch: `<BRANCH>`. Implement the required migration or schema change. Read `.devpilot/skills/core-rules.md` and your database stack snippet in `.devpilot/rules/` (e.g. `sqlserver.md` or `postgres-mysql.md`); read `.devpilot/skills/self-heal.md` if a step fails. Use the project's migration tool. Verify the migration runs without errors. Commit with `feat|fix(db): <description>`. Report: migration name + commit hash + what changed.

### Engine: `opencode`

⚠️ **CRITICAL: Use the Bash tool to run the engine command directly. NEVER output a HANDOFF block. NEVER ask the user to run anything manually.**

Write `docs/implementation/<SLUG>-db.md` with the task description and schema change details.
Then immediately run via Bash tool:
```bash
$IMPL_ENGINE --model "$IMPL_MODEL_DB" < "docs/implementation/${SLUG}-db.md"
```
Proceed to QA when it exits 0.

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

cat > /tmp/devpilot-pr-body-$$.md << EOF
DB change: $ARGUMENTS

QA: PASS — docs/qa/<SLUG>.md
Commits: $COMMITS
EOF

# Auto-merge into develop — production (main) requires /binaa-prd with human sign-off
PR_URL=$(bash scripts/open-pr.sh "$BASE_BRANCH" "$KEY: $ARGUMENTS" /tmp/devpilot-pr-body-$$.md)
if [ $? -eq 0 ]; then
  DEVPILOT_ENGINES="db: $IMPL_ENGINE${IMPL_MODEL_DB:+ ($IMPL_MODEL_DB)}" \
    bash scripts/run-summary.sh "$KEY" "$SLUG" "<what changed>" "QA: PASS" "$BASE_BRANCH" --post
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
• Migration: <migration name>
• Changed: <tables / columns affected>
• QA: PASS

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
