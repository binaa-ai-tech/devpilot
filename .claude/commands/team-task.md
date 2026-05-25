# /team-task — Full AI Dev Team Workflow

Task: **$ARGUMENTS**

You are the **Team Lead**. Orchestrate the full dev team through every phase below.
Never skip a phase. Follow `.devpilot/rules.md` throughout.

---

## Step 0 — Load config and skills (before anything else)

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

2. Set `BASE_BRANCH` by running:
   ```bash
   grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//'
   ```

3. Set `IMPL_ENGINE` from `project.config.md → implementation.engine` (`opencode` or `claude`).
4. Set per-agent models from `project.config.md`:
   ```bash
   IMPL_MODEL_FE=$(grep 'model_frontend:'    project.config.md | head -1 | sed 's/.*model_frontend:[[:space:]]*//'    | tr -d '"')
   IMPL_MODEL_BE=$(grep 'model_backend:'     project.config.md | head -1 | sed 's/.*model_backend:[[:space:]]*//'     | tr -d '"')
   IMPL_MODEL_DB=$(grep 'model_db:'          project.config.md | head -1 | sed 's/.*model_db:[[:space:]]*//'          | tr -d '"')
   IMPL_MODEL_INT=$(grep 'model_integration:' project.config.md | head -1 | sed 's/.*model_integration:[[:space:]]*//' | tr -d '"')
   ```

5. Read `.devpilot/skills/get-shit-done.md`
6. Read `.devpilot/skills/architecture-guard.md`
7. Read `.devpilot/skills/self-heal.md`

Set `ACTIVE_AGENTS` = agents where `enabled: true` in project.config.md.

---

## Phase 1 — BA: Autonomous Requirements

**Adopt the Business Analyst persona.** Read `.devpilot/prompts/team/ba-agent.md`.

**Before anything else — ensure the project index is fresh:**
```bash
bash scripts/generate-project-index.sh
```
Read `docs/project-index.md`. Use it to scope all file reading (3-8 files max).

1. Analyze the task: `$ARGUMENTS`
2. Read the existing codebase to understand context — scan relevant files, routes, components, services
3. Write `docs/requirements/<task-slug>.md` using `.devpilot/templates/team/requirements.md`
   - Document all assumptions made (no clarifying questions — follow rules.md)
   - Include user story, acceptance criteria, scope, data/API changes, edge cases
4. Write `docs/domain-models/<task-slug>.md` using `.devpilot/templates/team/domain-model.md`
5. Count the acceptance criteria in the requirements doc. Save this count as `AC_COUNT`.
6. Output a **JIRA DESCRIPTION** block:
   ```
   --- JIRA DESCRIPTION ---
   As a <role>, I want to <goal> so that <benefit>.

   Scope: <frontend / backend / DB / integration>

   Acceptance Criteria:
   1. <AC 1>
   2. <AC 2>
   ...

   Assumptions: <key assumptions>
   --- END JIRA DESCRIPTION ---
   ```
7. Announce: "✅ BA Phase complete. Requirements at `docs/requirements/<slug>.md`. AC count: <AC_COUNT>"

**Do not stop or ask questions.**

---

## Phase 2 — Team Lead: Planning

**Resume Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md`.

1. Read `docs/requirements/<slug>.md`

2. **Determine ticket structure:**
   - **Simple** (AC_COUNT ≤ 5 AND 1-2 agents): ONE Task ticket
   - **Complex** (AC_COUNT > 5 OR 3+ agents): Epic + one child Task per agent

3. **REQUIRED — Create ticket(s) and move to In Progress:**

   **Simple:**
   ```bash
   KEY=$(bash scripts/create-jira-ticket.sh "<summary>" "<user story, first 200 chars>" "Task")
   bash scripts/update-jira-status.sh "$KEY" "In Progress"
   bash scripts/add-jira-comment.sh "$KEY" "[Team Lead | claude-sonnet-4-6] Phase 2 started"
   ```

   **Complex:**
   ```bash
   EPIC_KEY=$(bash scripts/create-jira-epic.sh "<feature name>" "<user story, first 300 chars>")
   bash scripts/update-jira-status.sh "$EPIC_KEY" "In Progress"
   KEY_FE=$(bash scripts/create-jira-epic.sh "[Frontend] <summary>" "<frontend ACs>" "$EPIC_KEY")
   KEY_BE=$(bash scripts/create-jira-epic.sh "[Backend] <summary>" "<backend ACs>" "$EPIC_KEY")
   # add KEY_DB / KEY_INT if those agents run
   bash scripts/update-jira-status.sh "$KEY_FE" "In Progress"
   bash scripts/update-jira-status.sh "$KEY_BE" "In Progress"
   KEY="$EPIC_KEY"
   ```

4. **REQUIRED — Update Jira description with user story:**
   ```bash
   USER_STORY=$(grep -A 20 "## User Story" docs/requirements/<slug>.md | head -20)
   bash scripts/update-jira-description.sh "$KEY" "User Story: $USER_STORY | Task: $ARGUMENTS"
   ```

5. **REQUIRED — Create feature branch:**
   ```bash
   bash scripts/git-flow.sh feature-start <ticket-number> <slug>
   ```

6. Determine scope: frontend? backend? DB? integration?
   Cross-check against `project.config.md → agents`.

7. Write `docs/plans/<slug>.md` using `.devpilot/templates/team/implementation-plan.md`

8. **REQUIRED — Log plan complete:**
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "[Team Lead | claude-sonnet-4-6] Phase 2 complete — plan: docs/plans/<slug>.md | branch: feature/<KEY>-<slug>"
   ```

9. Announce: "✅ Planning Phase complete. Plan at `docs/plans/<slug>.md`"

---

## Phase 3 — Implementation

Read `project.config.md → implementation.engine`.

---

### Engine: `opencode` (default for coding tasks)

Write one implementation brief per agent. Then stop and hand off to the user.

#### Write implementation briefs

For each agent that has work to do, write `docs/implementation/<slug>-<agent>.md`:

```markdown
# Implementation Brief — <Agent> — <slug>

## Task
<original task description>

## Branch
<feature branch name> — already created, check it out first:
git checkout <branch>

## What to build
Read the full plan: docs/plans/<slug>.md
Read the full requirements: docs/requirements/<slug>.md

## Your scope (<Agent> only)
<paste the relevant section from docs/plans/<slug>.md for this agent>

## Acceptance criteria for this agent
<paste the ACs that this agent is responsible for from docs/requirements/<slug>.md>

## Tech stack rules
Read .devpilot/rules.md before writing any code.

## Stack: <Angular / .NET / SQL Server / etc.>
<list the specific tech constraints relevant to this agent>

## Definition of Done
- [ ] All ACs above are met
- [ ] Lint passes
- [ ] Build passes
- [ ] Tests pass (run: <lint/build/test command>)
- [ ] Committed with: <feat|fix>(<slug>): <description>

## Do not
- Write code outside your scope — other agents handle the rest
- Skip any AC
- Commit to main or develop — commit only to <branch>
```

Write a brief for each agent: frontend, backend, db (if needed), integration (if needed).

#### Hand off to user

Output exactly this block:

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

  # DB (if applicable)  (model: <IMPL_MODEL_DB>)
  opencode --model "<IMPL_MODEL_DB>" < docs/implementation/<slug>-db.md

  # Integration (if applicable)  (model: <IMPL_MODEL_INT>)
  opencode --model "<IMPL_MODEL_INT>" < docs/implementation/<slug>-integration.md

Run them one at a time. Wait for each to finish before starting the next.

When ALL are done → run: /ceo resume
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Stop here. Do not proceed to Phase 4 until /ceo resume is run.**

---

### Engine: `claude` (use when opencode is not available)

Use the **Agent tool** to spawn developer agents. Run frontend and backend **in parallel** when both needed.

**Frontend Agent** (if `agents.frontend.enabled: true` AND frontend work identified)

Spawn with `subagent_type: "team-frontend"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<slug>`. Implement all frontend work per the plan. Read `.devpilot/skills/self-heal.md`. Run lint + build + tests. Commit. Report what you built in 3 bullets.

**Backend Agent** (if `agents.backend.enabled: true` AND backend work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<slug>`. Implement all backend work per the plan. Read `.devpilot/skills/self-heal.md`. Run build + tests. Commit. Report what you built in 3 bullets.

**DB Agent** (if `agents.db.enabled: true` AND DB schema/migration work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: DB changes for `[task description]`. Branch: `feature/<KEY>-<slug>`. Implement all migrations per the plan. Run migration tests. Commit.

**Integration Agent** (if `agents.integration.enabled: true` AND integration work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: Integration work for `[task description]`. Branch: `feature/<KEY>-<slug>`. Implement all integration work per the plan. Run tests. Commit.

Wait for all agents to complete.

**If any agent FAILED:**
1. Write `docs/implementation/<slug>-<agent>-brief.md` with full context of remaining work
2. Output the IMPLEMENTATION HANDOFF block above (opencode engine format) with the failed agent
3. Stop — do not proceed to Phase 4

**If all agents SUCCEEDED:**
```bash
bash scripts/add-jira-comment.sh "$KEY" "[Frontend Dev | claude-sonnet-4-6] Phase 3 complete — <summary>"
bash scripts/add-jira-comment.sh "$KEY" "[Backend Dev | claude-sonnet-4-6] Phase 3 complete — <summary>"
```

---

## Phase 4 — QA: Testing

*(Run this phase after /ceo resume confirms implementation is complete)*

Spawn with `subagent_type: "team-qa"`:

> Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<slug>`. Verify every acceptance criterion. Apply mutation-mindset testing. Add missing coverage. Write QA report to `docs/qa/<slug>.md`. Report final verdict (PASS / BLOCKED).

Wait for QA agent to complete before Phase 5.

**REQUIRED — Log QA verdict:**
```bash
# PASS:
bash scripts/add-jira-comment.sh "$KEY" "[QA Engineer | claude-haiku-4-5] Phase 4 complete — PASS. All ACs verified."
# BLOCKED:
bash scripts/add-jira-comment.sh "$KEY" "[QA Engineer | claude-haiku-4-5] Phase 4 BLOCKED. See docs/qa/<slug>.md"
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
5. **REQUIRED — Open PR, merge it, then close ticket (run in order, do not skip):**
   ```bash
   # Step A — Open the PR
   PR_URL=$(gh pr create \
     --base <BASE_BRANCH> \
     --title "<KEY>: <description>" \
     --body "$(cat docs/reviews/<slug>.md)" | tail -1)
   PR_NUM=$(echo "$PR_URL" | grep -oE '[0-9]+$')

   bash scripts/add-jira-comment.sh "$KEY" "[Team Lead | claude-sonnet-4-6] PR opened: $PR_URL targeting <BASE_BRANCH>"

   # Step B — Merge the PR into <BASE_BRANCH>
   gh pr merge "$PR_NUM" --squash --delete-branch

   # Step C — Confirm merge succeeded before closing ticket
   MERGE_STATE=$(gh pr view "$PR_NUM" --json state --jq '.state')
   if [ "$MERGE_STATE" = "MERGED" ]; then
     bash scripts/update-jira-status.sh "$KEY" "Done"
     bash scripts/add-jira-comment.sh "$KEY" "[Team Lead | claude-sonnet-4-6] PR #${PR_NUM} merged into <BASE_BRANCH>. Ticket closed. Feature live on DEV after CI."
   else
     echo "⚠️  Merge failed (branch protection or CI required). Merge manually then run:"
     echo "   bash scripts/update-jira-status.sh $KEY Done"
     echo "   bash scripts/add-jira-comment.sh $KEY 'PR merged into <BASE_BRANCH>. Ticket closed.'"
   fi
   ```

   **Never close the Jira ticket before the PR is merged.**

6. Announce: "✅ Review complete. PR merged into <BASE_BRANCH>. Ticket closed."

---

## Final Report

| Artifact | Path / URL |
|----------|------------|
| Requirements | `docs/requirements/<slug>.md` |
| Domain Model | `docs/domain-models/<slug>.md` |
| Implementation Plan | `docs/plans/<slug>.md` |
| Implementation Briefs | `docs/implementation/<slug>-*.md` |
| QA Report | `docs/qa/<slug>.md` |
| Review Report | `docs/reviews/<slug>.md` |
| Jira Ticket | `<URL>` |
| Pull Request | `<URL>` |

## Next Steps (after PR merges)

1. Test on DEV → `/binaa-sit <version>`
2. SIT passes → `/binaa-uat`
3. UAT approved → `/binaa-prd <version>`
