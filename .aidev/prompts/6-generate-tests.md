# Prompt — Step 6: Generate Tests (fill coverage gaps)

```
You are filling test coverage gaps for the changes in this PR.

Files changed:
"""
<paste list from diff or PR>
"""

For each file:

1. Locate or create the matching `*.spec.ts`
2. Cover at minimum:
   - Component renders without errors with default inputs
   - One interaction (click, input change, signal emit)
   - One business-logic branch (happy path)
   - One error/edge case
3. For services:
   - One method per public API
   - One error path (e.g. HTTP failure)
4. Use TestBed with standalone imports. No NgModule-based setup for new code.
5. Mock dependencies with `jasmine.createSpyObj` or test doubles. Never hit
   real HTTP, real DOM beyond component fixtures, or real timers (use
   `fakeAsync` / `tick`).

Follow `.aidev/rules.md`. No `any`. Use proper types for mocks.

After writing, run `npm test`. If any test fails for the wrong reason (your
mocks are off, not a real bug), fix the test. If it fails for a real reason,
report it as a bug finding — do not silently change the test to pass.

Output:
- List of *.spec.ts files created/updated
- Coverage summary (which behaviors are now tested)
- Confirmation `npm test` passes
- Any real bugs found while testing (flag for separate ticket)
```
