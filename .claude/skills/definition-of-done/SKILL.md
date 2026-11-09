---
name: definition-of-done
description: "Per-role exit gate every phase must pass before handoff."
when_to_use: "Before handing work to the next phase."
user-invocable: false
---
# Definition of Done — the exit gate every phase must pass

Every agent MUST pass ALL applicable items before handing off to the next phase.
A handoff with a failing DoD item is a defect.

---

## Universal DoD (all agents)

### Code quality
- [ ] Code compiles with zero errors
- [ ] Zero lint errors (warnings noted but don't block)
- [ ] All pre-existing tests still pass — zero regressions introduced
- [ ] No `any` types introduced
- [ ] No hardcoded secrets or credentials

### Security (always run `security-scan`)
- [ ] Security scan checklist completed
- [ ] Zero 🔴 CRITICAL security issues

---

## Bug DoD (any agent fixing a `bug`/`issue` ticket)

Applies on top of the layer DoD. A bug is not "done" because the symptom disappeared:
- [ ] A test was written that **reproduces** the bug and **fails on the unfixed code** (red first)
- [ ] After the fix that test **passes**, and it is committed as a **regression test** (stays in the suite)
- [ ] The **root cause** is addressed, not just the symptom — noted in one line on the ticket
- [ ] Severity-appropriate path was honored (P0/P1 → `/dp-hotfix`; P2/P3 → active/next sprint)
- [ ] No new regressions — full pre-existing suite still green

---

## Frontend DoD (Frontend Developer)

All universal items, plus:
- [ ] `ng lint` passes
- [ ] `ng build --configuration=production` passes
- [ ] `bash scripts/run-tests.sh angular` passes (Vitest)
- [ ] All new components use `ChangeDetectionStrategy.OnPush` + signal inputs/outputs
- [ ] Specs per `angular-testing`: render, interaction, loading/empty/error states
- [ ] `data-testid` / accessible names on elements a UI journey will touch
- [ ] WCAG 2.1 AA checklist reviewed (see `accessibility`)
- [ ] API calls go through the generated client when an OpenAPI contract exists (`api-contract`)
- [ ] Performance checklist completed (from `performance`)
- [ ] Self-heal protocol applied on any failures (from `self-heal`)

---

## Backend DoD (.NET Developer)

All universal items, plus:
- [ ] `dotnet build` passes with zero warnings on new code
- [ ] `bash scripts/run-tests.sh dotnet` passes with zero failures
- [ ] All new service methods have unit tests
- [ ] All new API endpoints have integration tests on real SQL Server (`dotnet-testing`)
- [ ] Endpoints follow `dotnet-api`: DTOs, validation, auth + ownership, ProblemDetails
- [ ] OpenAPI spec regenerated + committed; no unversioned breaking change (`api-contract`)
- [ ] Migrations additive, reversible, idempotent script reviewed (`efcore-sqlserver`)
- [ ] Performance checklist completed (from `performance`)
- [ ] Architecture guardrails checked (from `architecture-guard`)
- [ ] Self-heal protocol applied on any failures (from `self-heal`)

---

## QA DoD (QA Engineer)

All universal items, plus:
- [ ] Every acceptance criterion has at least one dedicated test
- [ ] For a **bug** ticket: a regression test exists that fails on the pre-fix code (apply the Bug DoD)
- [ ] Happy path, at least two edge cases, and at least one error/empty state are covered
- [ ] Mutation-mindset applied: boundary values, null/empty inputs, inverted boolean conditions all tested
- [ ] Every UI-facing AC has a Playwright journey or a written reason it is covered lower (`ui-e2e-playwright`)
- [ ] `bash scripts/run-tests.sh all` green; `bash scripts/test-guard.sh` clean
- [ ] QA report written with explicit ✅ PASS or ❌ BLOCKED verdict
- [ ] No blockers left unresolved

---

## Team Lead DoD (Review)

All universal items, plus:
- [ ] All agent DoDs verified (Frontend, Backend, QA reports reviewed)
- [ ] Architecture guardrails checked across entire diff (from `architecture-guard`)
- [ ] Security scan run across entire diff (from `security-scan`)
- [ ] Review report written with APPROVED / BLOCKED rating
- [ ] PR body is the review report
- [ ] Zero open blockers from QA or review
