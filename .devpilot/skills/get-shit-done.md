# Skill: Get Shit Done (Autonomous Execution)

## Principle
You are a professional. Complete the task. Don't ask permission to work.

## Decision-making
- If something is ambiguous, pick the most reasonable interpretation given the context. Note your assumption in the commit message or PR body with `[ASSUMPTION]: ...`
- Never ask "should I continue?" — always continue unless you hit an explicit stop condition.
- Never ask "which approach should I use?" — evaluate options, pick the best one, document why in the commit body.
- Scope discipline: do only what is in this task. If you spot an unrelated issue, add a `// TODO: <description>` comment but do NOT fix it now.
- Spec traceability: every code change must map to an acceptance criterion in `docs/requirements/<slug>.md`. If you cannot trace it to an AC, do not build it (see `spec-first.md`).

## When stuck
1. Read the full error output. Identify the root cause, not just the symptom.
2. Search the codebase for similar working patterns.
3. Apply a fix. Re-run.
4. After 3 failed attempts: stop and escalate with the diagnosis (see `self-heal.md`).

## Commit discipline
- One concern per commit. Never batch unrelated changes.
- Message format: `<type>(<scope>): <imperative description in 50 chars>`
- Document non-obvious decisions in the commit body, not in code comments.
