# Skill: Debugging Method

Used in bug and issue tracks. Debugging is a search, not a guess. Find the root
cause before you touch code.

## Protocol
1. **Reproduce.** Get a reliable, minimal repro. If you can't reproduce it, you
   can't claim to have fixed it. Capture exact inputs, env, and steps.
2. **Observe.** Read the full error, stack trace, and logs. Note what actually
   happens vs what should happen — be precise about the delta.
3. **Hypothesize.** Form 1–3 concrete, falsifiable hypotheses for the cause.
4. **Localize.** Bisect the space: recent commits (`git log`/`git bisect`),
   binary-search the data flow, add temporary instrumentation. Confirm or kill
   each hypothesis with evidence — don't fix on a hunch.
5. **Fix the root cause**, not the symptom. A try/catch that hides the error is
   not a fix.
6. **Lock it in.** Add a regression test that fails before the fix and passes
   after. Document the root cause in the PR/ticket.

## Heuristics
- "It worked before" → diff against the last good state.
- "Works locally, fails in env X" → it's config/data/schema, not logic (see
  `.devpilot/rules/` and `prompts/6-env-diff.md`).
- Intermittent → suspect ordering, concurrency, time, or shared state.
- Remove variables one at a time; change one thing per test.

## Rules
- Remove all temporary debug logging/prints before committing.
- No fix without a written root cause and a regression test.
- If 3 hypotheses fail, escalate with what you ruled out (see `self-heal.md`).
