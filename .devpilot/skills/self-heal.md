# Skill: Self-Healing (Error Recovery + Model Fallback)

Apply this skill in every agent. It covers two scenarios:
build/lint/test failures and Claude limit fallback to the configured fallback engine.

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

## Part 2 — Limit Fallback & Cross-Tool Resumability

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
```bash
FALLBACK_ENGINE=$(grep -A 10 '^engines:' project.config.md | grep '^\s*fallback:' | head -1 \
  | sed 's/.*fallback:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
FALLBACK_MODEL=$(grep -A 20 "^  ${FALLBACK_ENGINE}:" project.config.md 2>/dev/null \
  | grep "    <agent-role>:" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
# e.g. for backend agent: grep '    backend:' under the fallback engine's section
```

**Step 2 — Write checkpoint (structured state)**

```bash
bash scripts/checkpoint.sh write \
  --key "$KEY" \
  --slug "$SLUG" \
  --branch "$BRANCH" \
  --base-branch "$BASE_BRANCH" \
  --command "$COMMAND" \
  --task "$TASK" \
  --runner "claude" \
  --coding-engine "$IMPL_ENGINE" \
  --phase-completed "<last completed phase>" \
  --next-phase "<phase to resume>" \
  --agents-completed "<comma-separated list of done agents>" \
  --agents-remaining "<comma-separated list of remaining agents>" \
  --pause-reason "limit_hit"
```

The checkpoint JSON at `docs/tasks/<KEY>-checkpoint.json` stores all fields needed by any runner (Claude, opencode, antigravity) to resume without re-deriving context.

**Step 3 — Write the engine-aware fallback prompt**

The fallback prompt must NOT contain Claude-Code-specific instructions (no "spawn subagent_type", no "use Agent tool"). Write a self-contained brief the fallback engine can execute directly:

Write `docs/fallback/<slug>-<phase>-prompt.md`:
```markdown
# Implementation Brief — <Phase> — <slug>
# Runnable by: <FALLBACK_ENGINE> (no subagents, no Claude-specific tools)

## What you are
You are a coding assistant running in <FALLBACK_ENGINE> mode.
Execute every step below using your bash tool and file editing tools.
Do NOT spawn subagents. Do NOT use the Agent tool. You are the implementation agent.

## Task
<original task description>

## Branch
<feature branch> — check it out first:
git checkout <branch>

## What was already done
<list files already committed — use: git log <base_branch>..HEAD --oneline>

## Remaining work for <Phase>
<exact steps still needed from the plan>
<specific files to create or modify>
<acceptance criteria not yet passing>

## Rules
Read .devpilot/rules.md before writing any code.

## When done
Run: <lint/build/test command>
Commit with: <feat|fix>(<slug>): <description>
Then: /ceo resume    (or: bash scripts/run-command.sh ceo resume)
```

**Step 4 — Report to user**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  LIMIT REACHED — <Phase Name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Checkpoint saved: docs/tasks/<KEY>-checkpoint.json
Fallback engine:  <FALLBACK_ENGINE>
Fallback model:   <FALLBACK_MODEL>

Run this now:
  <FALLBACK_ENGINE> --model "<FALLBACK_MODEL>" < docs/fallback/<slug>-<phase>-prompt.md

When done → run:
  /ceo resume                           (from Claude Code)
  bash scripts/run-command.sh ceo resume (from any terminal)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then stop. Do not attempt to continue the current phase.

### What NOT to do

- Never write Claude-Code-specific instructions (subagent spawning) into fallback prompts — the fallback engine cannot execute them
- Never silently skip implementation steps to work around a limit
- Never pretend work is done if it was cut short
- Never open a PR if any phase fell back to an external engine and `/ceo resume` hasn't run
