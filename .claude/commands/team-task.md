# /team-task — Full AI Dev Team Workflow

Task: **$ARGUMENTS**

You are the **Team Lead**. Orchestrate the full dev team through every phase below.
Never skip a phase. Follow `.devpilot/rules.md` throughout.

---

## Step 0 — Load config and skills (before anything else)

1. Read `project.config.md` — extract and announce:
   ```
   Project: <project_name>
   Base branch: <base_branch>
   Active agents: <list>
   ```
   **If project_name is missing or this looks like the wrong project, stop and tell the user to open the correct project in Claude Code.**

2. Set `BASE_BRANCH` by running:
   ```bash
   grep 'base_branch' project.config.md | head -1 | sed 's/.*base_branch:[[:space:]]*//'
   ```
   Use the result as BASE_BRANCH throughout. Never default to `main` without reading the config.

3. Read `.devpilot/skills/get-shit-done.md`
4. Read `.devpilot/skills/architecture-guard.md`
5. Read `.devpilot/skills/self-heal.md`

Set `ACTIVE_AGENTS` = agents where `enabled: true` in project.config.md.

---

## Phase 1 — BA: Autonomous Requirements

**Adopt the Business Analyst persona.** Read `.devpilot/prompts/team/ba-agent.md`.

1. Analyze the task: `$ARGUMENTS`
2. Read the existing codebase to understand context — scan relevant files, routes, components, services
3. Write `docs/requirements/<task-slug>.md` using `.devpilot/templates/team/requirements.md`
   - Document all assumptions made (no clarifying questions — follow rules.md)
   - Include user story, acceptance criteria, scope, data/API changes, edge cases
4. Write `docs/domain-models/<task-slug>.md` using `.devpilot/templates/team/domain-model.md`
5. Announce: "✅ BA Phase complete. Requirements at `docs/requirements/<slug>.md`"

**Do not stop or ask questions.** Make reasonable assumptions and document them.
If the task is genuinely ambiguous on a critical decision (e.g. data model change that can't be reversed),
note it as an assumption and pick the safer option.

---

## Phase 2 — Team Lead: Planning

**Resume Team Lead persona.** Read `.devpilot/prompts/team/lead-plan.md`.

1. Read `docs/requirements/<slug>.md`

2. **REQUIRED — Create ticket + transition + comment (run all 3 lines, do not skip any):**
   ```bash
   KEY=$(bash scripts/create-jira-ticket.sh "<summary>" "<slug> — devpilot auto-task" "Story")
   bash scripts/update-jira-status.sh "$KEY" "In Progress"
   bash scripts/add-jira-comment.sh "$KEY" "[Team Lead | claude-sonnet-4-6] Phase 2 started — branch and implementation plan being created"
   ```
   Save the value of `KEY` (e.g. `MSK-42`) — use it in every step below.

3. **REQUIRED — Create feature branch:**
   ```bash
   bash scripts/git-flow.sh feature-start <ticket-number> <slug>
   ```

4. Determine scope from requirements: frontend needed? backend needed? db changes? integration?
   Cross-check against `project.config.md → agents` — only plan for enabled agents.

5. Write `docs/plans/<slug>.md` using `.devpilot/templates/team/implementation-plan.md`

6. **REQUIRED — Log plan complete:**
   ```bash
   bash scripts/add-jira-comment.sh "$KEY" "[Team Lead | claude-sonnet-4-6] Phase 2 complete — plan: docs/plans/<slug>.md | branch: feature/<KEY>-<n>-<slug>"
   ```

7. Announce: "✅ Planning Phase complete. Plan at `docs/plans/<slug>.md`"

---

## Phase 3 — Implementation

Read `project.config.md → models` for each agent's tier1 model.
Use the **Agent tool** to spawn developer agents. Run frontend and backend **in parallel** when both needed.

### Frontend Agent (if `agents.frontend.enabled: true` AND frontend work identified)

Spawn with `subagent_type: "team-frontend"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Implement all frontend work per the plan. Read `.devpilot/skills/self-heal.md` for fallback protocol if limits hit. Run lint + build + tests. Apply security, performance, and DoD checklists. Commit. Report what you built in 3 bullets.

### Backend Agent (if `agents.backend.enabled: true` AND backend work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Implement all backend work per the plan. Read `.devpilot/skills/self-heal.md` for fallback protocol if limits hit. Run build + tests. Apply security, performance, architecture, and DoD checklists. Commit. Report what you built in 3 bullets.

### DB Agent (if `agents.db.enabled: true` AND DB schema/migration work identified)

Spawn with `subagent_type: "team-dotnet"` (reuses .NET agent for SQL work):

> Task: DB changes for `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Implement all database migrations and schema changes per the plan. Follow SQL Server rules in `.devpilot/rules.md`. Read `.devpilot/skills/self-heal.md` for fallback protocol. Run migration tests. Commit. Report what you built in 3 bullets.

### Integration Agent (if `agents.integration.enabled: true` AND integration work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: Integration work for `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Implement all integration/messaging work per the plan. Read `.devpilot/skills/self-heal.md` for fallback protocol. Run tests. Commit. Report what you built in 3 bullets.

**Wait for all implementation agents to complete before Phase 4.**

**REQUIRED — Log each agent that ran (one call per agent):**
```bash
bash scripts/add-jira-comment.sh "$KEY" "[Frontend Dev | <tier1-model>] Phase 3 complete — <one-line summary>"
bash scripts/add-jira-comment.sh "$KEY" "[Backend Dev | <tier1-model>] Phase 3 complete — <one-line summary>"
```

If any agent triggered the opencode fallback: **stop here and wait for `/ceo resume`.**

---

## Phase 4 — QA: Testing

Spawn with `subagent_type: "team-qa"`:

> Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Verify every acceptance criterion. Apply mutation-mindset testing. Add missing coverage. Write QA report to `docs/qa/<slug>.md`. Report final verdict (PASS / BLOCKED).

Wait for QA agent to complete before Phase 5.

**REQUIRED — Log QA verdict:**
```bash
# PASS:
bash scripts/add-jira-comment.sh "$KEY" "[QA Engineer | <tier1-model>] Phase 4 complete — PASS. All acceptance criteria verified."
# BLOCKED:
bash scripts/add-jira-comment.sh "$KEY" "[QA Engineer | <tier1-model>] Phase 4 complete — BLOCKED. See docs/qa/<slug>.md"
```

---

## Phase 5 — Team Lead: Review & PR

**Resume Team Lead persona.** Read `.devpilot/prompts/team/lead-review.md`.

1. Run `git diff <BASE_BRANCH>...HEAD` and review against `.devpilot/rules.md`
2. Check `docs/qa/<slug>.md` — if BLOCKED, resolve before continuing
3. Write `docs/reviews/<slug>.md` using `.devpilot/templates/team/review-report.md`
4. Commit docs:
   ```bash
   git add docs/
   git commit -m "docs(<slug>): add requirements, plan, qa, and review docs"
   ```
5. **REQUIRED — Open PR, close ticket, log completion (run all in order):**
   ```bash
   PR_URL=$(gh pr create \
     --base <BASE_BRANCH> \
     --title "<KEY>: <description>" \
     --body "$(cat docs/reviews/<slug>.md)" | tail -1)
   bash scripts/update-jira-status.sh "$KEY" "Done"
   bash scripts/add-jira-comment.sh "$KEY" "[Team Lead | claude-sonnet-4-6] Phase 5 complete — PR: $PR_URL targeting <BASE_BRANCH>. Ticket closed."
   ```

6. Announce: "✅ Review complete. PR opened."

---

## Final Report

| Artifact | Path / URL |
|----------|------------|
| Requirements | `docs/requirements/<slug>.md` |
| Domain Model | `docs/domain-models/<slug>.md` |
| Implementation Plan | `docs/plans/<slug>.md` |
| QA Report | `docs/qa/<slug>.md` |
| Review Report | `docs/reviews/<slug>.md` |
| Jira Ticket | `<URL>` |
| Pull Request | `<URL>` |

## Next Steps (after PR merges)

CI auto-deploys to DEV. Then:

1. Test on DEV → `/binaa-sit <version>`
   - Features: bump MINOR (`1.0.0 → 1.1.0`) | Fixes: bump PATCH (`1.0.0 → 1.0.1`)
2. SIT passes → `/binaa-uat`
3. UAT approved → `/binaa-prd <version>`
