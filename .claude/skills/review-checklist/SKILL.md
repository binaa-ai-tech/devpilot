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

## The rules come from the base branch
A change must not be judged by rules it edited. Before reviewing:
```bash
bash scripts/rules-guard.sh touched            # exit 1 → the diff edits its own checks
bash scripts/rules-guard.sh show <path>        # = git show origin/<base_branch>:<path>
```
- Load every rule you review against with `rules-guard.sh show`, **never from the working tree**:
  `.claude/skills/**`, `.claude/commands/**`, `.claude/settings.json`, `.devpilot/rules/**`,
  `.devpilot/rules.md`, `.devpilot/reliability-checklist.md`, `CLAUDE.md`, `scripts/test-guard.sh`,
  `scripts/test-guard.exempt`, `.github/workflows/**` (full list: `rules-guard.sh list`).
- If `touched` exits 1, the review starts with this line, and so does the PR body:
  **"⚠️ This change edits the checks that judge it — human review required."**
  Such a PR is never auto-merged (`auto-merge`).
- **A weakened check is a 🔴 finding** — a removed assertion, a widened exemption
  (`test-guard.exempt`, a broader glob), retries raised, a timeout stretched, a rule or checklist
  item deleted, a gate made non-blocking, an `Expected` result in `docs/feature-map.md` loosened.
  Say which check, and what it no longer catches.
- A file that is new on the branch has no base copy: read it as part of the diff, not as a rule.

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
8. **Reliability checklist** — `bash scripts/reliability.sh match` reads
   `.devpilot/reliability-checklist.md` from the base branch and lists **only** the items this diff
   triggers (usually 3–10), each with what triggered it. Answer every one with evidence — a test
   name, a command and its output, or `file:line`. An item answered "no", or with no evidence, is a
   🔴 Important finding. Don't run the items that didn't trigger; the list is long on purpose.

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
Tag each finding, quote `file:line`, and say **why in one line** — the failure it causes, not the
rule it breaks:
- 🔴 **Important** — must fix before merge: a bug, a security hole, a missing test, a broken
  contract, a weakened check, a reliability item answered "no". Introduced or exposed by this diff.
- 🟢 **Nit** — optional polish; never blocks.
- 🟣 **Pre-existing** — a real problem that was already on the base branch
  (`git show origin/<base>:<file>` / `git blame` shows it predates this change). Not the author's
  bug and never blocks this PR: open a follow-up item (`tracker.sh new Bug …`) and link it. If the
  diff makes it worse or newly depends on it, it is 🔴 Important instead.

```
🔴 Important — api/Orders/OrdersController.cs:42 — Why: the owner check is gone, so any signed-in user can read another customer's orders.
🟣 Pre-existing — api/Fees/FeeCalculator.cs:18 — Why: fees are computed in double and drift by a fil on large amounts; already on develop → MSK-91.
```
`security-scan` and `performance` findings use the same tags in the report: their 🔴 is Important;
a 🟡 warning is Important when this diff introduced it and it can fail in production, otherwise Nit.
**Every escalation** — a 🔴, a send-back, a stop for a human — **states why in one line.**

## Outcome
- **APPROVED** — zero 🔴 Important; every triggered reliability item answered with evidence;
  Pre-existing findings have follow-up items. Proceed to PR/merge.
- **CHANGES REQUESTED** — any 🔴. Send back with the specific fixes and the one-line why;
  re-review after. Never merge around an Important finding.

## Rules
- Prefer the smallest fix that resolves the issue.
- If you cannot understand a change in 30 seconds, that is a readability finding.
