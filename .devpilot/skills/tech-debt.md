# Skill: Tech Debt Management

A professional team takes on debt deliberately and pays it down — it never
pretends debt doesn't exist. Sustainable pace beats heroics.

## When you spot debt mid-task
- **In scope to fix cleanly?** Apply the boy-scout rule: leave it a little
  better, but only within your task's blast radius.
- **Out of scope?** Do NOT fix it now (scope discipline). Record it:
  `// TODO(<ticket-or-LOCAL-id>): <what + why>` and add a one-line note to the
  task log / tracker so it's tracked, not lost.

## Taking on debt deliberately
If you must cut a corner to ship a slice, make it visible:
- Comment `// DEBT: <shortcut taken> — proper fix: <what> — risk: <impact>`.
- Note it in the PR body under a **Known debt** heading.
- Never let a shortcut be silent or undocumented.

## Triage (Team Lead)
Rank recorded debt by **risk × frequency**:
- 🔴 High risk + hits often → schedule next.
- 🟡 Medium → backlog with a ticket.
- 🟢 Cosmetic → note and move on.

## Rules
- No silent debt. If you knowingly leave it worse, it must be written down.
- Don't gold-plate: refactoring unrelated to the task is itself scope creep.
- A `TODO` without an owner/ticket is a wish, not a plan — link it.
