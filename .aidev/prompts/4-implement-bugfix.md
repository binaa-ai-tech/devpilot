# Prompt — Step 4: Implement Bug Fix (autonomous)

```
You are fixing bug <KEY>. Autonomous execution, no pauses.

Required reading:
1. `.aidev/rules.md`
2. `.aidev/impact-maps/<KEY>.md`
3. The ticket below

Ticket:
"""
<paste ticket — must include repro steps>
"""

Execution order:

1. REPRODUCE FIRST. Write a failing test that captures the bug exactly as
   described in the repro steps. Run the test. Confirm it fails for the
   right reason. If it passes, the bug is not what was described — stop and
   report.

2. ROOT CAUSE. Trace the bug to its true root cause. Do not fix symptoms.
   Document the root cause in a code comment near the fix and in your final
   summary.

3. FIX. Smallest change that resolves the root cause. Do not refactor unrelated
   code. Do not add new features.

4. REGRESSION TEST. The failing test from step 1 must now pass. Keep it as a
   permanent regression test.

5. RULES. Follow `.aidev/rules.md` for any code touched. No `any`,
   takeUntilDestroyed, OnPush, etc.

6. VERIFY. Run `npm run lint`, `npm test`, `npm run build`. All green before
   finishing.

Special case — SQL Server cross-environment bug:
- If the bug only reproduces in UAT/prod, do NOT change SP code first.
- Use `.aidev/prompts/6-env-diff.md` to diagnose. Prefer schema/trigger/
  server-config fixes over SP rewrites.

Output:
- Root cause in one paragraph
- Files changed (one line each)
- Regression test file + name
- Confirmation lint/test/build passed
- Suggested commit message: fix(<KEY>): <short summary>
```
