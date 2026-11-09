---
name: review-checklist
description: "DevPilot's code review: review order, severity tags, clean-code and PR-hygiene standards."
when_to_use: "When the Team Lead reviews a diff, or a developer self-reviews before handoff."
user-invocable: false
---
# Code Review — the gate a defect must not pass

Used by the **Team Lead** in the review phase (`/dp-pr`, `/dp-build`), and by developers
as a self-review before handoff. A review that rubber-stamps a defect is itself a defect.
This skill also carries the clean-code, refactoring, and PR-hygiene standards.

## Principle
Review the diff, not the description. Read every changed line and ask: is it
correct, is it safe, is it tested, will the next person understand it?

## Review the diff in this order
1. **Correctness** — does it meet every acceptance criterion? Any off-by-one,
   null, race, or wrong-branch bug?
2. **Scope** — only files the plan named are touched. Flag unrelated changes.
3. **Security** — run `security-scan` over the diff: input validation, authz,
   ownership, secrets, injection, new dependencies. Zero 🔴 CRITICAL to pass.
4. **Tests** — every new behavior has a test; the test would fail without the
   change. No deleted/skipped tests to go green. `test-guard` clean.
5. **Contract** — API changes are additive or versioned; OpenAPI + Angular client
   regenerated in the same PR (`api-contract`).
6. **Design & readability** — right layer (`architecture-guard`), standards below.
7. **Performance & operability** — `performance` over queries/loops/rendering;
   errors handled and logged with context, no secrets/PII in logs.

## Clean-code standards
- **Names reveal intent** (`elapsedDays`, not `d`); booleans read as questions (`isActive`);
  one word per concept.
- **Small functions, one job**, ≤ 3 parameters, no boolean "mode" flags; guard clauses over
  nesting; no hidden side effects.
- **No magic values, no dead or commented-out code**; comments explain *why*, not *what*.
- **Match the file** — its style, naming, and idioms. DRY real duplication, not coincidence.
- Errors handled explicitly; never swallowed by an empty `catch`.

## Refactoring discipline
- A refactor **never changes behavior**. Tests are green before and after; missing coverage is
  pinned first with characterization tests.
- Refactor commits (`refactor(scope): …`) are separate from feature/fix commits — never mixed.
- Refactor in service of the task or a tracked debt item, not as a detour.

## PR hygiene
- **Atomic, conventional commits** (`feat|fix|refactor|test|chore(scope): …`); each builds.
- **Small and single-purpose** — aim for < ~400 changed lines; larger → split.
- **PR body is the technical record** — what, why, how tested, risk, exemptions.
- CI green before review; no secrets, generated noise, or TODOs without a ticket.

## Finding format
Tag each finding so the author knows what blocks merge, and quote `file:line`:
- 🔴 **BLOCKER** — must fix before merge (bug, security, missing test, breaking contract).
- 🟡 **SHOULD** — fix now unless there's a reason; note it.
- 🟢 **NIT** — optional polish.

## Outcome
- **APPROVED** — zero 🔴, all 🟡 addressed or justified. Proceed to PR/merge.
- **CHANGES REQUESTED** — any 🔴. Send back with the specific fixes; re-review
  after. Never merge around a blocker.

## Rules
- Prefer the smallest fix that resolves the issue.
- If you cannot understand a change in 30 seconds, that is a readability finding.
