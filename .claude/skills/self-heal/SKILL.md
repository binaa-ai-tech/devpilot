---
name: self-heal
description: "Root-cause debugging, 3-attempt build/test recovery, model-limit fallback."
when_to_use: "Whenever a build, test or command fails."
user-invocable: false
---
# Self-Healing — 3-attempt recovery + model fallback

Apply this skill in every agent. It covers three scenarios: debugging a bug to its
root cause, build/lint/test failures, and Claude limit fallback to the configured
fallback engine.

---

## Part 0 — Debugging method (bug / issue tracks)

Debugging is a search, not a guess. Find the root cause before touching code.
1. **Reproduce** — a reliable, minimal repro (exact inputs, env, steps). No repro, no fix claim.
2. **Observe** — read the full error, stack trace, and logs; state actual vs. expected precisely.
3. **Hypothesize** — 1–3 concrete, falsifiable causes.
4. **Localize** — bisect (`git bisect`, binary-search the data flow, temporary instrumentation);
   confirm or kill each hypothesis with evidence.
5. **Fix the root cause**, not the symptom — a try/catch that hides the error is not a fix.
6. **Lock it in** — a regression test that fails before the fix and passes after; root cause in
   one line on the PR/ticket. Remove temporary debug logging before committing.

Heuristics: "worked before" → diff against the last good state · "works locally, fails in env X"
→ config/data/schema, not logic (`prompts/6-env-diff.md`) · intermittent → ordering,
concurrency, time, or shared state. Three dead hypotheses → escalate with what you ruled out.

---

## Part 1 — Build / Lint / Test Recovery (3-attempt protocol)

When a build, lint, or test command fails (run suites via `bash scripts/run-tests.sh` —
`token-lean-testing` — and read only the failure lines):

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

## Part 2 — Usage limits & resumability

### Trigger signals
- Rate limit / 429, "overloaded", or a usage-limit message
- Context window exhausted mid-task, or a response truncated mid-implementation
- Repeated tool failures on the same operation

### Recovery
1. **Downshift first** (cheap, no stop): if the phase is running on the power tier, finish it on
   the standard tier (`bash scripts/resolve-model.sh tier standard`) — a Sonnet finish beats a stall.
2. **Checkpoint and stop cleanly** when the limit is hard:
   ```bash
   bash scripts/checkpoint.sh write \
     --key "$KEY" --slug "$SLUG" --branch "$BRANCH" --base-branch "$BASE_BRANCH" \
     --command "/dp-deliver" --task "$TASK" --runner claude --coding-engine claude \
     --phase-completed "<last completed phase>" --next-phase "<phase to resume>" \
     --agents-completed "<done agents>" --agents-remaining "<remaining agents>" \
     --pause-reason "usage_limit"
   ```
   Commit and push whatever is already green on the branch so no work lives only in the session.
3. **Report and stop:**
   ```
   ⚠️  USAGE LIMIT — <phase>
   Checkpoint: docs/tasks/<KEY>-checkpoint.json   ·   Branch: <branch> (pushed)
   Resume when the limit resets:  /dp-deliver resume
   ```

### Never
- Silently skip steps to squeeze under a limit, or claim work is done when it was cut short.
- Open or merge a PR from a run that stopped mid-phase before `/dp-deliver resume` completes it.
