# /ceo-run — Execute Saved Plan

Ticket: **$ARGUMENTS**

Execute a plan that was previously saved by `/ceo-plan`. Reads the plan file, creates branch,
implements, runs QA, opens and merges PR.

---

## Step 0 — Load config

Read `project.config.md`. Extract engine, models, and active agents.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
KEY="$ARGUMENTS"   # e.g. MSK-22

BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')

IMPL_ENGINE=$(grep -A 10 '^engines:' project.config.md | grep '^\s*coding:' | head -1 | sed 's/.*coding:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
[ -z "$IMPL_ENGINE" ] && IMPL_ENGINE="claude"

# Load per-agent models from the active engine's section in coding_models:
_model() {
  grep -A 20 "^  ${IMPL_ENGINE}:" project.config.md 2>/dev/null \
    | grep "    ${1}:" | head -1 \
    | sed "s/.*${1}:[[:space:]]*//" | tr -d '"' | awk '{print $1}'
}
IMPL_MODEL_FE=$(_model frontend)
IMPL_MODEL_BE=$(_model backend)
IMPL_MODEL_DB=$(_model db)
IMPL_MODEL_INT=$(_model integration)
```

Also load and validate the checkpoint if one exists for KEY:
```bash
CHECKPOINT="docs/tasks/${KEY}-checkpoint.json"
if [ -f "$CHECKPOINT" ]; then
  echo "🔍 Loading and validating checkpoint state via scripts/checkpoint.sh..."
  
  # Validate and extract slug with safety fallback
  if ! SLUG=$(bash scripts/checkpoint.sh read "$KEY" "slug" 2>/dev/null) || [ -z "$SLUG" ]; then
    echo "⚠️  WARNING: Checkpoint state is corrupted or missing schema keys! Attempting recovery from plan..."
    PLAN_FILE="docs/tasks/${KEY}-plan.md"
    if [ -f "$PLAN_FILE" ]; then
      SLUG=$(grep -E '^slug:[[:space:]]*' "$PLAN_FILE" | head -1 | sed 's/slug:[[:space:]]*//' | tr -d '"'\'' ' || echo "")
    fi
    if [ -z "$SLUG" ]; then
      echo "❌ CRITICAL: State recovery failed. Could not load valid SLUG."
      exit 1
    fi
    BRANCH=""
    PHASE_COMPLETED=""
    NEXT_PHASE=""
    echo "♻️ Recovered SLUG from plan file: $SLUG"
  else
    BRANCH=$(bash scripts/checkpoint.sh read "$KEY" "branch" 2>/dev/null || echo "")
    PHASE_COMPLETED=$(bash scripts/checkpoint.sh read "$KEY" "phase_completed" 2>/dev/null || echo "")
    NEXT_PHASE=$(bash scripts/checkpoint.sh read "$KEY" "next_phase" 2>/dev/null || echo "")
    echo "✅ Checkpoint successfully validated: phase_completed=$PHASE_COMPLETED, next=$NEXT_PHASE"
  fi
fi
```

---

## Step 1 — Load saved plan

```bash
PLAN_FILE="docs/tasks/${KEY}-plan.md"
if [ ! -f "$PLAN_FILE" ]; then
  echo "❌ Plan file not found: $PLAN_FILE"
  echo "   Run /ceo-plan first, or check the KEY is correct."
  exit 1
fi
```

Read `docs/tasks/${KEY}-plan.md` — extract:
- `slug` → set `SLUG`
- `base_branch` (use project.config.md value as override)
- Scope (frontend / backend / DB / integration)
- AC count

Also read:
- `docs/requirements/<SLUG>.md`
- `docs/domain-models/<SLUG>.md`

---

## Step 2 — Move Jira ticket to In Progress + log start

```bash
bash scripts/update-jira-status.sh "$KEY" "In Progress"
bash scripts/add-jira-comment.sh "$KEY" "▶ Execution started [$START_TIME]
Command: /ceo-run $KEY
Engine: $IMPL_ENGINE
Plan file: $PLAN_FILE"
```

---

## Step 3 — Team Lead: Create branch + implementation plan

**Adopt Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md`.

1. Create feature branch:
   ```bash
   TICKET_NUM=$(echo "$KEY" | grep -oE '[0-9]+')
   bash scripts/git-flow.sh feature-start "$TICKET_NUM" "$SLUG"
   BRANCH=$(git branch --show-current)
   ```

2. Write `docs/plans/<SLUG>.md` using `.devpilot/templates/team/implementation-plan.md`
   - Base this on `docs/requirements/<SLUG>.md` — do not re-analyze from scratch
   - Determine which agents have work (frontend / backend / DB / integration)

3. Log to Jira:
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "📋 Plan complete [$( date '+%Y-%m-%d %H:%M:%S')]
Branch: $BRANCH
Plan: docs/plans/<SLUG>.md"
   ```

---

## Step 4 — Implementation

Use `IMPL_ENGINE` from Step 0 (already loaded from `project.config.md → engines.coding`).

### Engine: `claude`

Spawn agents in parallel for all scoped work. Use the same agent prompts as `/team-task` Phase 3:

- **Frontend** → `subagent_type: "team-frontend"` if frontend work exists
- **Backend** → `subagent_type: "team-dotnet"` if backend work exists
- **DB** → `subagent_type: "team-dotnet"` if DB/migration work exists
- **Integration** → `subagent_type: "team-dotnet"` if integration work exists

Each agent prompt:
> Task: `<task description>`. Requirements: `docs/requirements/<SLUG>.md`. Plan: `docs/plans/<SLUG>.md`. Branch: `<BRANCH>`. Implement all <scope> work per the plan. Read `.devpilot/skills/self-heal.md`. Run build + tests. Commit with conventional commit message. Report what you built in 3 bullets.

Wait for all agents. Then:
```bash
bash scripts/add-jira-comment.sh "$KEY" "⚙️ Implementation complete [$( date '+%Y-%m-%d %H:%M:%S')]
Commits: $(git log ${BASE_BRANCH}..HEAD --oneline | awk '{print $1}' | head -10 | tr '\n' ' ')"
```

### Engine: `opencode`

Write implementation briefs at `docs/implementation/<SLUG>-<agent>.md` (see team-task.md for format).
Output IMPLEMENTATION HANDOFF block and stop. Wait for `/ceo resume`.

---

## Step 5 — QA

Spawn with `subagent_type: "team-qa"`:

> Requirements: `docs/requirements/<SLUG>.md`. Plan: `docs/plans/<SLUG>.md`. Branch: `<BRANCH>`. Verify every acceptance criterion. Write QA report to `docs/qa/<SLUG>.md`. Verdict: PASS or BLOCKED.

```bash
QA_VERDICT="PASS"  # or BLOCKED
bash scripts/add-jira-comment.sh "$KEY" "✅ QA $QA_VERDICT [$( date '+%Y-%m-%d %H:%M:%S')] — docs/qa/<SLUG>.md"
```

If BLOCKED: fix and re-run QA.

---

## Step 6 — Review & PR

1. Write `docs/reviews/<SLUG>.md`
2. Commit docs:
   ```bash
   git add docs/
   git commit -m "docs(<SLUG>): add plan, qa, and review docs"
   ```
3. Create PR + auto-merge into develop:
   ```bash
   PR_URL=$(gh pr create \
     --base "$BASE_BRANCH" \
     --title "$KEY: <description>" \
     --body "$(cat docs/reviews/<SLUG>.md)" | tail -1)
   PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

   # Auto-merge into develop — production (main) requires /binaa-prd with human sign-off
   if gh pr merge "$PR_NUM" --squash 2>&1; then
     bash scripts/update-jira-status.sh "$KEY" "Done"
   else
     bash scripts/update-jira-status.sh "$KEY" "In Review"
     echo "⚠️  Auto-merge failed — merge $PR_URL manually, then: bash scripts/update-jira-status.sh $KEY Done"
   fi
   ```
4. Capture final state:
   ```bash
   END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    COMMIT_HASHES=$(git log ${BASE_BRANCH}..HEAD --oneline 2>/dev/null | awk '{print $1}' | head -10 | tr '\n' ' ')
   ```
5. Final Jira comment:
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "✅ Merged into $BASE_BRANCH [$END_TIME]
PR: $PR_URL
QA: PASS · Commits: $COMMIT_HASHES
Duration: $START_TIME → $END_TIME
→ Promote: /binaa-sit <version>"
   ```
6. Update plan file status:
   ```bash
   sed -i.bak 's/status: planned/status: done/' "docs/tasks/${KEY}-plan.md" && rm -f "docs/tasks/${KEY}-plan.md.bak"
   cat >> "docs/tasks/${KEY}-plan.md" << EOF

   ## Result (merged: $END_TIME)
   - PR: $PR_URL (merged into $BASE_BRANCH)
   - Jira: $KEY → Done
   - Commits: $COMMIT_HASHES
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
🔖  Commits: <hash1> · <hash2> · <hash3>

📦  What was built:
    • <bullet 1>
    • <bullet 2>
    • <bullet 3>

🔗  DEV deploys automatically from <BASE_BRANCH> after CI passes
📁  Task log:  docs/tasks/<KEY>-plan.md
──────────────────────────────────────────────────────
🚀  Promote to production when ready:
    1. DEV ready?        → /binaa-sit <version>
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
         ↑ Production PR opens here — requires your review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
