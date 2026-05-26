# /ceo-subdomain — CEO Sub-Domain Layer-Locked Fixer (Track 3)

Task: **$ARGUMENTS**

**Track 3 flow:** Bypasses broad planning and locks down the agent's write privileges and execution context exclusively to a single target vertical layer. Generates a single targeted Jira ticket, branches, resolves, and merges.

---

## Step 0 — Load config & Parse Arguments

Read `project.config.md` using the engine-aware parser.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')

# Parse arguments to extract target scope and actual task description
RAW_ARGS="$ARGUMENTS"
SCOPE=$(echo "$RAW_ARGS" | grep -oE '^(frontend|backend|db|security|\\[frontend\\]|\\[backend\\]|\\[db\\]|\\[security\\]|\\[SECURITY\\]|\\[FRONTEND\\]|\\[BACKEND\\]|\\[DB\\])' | tr -d '[]' | tr '[:upper:]' '[:lower:]' | head -1 || echo "")

if [ -z "$SCOPE" ]; then
  # Fallback: check first word
  FIRST_WORD=$(echo "$RAW_ARGS" | awk '{print $1}' | tr -d '[]' | tr '[:upper:]' '[:lower:]')
  if [[ "$FIRST_WORD" =~ ^(frontend|backend|db|security)$ ]]; then
    SCOPE="$FIRST_WORD"
    TASK_DESC=$(echo "$RAW_ARGS" | cut -d' ' -f2-)
  else
    echo "❌ No valid target domain scope specified."
    echo "   Usage: /ceo-subdomain [scope] description..."
    echo "   Allowed scopes: frontend, backend, db, security"
    exit 1
  fi
else
  TASK_DESC=$(echo "$RAW_ARGS" | sed -E 's/^(\[?[a-zA-Z]+\]?)[[:space:]]+//')
fi

# Ensure scope has work enabled in config
if [ "$SCOPE" = "frontend" ] && [ "$(grep -A 10 '^agents:' project.config.md | grep 'frontend:' | grep -o 'true')" != "true" ]; then
  echo "❌ Frontend agent is disabled in project.config.md."
  exit 1
fi
if [ "$SCOPE" = "backend" ] && [ "$(grep -A 10 '^agents:' project.config.md | grep 'backend:' | grep -o 'true')" != "true" ]; then
  echo "❌ Backend agent is disabled in project.config.md."
  exit 1
fi

IMPL_ENGINE=$(grep -A 10 '^engines:' project.config.md | grep '^\s*coding:' | head -1 | sed 's/.*coding:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
[ -z "$IMPL_ENGINE" ] && IMPL_ENGINE="claude"
```

---

## Step 1 — Create Jira ticket & Branch

Create a single targeted ticket for the scope, transition it to In Progress, and start the branch.

```bash
SLUG=$(echo "$TASK_DESC" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed -E 's/-+/-/g' | sed -E 's/^-|-$//g' | cut -d'-' -f1-5)

KEY=$(bash scripts/create-jira-ticket.sh "[${SCOPE^^}] ${TASK_DESC}" "$TASK_DESC" "Task")
bash scripts/update-jira-status.sh "$KEY" "In Progress"

TICKET_NUM=$(echo "$KEY" | grep -oE '[0-9]+')
bash scripts/git-flow.sh feature-start "$TICKET_NUM" "$SLUG"
BRANCH=$(git branch --show-current)
```

Log start:
```bash
bash scripts/add-jira-comment.sh "$KEY" "🚀 Track 3 Layer-Locked task started [$START_TIME]
Command: /ceo-subdomain $RAW_ARGS
Scope: $SCOPE (Layer-Locked)
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
scope: $SCOPE
command: /ceo-subdomain
branch: $BRANCH
base_branch: $BASE_BRANCH
started: $START_TIME
status: in-progress
---
## Task
$TASK_DESC
## Layer-Locked Scope Restrictions
All changes are strictly locked to the $SCOPE vertical layer.
EOF
```

Initialize checkpoint:
```bash
bash scripts/checkpoint.sh write \
  --key "$KEY" \
  --slug "$SLUG" \
  --branch "$BRANCH" \
  --base-branch "$BASE_BRANCH" \
  --command "/ceo-subdomain" \
  --task "$TASK_DESC" \
  --runner "claude" \
  --coding-engine "$IMPL_ENGINE" \
  --phase-completed "triage" \
  --next-phase "implementation" \
  --agents-completed "lead" \
  --agents-remaining "$SCOPE" \
  --pause-reason "none"
```

---

## Step 2 — Layer-Locked Implementation

Spawn the target agent. The agent is **forcefully lock-down restricted** with zero privileges to touch files outside its specific domain scope.

### Scope Locks Definition

| Scope | Allowed Path Write Privileges | Forbidden Path Contexts |
|---|---|---|
| **frontend** | Frontend Angular/React templates, styles, components, packages | Any backend APIs, SQL schemas, migrations, secrets files |
| **backend** | Backend controllers, models, services, configs, unit tests | HTML, CSS, frontend client routers, database migrations |
| **db** | Migrations folders, schema definition files, idempotent SQL scripts | Application business logic, frontend UI templates |
| **security** | Security middlewares, policy configs, secrets managers, package lock files | Feature additions, styling, UI layouts |

### Engine: `claude`

**Frontend** (if SCOPE = `frontend`):
Spawn `subagent_type: "team-frontend"`:
> Task: `$TASK_DESC`. Jira: `<KEY>`. Branch: `<BRANCH>`.
> **VERTICAL-LAYER SCOPE LOCK:**
> - You have write privileges ONLY for frontend UI files, styles, components, and package.json files.
> - **CRITICAL:** You are forbidden from modifying any backend, shared API structures, or database files.
> Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`.
> Run `npm run lint` and `npm run build` or appropriate frontend tests.
> Commit: `feat(frontend): <description>`. Report: commits + modified files.

**Backend** (if SCOPE = `backend`):
Spawn `subagent_type: "team-dotnet"`:
> Task: `$TASK_DESC`. Jira: `<KEY>`. Branch: `<BRANCH>`.
> **VERTICAL-LAYER SCOPE LOCK:**
> - You have write privileges ONLY for backend controllers, models, application configuration, and backend tests.
> - **CRITICAL:** You are forbidden from modifying UI templates, css files, frontend routes, or DB migrations.
> Read `.devpilot/skills/self-heal.md` and `.devpilot/rules.md`.
> Run `dotnet build && dotnet test` or equivalent backend tests.
> Commit: `feat(backend): <description>`. Report: commits + modified files.

**DB** (if SCOPE = `db`):
Spawn `subagent_type: "team-dotnet"`:
> Task: `$TASK_DESC`. Jira: `<KEY>`. Branch: `<BRANCH>`.
> **VERTICAL-LAYER SCOPE LOCK:**
> - You have write privileges ONLY for SQL schemas, migration scripts, and DB configs.
> - **CRITICAL:** You are forbidden from modifying frontend UI or backend API controllers.
> Make migrations idempotent.
> Commit: `feat(db): <description>`. Report: commits + migration files.

**Security** (if SCOPE = `security`):
Spawn `subagent_type: "team-dotnet"`:
> Task: `$TASK_DESC`. Jira: `<KEY>`. Branch: `<BRANCH>`.
> **VERTICAL-LAYER SCOPE LOCK:**
> - You have write privileges ONLY for security middleware, configs, packages, and authorization policies.
> - **CRITICAL:** Do not add business logic or modify layouts. Keep diffs focused strictly on security controls.
> Run security scans if available.
> Commit: `sec(security): <description>`. Report: commits + modified files.

### Engine: `opencode` or `antigravity`

Write the implementation handoff brief to `docs/implementation/${SLUG}-${SCOPE}.md`.
Include the respective vertical-layer scope lock instructions.
Stop and output:
```
⏸  IMPLEMENTATION HANDOFF — $IMPL_ENGINE ($SCOPE)
Branch: $BRANCH
  $IMPL_ENGINE < docs/implementation/$SLUG-$SCOPE.md
When done → run: /ceo resume
```

---

## Step 3 — QA Verification (Layer-Targeted)

Spawn `subagent_type: "team-qa"` with a targeted brief:
> Task: `$TASK_DESC`. Branch: `<BRANCH>`.
> Verify that the vertical change works as expected within the `$SCOPE` layer.
> Confirm that adjacent layers remain untouched and that the Scope Lock was strictly adhered to.
> Write QA report to `docs/qa/<SLUG>.md`. Verdict: PASS or BLOCKED.

```bash
QA_TIME=$(date '+%Y-%m-%d %H:%M:%S')
bash scripts/add-jira-comment.sh "$KEY" "✅ Layer-Locked QA Passed [$QA_TIME] — docs/qa/<SLUG>.md"
```

If BLOCKED: correct the code strictly within the vertical layer and re-run QA.

---

## Step 4 — PR + Auto-merge

```bash
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')

PR_URL=$(gh pr create \
  --base "$BASE_BRANCH" \
  --title "$KEY: [$SCOPE] $TASK_DESC" \
  --body "Track 3 Layer-Locked Fix ($SCOPE): $TASK_DESC

QA: PASS — docs/qa/<SLUG>.md
Commits: $COMMITS" | tail -1)
PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

if gh pr merge "$PR_NUM" --squash 2>&1; then
  bash scripts/update-jira-status.sh "$KEY" "Done"
  bash scripts/add-jira-comment.sh "$KEY" "✅ Layer-Locked PR merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
Commits: $COMMITS"
else
  bash scripts/update-jira-status.sh "$KEY" "In Review"
  echo "⚠️ Auto-merge failed. Merge manually."
fi

bash scripts/checkpoint.sh update "$KEY" phase_completed "done"

cat >> "docs/tasks/${KEY}.md" << EOF

## Result (merged: $END_TIME)
- PR: $PR_URL
- Commits: $COMMITS
EOF
```

---

## Final Output — DONE Block

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  DONE — Track 3 Layer-Locked Merge Completed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  Jira:      <KEY> → Done
🔒  Scope Lock: <SCOPE> (Layer-Locked)
🔀  Merged:    <PR URL> → <BASE_BRANCH>
⏱  Time:      <START_TIME> → <END_TIME>
🔖  Commits:   <COMMITS>

📦  What was built:
    • Layer-locked scope constraints successfully verified.
    • Vertical fixes applied exclusively within <SCOPE> layer.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
