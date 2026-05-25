# /team-task — Full AI Dev Team Workflow

Task: **$ARGUMENTS**

You are the **Team Lead**. Orchestrate the full dev team through every phase below.
Never skip a phase. Follow `.aidev/rules.md` throughout.

---

## Step 0 — Load config and skills (before anything else)

1. Read `project.config.md` — note: base_branch, active agents, model routing
2. Read `.aidev/skills/get-shit-done.md`
3. Read `.aidev/skills/architecture-guard.md`
4. Read `.aidev/skills/self-heal.md`

Set `BASE_BRANCH` = value of `base_branch` from project.config.md (default: `main`).
Set `ACTIVE_AGENTS` = agents where `enabled: true`.

---

## Phase 1 — BA: Autonomous Requirements

**Adopt the Business Analyst persona.** Read `.aidev/prompts/team/ba-agent.md`.

1. Analyze the task: `$ARGUMENTS`
2. Read the existing codebase to understand context — scan relevant files, routes, components, services
3. Write `docs/requirements/<task-slug>.md` using `.aidev/templates/team/requirements.md`
   - Document all assumptions made (no clarifying questions — follow rules.md)
   - Include user story, acceptance criteria, scope, data/API changes, edge cases
4. Write `docs/domain-models/<task-slug>.md` using `.aidev/templates/team/domain-model.md`
5. Announce: "✅ BA Phase complete. Requirements at `docs/requirements/<slug>.md`"

**Do not stop or ask questions.** Make reasonable assumptions and document them.
If the task is genuinely ambiguous on a critical decision (e.g. data model change that can't be reversed),
note it as an assumption and pick the safer option.

---

## Phase 2 — Team Lead: Planning

**Resume Team Lead persona.** Read `.aidev/prompts/team/lead-plan.md`.

1. Read `docs/requirements/<slug>.md`
2. Create Jira ticket:
   ```bash
   ./scripts/create-jira-ticket.sh "<summary>" "<description>" "Story"
   ```
3. Note the ticket key (e.g. `KEY-42`)
4. Create feature branch:
   ```bash
   bash scripts/git-flow.sh feature-start <ticket-number> <slug>
   ```
5. Determine scope from requirements: frontend needed? backend needed? db changes? integration?
   Cross-check against `project.config.md → agents` — only plan for enabled agents.
6. Write `docs/plans/<slug>.md` using `.aidev/templates/team/implementation-plan.md`
7. Announce: "✅ Planning Phase complete. Plan at `docs/plans/<slug>.md`"

---

## Phase 3 — Implementation

Read `project.config.md → models` for each agent's tier1 model.
Use the **Agent tool** to spawn developer agents. Run frontend and backend **in parallel** when both needed.

### Frontend Agent (if `agents.frontend.enabled: true` AND frontend work identified)

Spawn with `subagent_type: "team-frontend"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Implement all frontend work per the plan. Read `.aidev/skills/self-heal.md` for fallback protocol if limits hit. Run lint + build + tests. Apply security, performance, and DoD checklists. Commit. Report what you built in 3 bullets.

### Backend Agent (if `agents.backend.enabled: true` AND backend work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Implement all backend work per the plan. Read `.aidev/skills/self-heal.md` for fallback protocol if limits hit. Run build + tests. Apply security, performance, architecture, and DoD checklists. Commit. Report what you built in 3 bullets.

### DB Agent (if `agents.db.enabled: true` AND DB schema/migration work identified)

Spawn with `subagent_type: "team-dotnet"` (reuses .NET agent for SQL work):

> Task: DB changes for `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Implement all database migrations and schema changes per the plan. Follow SQL Server rules in `.aidev/rules.md`. Read `.aidev/skills/self-heal.md` for fallback protocol. Run migration tests. Commit. Report what you built in 3 bullets.

### Integration Agent (if `agents.integration.enabled: true` AND integration work identified)

Spawn with `subagent_type: "team-dotnet"`:

> Task: Integration work for `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Implement all integration/messaging work per the plan. Read `.aidev/skills/self-heal.md` for fallback protocol. Run tests. Commit. Report what you built in 3 bullets.

**Wait for all implementation agents to complete (or fall back to opencode) before Phase 4.**

If any agent triggered the opencode fallback: **stop here and wait for `/ceo resume`.**

---

## Phase 4 — QA: Testing

Spawn with `subagent_type: "team-qa"`:

> Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<KEY>-<n>-<slug>`. Verify every acceptance criterion. Apply mutation-mindset testing. Add missing coverage. Write QA report to `docs/qa/<slug>.md`. Report final verdict (PASS / BLOCKED).

Wait for QA agent to complete before Phase 5.

---

## Phase 5 — Team Lead: Review & PR

**Resume Team Lead persona.** Read `.aidev/prompts/team/lead-review.md`.

1. Run `git diff <BASE_BRANCH>...HEAD` and review against `.aidev/rules.md`
2. Check `docs/qa/<slug>.md` — if BLOCKED, resolve before continuing
3. Write `docs/reviews/<slug>.md` using `.aidev/templates/team/review-report.md`
4. Commit docs:
   ```bash
   git add docs/
   git commit -m "docs(<slug>): add requirements, plan, qa, and review docs"
   ```
5. Open PR:
   ```bash
   gh pr create \
     --base <BASE_BRANCH> \
     --title "<KEY>: <description>" \
     --body "$(cat docs/reviews/<slug>.md)"
   gh pr merge --auto --squash --delete-branch
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
