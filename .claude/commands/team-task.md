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

Use the **Agent tool** to spawn developer agents. Run frontend and backend **in parallel** when both are needed.

### Frontend Agent (if frontend work identified)
Spawn an agent with this prompt (substituting actual paths):

> You are the Frontend Developer on the dev team. Read `.aidev/prompts/team/frontend-agent.md` for your full persona and rules. Task context: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<n>-<slug>`. Implement all frontend work, run lint + build, commit. Report what you built in 3 bullets.

### .NET Backend Agent (if backend work identified)
Spawn an agent with this prompt:

> You are the .NET Backend Developer on the dev team. Read `.aidev/prompts/team/dotnet-agent.md` for your full persona and rules. Task context: `[task description]`. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<n>-<slug>`. Implement all backend work, run build + tests, commit. Report what you built in 3 bullets.

Wait for all implementation agents to complete before Phase 4.

---

## Phase 4 — QA: Testing

Spawn a QA agent with this prompt:

> You are the QA Engineer on the dev team. Read `.aidev/prompts/team/qa-agent.md` for your full persona and rules. Requirements: `docs/requirements/<slug>.md`. Plan: `docs/plans/<slug>.md`. Branch: `feature/<n>-<slug>`. Run tests, add missing test coverage, write QA report to `docs/qa/<slug>.md` using `.aidev/templates/team/qa-report.md`.

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
