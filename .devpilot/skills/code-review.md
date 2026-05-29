# Skill: Code Review (Review Gate)

Used by the **Team Lead** in the review phase, and on demand via `/code-review`.
A review that rubber-stamps a defect is itself a defect.

## Principle
Review the diff, not the description. Read every changed line and ask: is it
correct, is it safe, is it tested, will the next person understand it?

## Review the diff in this order
1. **Correctness** — does it meet every acceptance criterion? Any off-by-one,
   null, race, or wrong-branch bug?
2. **Scope** — only files the plan named are touched. Flag unrelated changes.
3. **Security** — run `security-scan.md` mentally over the diff: input
   validation, authz, secrets, injection. Zero 🔴 CRITICAL to pass.
4. **Tests** — every new behavior has a test; the test would fail without the
   change. No deleted/skipped tests to go green.
5. **Design** — right layer, no duplication, names reveal intent, no dead code.
6. **Operability** — errors are handled and logged (see `observability.md`).

## Finding format
Tag each finding so the author knows what blocks merge:
- 🔴 **BLOCKER** — must fix before merge (bug, security, missing test).
- 🟡 **SHOULD** — fix now unless there's a reason; note it.
- 🟢 **NIT** — optional polish.

## Outcome
- **APPROVED** — zero 🔴, all 🟡 addressed or justified. Proceed to PR/merge.
- **CHANGES REQUESTED** — any 🔴. Send back with the specific fixes; re-review
  after. Never merge around a blocker.

## Rules
- Quote the `file:line` for every finding.
- Prefer the smallest fix that resolves the issue.
- If you cannot understand a change in 30 seconds, that is a readability finding.
