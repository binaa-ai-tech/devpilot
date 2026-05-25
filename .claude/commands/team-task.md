# /team-task — Full AI Dev Team Workflow

Task: **$ARGUMENTS**

You are the **Team Lead**. Orchestrate the full dev team through every phase below.
Never skip a phase. Follow `.aidev/rules.md` throughout.

---

## Phase 1 — BA: Requirements Gathering

**Adopt the Business Analyst persona.** Read `.aidev/prompts/team/ba-agent.md`.

1. Analyze the task: `$ARGUMENTS`
2. Identify what is unclear or missing
3. Ask the user **5–8 focused clarifying questions** in a numbered list — cover: user story, acceptance criteria, scope (frontend/backend/both), data/API changes, edge cases, design mockups, constraints
4. **⏸ STOP — wait for the user's answers before proceeding to Phase 2**

After receiving answers:
5. Write `docs/requirements/<task-slug>.md` using `.aidev/templates/team/requirements.md`
6. Announce: "✅ BA Phase complete. Requirements saved to `docs/requirements/<slug>.md`"

---

## Phase 2 — Team Lead: Planning

**Resume Team Lead persona.** Read `.aidev/prompts/team/lead-plan.md`.

1. Read the requirements doc written in Phase 1
2. Create Jira ticket:
   ```bash
   ./scripts/create-jira-ticket.sh "<summary>" "<description>" "Story"
   ```
3. Note the ticket key (e.g. `MSK-42`)
4. Create feature branch:
   ```bash
   bash scripts/git-flow.sh feature-start <ticket-number> <slug>
   ```
5. Determine scope: frontend work needed? backend (.NET) work needed? both?
6. Write `docs/plans/<slug>.md` using `.aidev/templates/team/implementation-plan.md`
7. Announce: "✅ Planning Phase complete. Plan at `docs/plans/<slug>.md`"

---

## Phase 3 — Implementation

Use the **Agent tool** to spawn developer agents with `subagent_type` so the correct model is used automatically (see `.aidev/config/models.md`). Run frontend and backend **in parallel** when both are needed.

### Frontend Agent (if frontend work identified)
Spawn with `subagent_type: "team-frontend"` (runs on **Sonnet 4.6**):

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<n>-<slug>`. Implement all frontend work per the plan. Run lint + build + tests. Apply security, performance, and DoD checklists. Commit. Report what you built in 3 bullets.

### .NET Backend Agent (if backend work identified)
Spawn with `subagent_type: "team-dotnet"` (runs on **Sonnet 4.6**):

> Task: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<n>-<slug>`. Implement all backend work per the plan. Run build + tests. Apply security, performance, architecture, and DoD checklists. Commit. Report what you built in 3 bullets.

Wait for all implementation agents to complete before Phase 4.

---

## Phase 4 — QA: Testing

Spawn with `subagent_type: "team-qa"` (runs on **Haiku 4.5**):

> Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<n>-<slug>`. Verify every acceptance criterion. Apply mutation-mindset testing. Add missing coverage. Write QA report to `docs/qa/<slug>.md`. Report final verdict (PASS / BLOCKED).

Wait for QA agent to complete before Phase 5.

---

## Phase 5 — Team Lead: Review & PR

**Resume Team Lead persona.** Read `.aidev/prompts/team/lead-review.md`.

1. Run `git diff develop...HEAD` and review against `.aidev/rules.md`
2. Check `docs/qa/<slug>.md` for blockers — resolve any before continuing
3. Write `docs/reviews/<slug>.md` using `.aidev/templates/team/review-report.md`
4. Commit docs:
   ```bash
   git add docs/
   git commit -m "docs(<slug>): add requirements, plan, qa, and review docs"
   ```
5. Open PR:
   ```bash
   gh pr create \
     --base develop \
     --title "<KEY>: <description>" \
     --body "$(cat docs/reviews/<slug>.md)"
   gh pr merge --auto --squash --delete-branch
   ```
6. Announce: "✅ Review complete. PR opened."

---

## Final Report

| Artifact | Path / URL |
|----------|-----------|
| Requirements | `docs/requirements/<slug>.md` |
| Implementation Plan | `docs/plans/<slug>.md` |
| QA Report | `docs/qa/<slug>.md` |
| Review Report | `docs/reviews/<slug>.md` |
| Jira Ticket | `<URL>` |
| Pull Request | `<URL>` |
