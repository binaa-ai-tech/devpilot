# /team-task — Full AI Dev Team Workflow

Task: **$ARGUMENTS**

You are the **Team Lead**. Orchestrate the full dev team through every phase below.
Never skip a phase. Follow `.devpilot/rules.md` throughout.

---

## Step 0 — Load config and capture start time

1. Read `project.config.md` — extract and announce:
   ```
   Project:               <project_name>
   Base branch:           <base_branch>
   Implementation engine: <implementation.engine>
   Coding models:
     Frontend:    <implementation.model_frontend>
     Backend:     <implementation.model_backend>
     DB:          <implementation.model_db>
     Integration: <implementation.model_integration>
   Active agents: <list>
   ```
   **If project_name is missing or this looks like the wrong project, stop and tell the user to open the correct project in Claude Code.**

2. Capture start time:
   ```bash
   START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
   ```

3. Set `BASE_BRANCH`:
   ```bash
   BASE_BRANCH=$(grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//')
   ```

4. Set `IMPL_ENGINE` from `project.config.md → implementation.engine`.

5. Set per-agent models:
   ```bash
   IMPL_MODEL_FE=$(grep 'model_frontend:'    project.config.md | head -1 | sed 's/.*model_frontend:[[:space:]]*//'    | tr -d '"')
   IMPL_MODEL_BE=$(grep 'model_backend:'     project.config.md | head -1 | sed 's/.*model_backend:[[:space:]]*//'     | tr -d '"')
   IMPL_MODEL_DB=$(grep 'model_db:'          project.config.md | head -1 | sed 's/.*model_db:[[:space:]]*//'          | tr -d '"')
   IMPL_MODEL_INT=$(grep 'model_integration:' project.config.md | head -1 | sed 's/.*model_integration:[[:space:]]*//' | tr -d '"')
   ```

6. Read `.devpilot/skills/get-shit-done.md`, `.devpilot/skills/architecture-guard.md`, `.devpilot/skills/self-heal.md`

Set `ACTIVE_AGENTS` = agents where `enabled: true` in project.config.md.

---

## Phase 1 — BA: Autonomous Requirements

**Adopt the Business Analyst persona.** Read `.devpilot/prompts/team/ba-agent.md`.

**Ensure the project index is fresh:**
```bash
if find docs/project-index.md -mmin -120 2>/dev/null | grep -q .; then
  echo "Project index is fresh — skipping regeneration"
else
  bash scripts/generate-project-index.sh
fi
```
Read `docs/project-index.md`. Use it to scope all file reading (3-8 files max).

1. Analyze the task: `$ARGUMENTS`
2. Read the existing codebase to understand context — scan relevant files, routes, components, services
3. Write `docs/requirements/<task-slug>.md` using `.devpilot/templates/team/requirements.md`
   - Document all assumptions made (no clarifying questions — follow rules.md)
   - Include user story, acceptance criteria, scope, data/API changes, edge cases
4. Write `docs/domain-models/<task-slug>.md` using `.devpilot/templates/team/domain-model.md`
5. Count the acceptance criteria. Save as `AC_COUNT`.
6. Announce: "✅ BA Phase complete. Requirements at `docs/requirements/<slug>.md`. AC count: <AC_COUNT>"

**Do not stop or ask questions.**

---

## Phase 2 — Team Lead: Planning

**Resume Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md`.

1. Read `docs/requirements/<slug>.md`

2. **Determine ticket structure:**
   - **Simple** (AC_COUNT ≤ 5 AND 1-2 agents): ONE Task ticket
   - **Complex** (AC_COUNT > 5 OR 3+ agents): Epic + one child Task per agent

3. **Create ticket(s) and move to In Progress:**

   **Simple:**
   ```bash
   KEY=$(bash scripts/create-jira-ticket.sh "<summary>" "<user story, first 200 chars>" "Task")
   bash scripts/update-jira-status.sh "$KEY" "In Progress"
   ```

   **Complex:**
   ```bash
   EPIC_KEY=$(bash scripts/create-jira-epic.sh "<feature name>" "<user story, first 300 chars>")
   bash scripts/update-jira-status.sh "$EPIC_KEY" "In Progress"
   KEY_FE=$(bash scripts/create-jira-epic.sh "[Frontend] <summary>" "<frontend ACs>" "$EPIC_KEY")
   KEY_BE=$(bash scripts/create-jira-epic.sh "[Backend] <summary>" "<backend ACs>" "$EPIC_KEY")
   bash scripts/update-jira-status.sh "$KEY_FE" "In Progress"
   bash scripts/update-jira-status.sh "$KEY_BE" "In Progress"
   KEY="$EPIC_KEY"
   ```

4. **Log start to Jira (human-readable):**
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "🚀 Task started
Command: /ceo \"$ARGUMENTS\"
Branch: feature/$(echo $KEY | tr '[:upper:]' '[:lower:]')-<slug>
Started: $START_TIME
Engine: $IMPL_ENGINE
Agents: <list of active agents>"
   ```

5. **Update Jira description:**
   ```bash
   USER_STORY=$(grep -A 20 "## User Story" docs/requirements/<slug>.md | head -20)
   bash scripts/update-jira-description.sh "$KEY" "User Story: $USER_STORY | Task: $ARGUMENTS"
   ```

6. **Create feature branch:**
   ```bash
   bash scripts/git-flow.sh feature-start <ticket-number> <slug>
   BRANCH=$(git branch --show-current)
   ```

7. Determine scope: frontend? backend? DB? integration?
   Cross-check against `project.config.md → agents`.

8. Write `docs/plans/<slug>.md` using `.devpilot/templates/team/implementation-plan.md`

9. **Initialize task log:**
   ```bash
   mkdir -p docs/tasks
   cat > "docs/tasks/${KEY}.md" << EOF
   ---
   key: $KEY
   slug: <slug>
   command: /ceo
   branch: $BRANCH
   base_branch: $BASE_BRANCH
   started: $START_TIME
   status: in-progress
   ---

   ## Task
   $ARGUMENTS

   ## Plan
   docs/plans/<slug>.md

   ## Timeline
   | Time | Phase | Notes |
   |------|-------|-------|
   | $START_TIME | Started | Ticket: $KEY · Branch: $BRANCH |

   ## Commits
   (updated at completion)

   ## Result
   (updated at completion)
   EOF
   ```

10. **Log plan complete to Jira:**
    ```bash
    PLAN_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    bash scripts/add-jira-comment.sh "$KEY" "📋 Plan complete [$PLAN_TIME]
Plan: docs/plans/<slug>.md
Scope: <frontend / backend / DB / integration>
ACs: $AC_COUNT"
    ```

11. Announce: "✅ Planning Phase complete. Plan at `docs/plans/<slug>.md`"

---

## Phase 3 — Implementation

Read `project.config.md → implementation.engine`.

---

### Engine: `claude`

Use the **Agent tool** to spawn developer agents. Run frontend and backend **in parallel** when both needed.

**Frontend Agent** (if `agents.frontend.enabled: true` AND frontend work identified)

Spawn with `subagent_type: "team-frontend"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `<branch>`. Implement all frontend work per the plan. Read `.devpilot/skills/self-heal.md`. Run lint + build + tests. Commit with conventional commit message. Report what you built in 3 bullets.

**Backend Agent** (if `agents.backend.enabled: true` AND backend work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `<branch>`. Implement all backend work per the plan. Read `.devpilot/skills/self-heal.md`. Run build + tests. Commit with conventional commit message. Report what you built in 3 bullets.

**DB Agent** (if `agents.db.enabled: true` AND DB schema/migration work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: DB changes for `[task description]`. Branch: `<branch>`. Implement all migrations per the plan. Run migration tests. Commit.

**Integration Agent** (if `agents.integration.enabled: true` AND integration work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: Integration work for `[task description]`. Branch: `<branch>`. Implement all integration work per the plan. Run tests. Commit.

Wait for all agents to complete.

**After implementation:**
```bash
IMPL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline 2>/dev/null | awk '{print $1}' | head -10 | tr '\n' ' ')
bash scripts/add-jira-comment.sh "$KEY" "⚙️ Implementation complete [$IMPL_TIME]
Commits: $COMMITS
Agents: <list of agents that ran>"
```

**If any agent FAILED:**
1. Write `docs/implementation/<slug>-<agent>-brief.md` with full context of remaining work
2. Output the opencode HANDOFF block (see engine: opencode section below) for the failed agent
3. Stop — do not proceed to Phase 4

---

### Engine: `opencode`

Write one implementation brief per agent at `docs/implementation/<slug>-<agent>.md`:

```markdown
# Implementation Brief — <Agent> — <slug>

## Task
<original task description>

## Branch
<feature branch> — already created, check it out first:
git checkout <branch>

## What to build
Read the full plan: docs/plans/<slug>.md
Read the full requirements: docs/requirements/<slug>.md

## Your scope (<Agent> only)
<paste the relevant section from the plan for this agent>

## Acceptance criteria for this agent
<paste the ACs this agent owns>

## Tech stack rules
Read .devpilot/rules.md before writing any code.

## Definition of Done
- [ ] All ACs above are met
- [ ] Lint passes
- [ ] Build passes
- [ ] Tests pass
- [ ] Committed with: <feat|fix>(<slug>): <description>
```

Then output exactly:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏸  IMPLEMENTATION HANDOFF — opencode
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Branch: <feature branch>

Run each command below in your terminal:

  # Frontend  (model: <IMPL_MODEL_FE>)
  opencode --model "<IMPL_MODEL_FE>" < docs/implementation/<slug>-frontend.md

  # Backend   (model: <IMPL_MODEL_BE>)
  opencode --model "<IMPL_MODEL_BE>" < docs/implementation/<slug>-backend.md

  # DB (if applicable)
  opencode --model "<IMPL_MODEL_DB>" < docs/implementation/<slug>-db.md

  # Integration (if applicable)
  opencode --model "<IMPL_MODEL_INT>" < docs/implementation/<slug>-integration.md

Run them one at a time. Wait for each to finish before starting the next.

When ALL are done → run: /ceo resume
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Stop here. Do not proceed to Phase 4 until /ceo resume is run.**

---

## Phase 4 — QA: Testing

Spawn with `subagent_type: "team-qa"`:

> Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `<branch>`. Verify every acceptance criterion. Apply mutation-mindset testing. Add missing coverage. Write QA report to `docs/qa/<slug>.md`. Report final verdict: PASS or BLOCKED.

Wait for QA agent to complete.

```bash
QA_TIME=$(date '+%Y-%m-%d %H:%M:%S')
# PASS:
bash scripts/add-jira-comment.sh "$KEY" "✅ QA passed [$QA_TIME] — All $AC_COUNT ACs verified. Report: docs/qa/<slug>.md"
# BLOCKED:
bash scripts/add-jira-comment.sh "$KEY" "🚫 QA BLOCKED [$QA_TIME] — See docs/qa/<slug>.md for failures"
```

If BLOCKED: fix the issue (spawn the relevant agent again), then re-run QA.

---

## Phase 5 — Team Lead: Review & PR

**Resume Team Lead persona.** Read `.devpilot/prompts/team/lead-review.md`.

1. Run `git diff <BASE_BRANCH>...HEAD` — review against `.devpilot/rules.md`
2. Check `docs/qa/<slug>.md` — if BLOCKED, resolve before continuing
3. Write `docs/reviews/<slug>.md` using `.devpilot/templates/team/review-report.md`
4. Commit docs:
   ```bash
   git add docs/
   git commit -m "docs(<slug>): add requirements, plan, qa, and review docs"
   ```
5. **Open PR, merge, close ticket:**
   ```bash
   PR_URL=$(gh pr create \
     --base <BASE_BRANCH> \
     --title "<KEY>: <description>" \
     --body "$(cat docs/reviews/<slug>.md)" | tail -1)
   PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

   gh pr merge "$PR_NUM" --squash --delete-branch

   MERGE_STATE=$(gh pr view "$PR_NUM" --json state --jq '.state')
   if [ "$MERGE_STATE" = "MERGED" ]; then
     bash scripts/update-jira-status.sh "$KEY" "Done"
   else
     echo "⚠️  Merge failed — merge manually then run: bash scripts/update-jira-status.sh $KEY Done"
   fi
   ```

6. **Capture final state:**
   ```bash
   END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
   ALL_COMMITS=$(git log ${BASE_BRANCH}..HEAD --oneline 2>/dev/null | head -10)
   COMMIT_HASHES=$(echo "$ALL_COMMITS" | awk '{print $1}' | tr '\n' ' ')
   DEV_URL=$(grep 'DEV_FRONTEND_URL\|dev_url' .devpilot/config.sh 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' || echo "see CI output")
   ```

7. **Log final Jira comment:**
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "🏁 Done [$END_TIME]
PR: $PR_URL (merged into $BASE_BRANCH)
Commits: $COMMIT_HASHES
Started: $START_TIME → Completed: $END_TIME
Docs: requirements · plan · qa · review saved in docs/"
   ```

8. **Finalize task log:**
   ```bash
   cat >> "docs/tasks/${KEY}.md" << EOF

   ## Result (completed: $END_TIME)
   - PR: $PR_URL (merged)
   - Jira: $KEY → Done
   - Commits: $COMMIT_HASHES

   ### What was built
   <3-5 bullet summary of what each agent built>
   EOF
   ```

---

## Final Output — DONE Block

Output this block exactly, filled in with real values:

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

📁  Task log:  docs/tasks/<KEY>.md
──────────────────────────────────────────────────────
🚀  Promote when ready:
    1. DEV looks good?
       Run: /binaa-sit <version>
       Tip: git tag --sort=-version:refname | head -1
            → features: bump MINOR (1.0.0 → 1.1.0)
            → bug fixes: bump PATCH (1.0.0 → 1.0.1)
    2. SIT passed QA?
       Run: /binaa-uat
    3. UAT signed off?
       Run: /binaa-prd <version>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
