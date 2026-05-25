# Skill: Self-Healing (Error Recovery)

When a build, lint, or test command fails, follow this protocol before escalating.

## Recovery protocol

### Attempt 1 — Diagnose
1. Read the COMPLETE error output. Do not skim.
2. Identify the root cause (not just the failing line — why did it fail?).
3. Apply a targeted, minimal fix.
4. Re-run the exact failing command.
5. ✅ Fixed → continue. ❌ Still failing → Attempt 2.

### Attempt 2 — Search for context
1. Search the codebase: how is the same pattern done elsewhere that works?
2. Check for missing imports, wrong types, stale generated files, config issues.
3. Apply a fix based on working examples.
4. Re-run.
5. ✅ Fixed → continue. ❌ Still failing → Attempt 3.

### Attempt 3 — Alternative approach
1. Isolate the smallest possible reproduction of the failure.
2. Try a structurally different approach to the same problem.
3. Re-run.
4. ✅ Fixed → continue. ❌ Still failing → ESCALATE.

### Escalation template (after 3 attempts)
```
❌ Self-heal failed after 3 attempts.

Command: `<exact failing command>`
Error:
<paste the full error output>

Root cause hypothesis: <your best diagnosis>

Attempts made:
1. <what you changed and why>
2. <what you changed and why>
3. <what you changed and why>

Needs human input to resolve.
```

## Hard rules — never do these to "fix" a failure
- Do not add `// @ts-ignore` or `// eslint-disable` to silence errors (unless it is a documented false positive)
- Do not delete or skip tests to make the suite green
- Do not widen types to `any` or add `!` non-null assertions to fix type errors
- Do not change test assertions to match broken behavior
