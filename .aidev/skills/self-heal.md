# Skill: Self-Healing (Error Recovery + Model Fallback)

Apply this skill in every agent. It covers two scenarios:
build/lint/test failures and Claude limit fallback to opencode.

---

## Part 1 — Build / Lint / Test Recovery (3-attempt protocol)

When a build, lint, or test command fails:

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

### Hard rules — never do these to "fix" a failure
- Do not add `// @ts-ignore` or `// eslint-disable` to silence errors (unless a documented false positive)
- Do not delete or skip tests to make the suite green
- Do not widen types to `any` or add `!` non-null assertions to fix type errors
- Do not change test assertions to match broken behavior

---

## Part 2 — Claude Limit Fallback (model exhaustion recovery)

### Trigger Signals

You have hit a limit when you observe any of:
- Rate limit error / 429 response
- "Claude is currently overloaded"
- Context window exceeded during a large task
- Response truncated mid-implementation
- Repeated tool call failures on the same operation

### Recovery Steps

When a limit signal is detected during an **implementation phase** (Frontend, Backend, DB, Integration):

**Step 1 — Read the fallback config**
```
Read project.config.md → models.<agent>.tier2 and fallback.save_path
```

**Step 2 — Save full task state**

Write `docs/fallback/<slug>-<phase>-prompt.md`:
```markdown
# Fallback Prompt — <Phase> — <slug>

## Context
Task: <original task description>
Branch: <current branch>
Requirements: docs/requirements/<slug>.md
Plan: docs/plans/<slug>.md

## Work Completed So Far
<list files already created/modified>
<list what was done>

## Remaining Work
<exact implementation steps not yet done>
<specific files to create/modify>
<acceptance criteria not yet met>

## Rules
Follow .aidev/rules.md.
Commit when done: <conventional commit message>.
Run: <lint/build/test command for this stack>
```

Write `docs/fallback/<slug>-state.md`:
```markdown
# Resume State — <slug>

phase_completed_up_to: <last completed phase>
next_phase: <phase to resume at>
branch: <feature branch name>
requirements: docs/requirements/<slug>.md
plan: docs/plans/<slug>.md
```

**Step 3 — Report to user**

Output exactly:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  CLAUDE LIMIT REACHED — <Phase Name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Fallback model: <tier2 model from project.config.md>

Run this now:
  opencode --model "<model name>" < docs/fallback/<slug>-<phase>-prompt.md

When opencode finishes → run: /ceo resume
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then stop. Do not attempt to continue the current phase.

### Tier 3 Free Fallback

If Tier 2 (Copilot) is also unavailable, use `project.config.md → models.<agent>.tier3`.
Output the same block with the free model name.

### What NOT to do

- Never silently skip implementation steps to work around a limit
- Never pretend work is done if it was cut short
- Never open a PR if any phase fell back to opencode and `/ceo resume` hasn't run
