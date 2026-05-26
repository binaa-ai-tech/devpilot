# /ceo-plan — BA Analysis Only (no code)

Task: **$ARGUMENTS**

Analyze the task, write full requirements, create a Jira ticket with the plan.
No code is written. No branch is created. Run `/ceo-run <KEY>` when ready to execute.

---

## Step 0 — Load config

Read `project.config.md`. Extract:
- `project_name`, `ticket_prefix`, `base_branch`
- Active agents

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
```

---

## Step 1 — Generate task slug

Derive `SLUG` from `$ARGUMENTS`:
- lowercase, hyphens only, max 6 words
- Example: "add PDF export for reports" → `add-pdf-export-reports`

---

## Step 2 — Refresh project index if stale

```bash
if find docs/project-index.md -mmin -120 2>/dev/null | grep -q .; then
  echo "Project index is fresh — skipping regeneration"
else
  bash scripts/generate-project-index.sh
fi
```

Read `docs/project-index.md`. Use it to scope codebase reading (3-8 files max).

---

## Step 3 — BA: Write requirements

**Adopt the Business Analyst persona.** Read `.devpilot/prompts/team/ba-agent.md`.

1. Analyze the task: `$ARGUMENTS`
2. Read relevant source files identified from the project index
3. Write `docs/requirements/<SLUG>.md` using `.devpilot/templates/team/requirements.md`
   - User story, acceptance criteria, scope, data/API changes, edge cases
   - All assumptions documented — no clarifying questions
4. Write `docs/domain-models/<SLUG>.md` using `.devpilot/templates/team/domain-model.md`
5. Count ACs → save as `AC_COUNT`
6. Determine scope: frontend / backend / DB / integration

---

## Step 4 — Create Jira ticket (To Do — not started yet)

```bash
SUMMARY="<one-line summary of the task>"
USER_STORY=$(grep -A 5 "## User Story" docs/requirements/<SLUG>.md | head -5)

KEY=$(bash scripts/create-jira-ticket.sh "$SUMMARY" "$USER_STORY" "Task")
bash scripts/update-jira-description.sh "$KEY" "$(cat docs/requirements/<SLUG>.md | head -80)"
```

Do **not** move to In Progress — ticket stays in To Do until `/ceo-run` executes it.

Log to Jira:
```bash
bash scripts/add-jira-comment.sh "$KEY" "📋 Plan saved [$START_TIME]
Command: /ceo-plan \"$ARGUMENTS\"
Requirements: docs/requirements/<SLUG>.md
Domain model: docs/domain-models/<SLUG>.md
AC count: $AC_COUNT
Scope: <frontend / backend / DB / integration>
▶ Ready to execute: /ceo-run $KEY"
```

---

## Step 5 — Save plan file for ceo-run

```bash
mkdir -p docs/tasks
cat > "docs/tasks/${KEY}-plan.md" << EOF
---
key: $KEY
slug: <SLUG>
command: /ceo-plan
base_branch: $BASE_BRANCH
planned: $START_TIME
status: planned
---

## Task
$ARGUMENTS

## Requirements
docs/requirements/<SLUG>.md

## Domain Model
docs/domain-models/<SLUG>.md

## Acceptance Criteria Count
$AC_COUNT

## Scope
<frontend / backend / DB / integration>

## To execute
/ceo-run $KEY
EOF
```

---

## Final Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  PLAN SAVED — Ready for execution
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌  Jira:         <KEY> (To Do)
📄  Requirements: docs/requirements/<SLUG>.md
🗂  Domain model: docs/domain-models/<SLUG>.md
✅  ACs:          <AC_COUNT>
📁  Plan file:    docs/tasks/<KEY>-plan.md

👀  Review the plan, then execute when ready:
    /ceo-run <KEY>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
