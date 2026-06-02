# Skill: Definition of Done (DoD Gate)

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

### Security (always run `security-scan.md`)
- [ ] Security scan checklist completed
- [ ] Zero 🔴 CRITICAL security issues

---

## Frontend DoD (Frontend Developer)

All universal items, plus:
- [ ] `ng lint` passes / `npm run lint` passes
- [ ] `ng build --configuration=production` passes / `npm run build` passes
- [ ] `ng test --watch=false` passes / `npm test -- --watchAll=false` passes
- [ ] All new components use `ChangeDetectionStrategy.OnPush`
- [ ] WCAG 2.1 AA checklist reviewed (see `frontend-agent.md` accessibility section)
- [ ] Performance checklist completed (from `performance-review.md`)
- [ ] Self-heal protocol applied on any failures (from `self-heal.md`)

---

## Backend DoD (.NET Developer)

All universal items, plus:
- [ ] `dotnet build` passes with zero warnings on new code
- [ ] `dotnet test` passes with zero failures
- [ ] All new service methods have unit tests
- [ ] All new API endpoints have integration tests
- [ ] DB migrations are idempotent (tested with `IF NOT EXISTS` patterns)
- [ ] Performance checklist completed (from `performance-review.md`)
- [ ] Architecture guardrails checked (from `architecture-guard.md`)
- [ ] Self-heal protocol applied on any failures (from `self-heal.md`)

---

## QA DoD (QA Engineer)

All universal items, plus:
- [ ] Every acceptance criterion has at least one dedicated test
- [ ] Happy path, at least two edge cases, and at least one error/empty state are covered
- [ ] Mutation-mindset applied: boundary values, null/empty inputs, inverted boolean conditions all tested
- [ ] QA report written with explicit ✅ PASS or ❌ BLOCKED verdict
- [ ] No blockers left unresolved

---

## Team Lead DoD (Review)

All universal items, plus:
- [ ] All agent DoDs verified (Frontend, Backend, QA reports reviewed)
- [ ] Architecture guardrails checked across entire diff (from `architecture-guard.md`)
- [ ] Security scan run across entire diff (from `security-scan.md`)
- [ ] Review report written with APPROVED / BLOCKED rating
- [ ] PR body is the review report
- [ ] Zero open blockers from QA or review
