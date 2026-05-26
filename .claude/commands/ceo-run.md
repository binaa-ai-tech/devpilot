# /ceo-run — Execute Saved Plan

Ticket: **$ARGUMENTS**

Execute a plan that was previously saved by `/ceo-plan`. Reads the plan file, creates branch,
implements, runs QA, opens and merges PR.

---

## Step 0 — Load config

Read `project.config.md`. Extract `base_branch`, `implementation.engine`, per-agent models, active agents.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
KEY="$ARGUMENTS"   # e.g. MSK-22
BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
IMPL_ENGINE=$(grep 'engine:' project.config.md | head -1 | sed 's/.*engine:[[:space:]]*//' | tr -d '"')
IMPL_MODEL_BE=$(grep 'model_backend:'     project.config.md | head -1 | sed 's/.*model_backend:[[:space:]]*//'  | tr -d '"')
IMPL_MODEL_FE=$(grep 'model_frontend:'    project.config.md | head -1 | sed 's/.*model_frontend:[[:space:]]*//' | tr -d '"')
IMPL_MODEL_DB=$(grep 'model_db:'          project.config.md | head -1 | sed 's/.*model_db:[[:space:]]*//'       | tr -d '"')
IMPL_MODEL_INT=$(grep 'model_integration:' project.config.md | head -1 | sed 's/.*model_integration:[[:space:]]*//' | tr -d '"')
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

Read `project.config.md → implementation.engine` and follow the matching section.

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
3. Open + merge PR:
   ```bash
   PR_URL=$(gh pr create \
     --base "$BASE_BRANCH" \
     --title "$KEY: <description>" \
     --body "$(cat docs/reviews/<SLUG>.md)" | tail -1)
   PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')
   gh pr merge "$PR_NUM" --squash --delete-branch

   MERGE_STATE=$(gh pr view "$PR_NUM" --json state --jq '.state')
   if [ "$MERGE_STATE" = "MERGED" ]; then
     bash scripts/update-jira-status.sh "$KEY" "Done"
   fi
   ```
4. Capture final state:
   ```bash
   END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
   COMMIT_HASHES=$(git log ${BASE_BRANCH}..HEAD --oneline 2>/dev/null | awk '{print $1}' | head -10 | tr '\n' ' ')
   DEV_URL=$(grep 'DEV_FRONTEND_URL\|dev_url' .devpilot/config.sh 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' || echo "see CI output")
   ```
5. Final Jira comment:
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "🏁 Done [$END_TIME]
PR: $PR_URL (merged into $BASE_BRANCH)
Commits: $COMMIT_HASHES
Duration: $START_TIME → $END_TIME"
   ```
6. Update plan file status:
   ```bash
   sed -i.bak 's/status: planned/status: completed/' "docs/tasks/${KEY}-plan.md" && rm -f "docs/tasks/${KEY}-plan.md.bak"
   cat >> "docs/tasks/${KEY}-plan.md" << EOF

   ## Result
   - Completed: $END_TIME
   - PR: $PR_URL (merged)
   - Commits: $COMMIT_HASHES
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
🔖  Commits: <hash1> · <hash2> · <hash3>

📦  What was built:
    • <bullet 1>
    • <bullet 2>
    • <bullet 3>

🔗  Test on DEV:  <DEV_URL>
    (Live ~5 min after CI passes)

📁  Task log:  docs/tasks/<KEY>-plan.md
──────────────────────────────────────────────────────
🚀  Promote when ready:
    1. DEV looks good?   → /binaa-sit <version>
    2. SIT passed?       → /binaa-uat
    3. UAT approved?     → /binaa-prd <version>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
