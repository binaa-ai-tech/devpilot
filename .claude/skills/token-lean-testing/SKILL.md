---
name: token-lean-testing
description: "Run suites via scripts/run-tests.sh: full log to disk, only failures in context."
when_to_use: "Before running any build or test suite."
user-invocable: false
---
# Token-Lean Testing — run everything, read only what failed

Load this **before running any build or test suite inside an agent.** A raw `dotnet test` or
Playwright run can dump thousands of lines into context; most of it is noise. The rule: **the full
log goes to disk, the agent reads a summary.**

## Always run suites through the wrapper
```bash
bash scripts/run-tests.sh angular      # ng test --watch=false (Vitest)
bash scripts/run-tests.sh dotnet       # dotnet test (quiet)
bash scripts/run-tests.sh e2e          # playwright test --reporter=line
bash scripts/run-tests.sh all          # every suite detected in the repo
bash scripts/run-tests.sh cmd "<any command>"   # e.g. a build or lint step
```
Each prints one `✅ PASS` / `❌ FAIL` line per suite, then **only** failure lines (capped by
`TEST_MAX_LINES`, default 40), and the path of the full log under `.devpilot/logs/`. Exit code is
non-zero if any suite failed.

## Narrow before you widen
1. Fixing one failure? Re-run **only** that test: Vitest `--include=<file>`,
   `dotnet test --no-build --filter "FullyQualifiedName~<Name>"`, `npx playwright test --last-failed`.
2. Green locally → run the suite once through the wrapper to confirm no regressions.
3. Need more detail than the summary? `grep -n -A 15 "<test name>" <log>` — read the slice, never
   `cat` the whole log.

## Other savings
- Build once, then `dotnet test --no-build`; don't rebuild between test-only edits.
- Don't re-run a green suite "to be sure" in the same phase — the result is in the log.
- Report numbers, not output: "dotnet 142/142 ✅, angular 88/90 ❌ (2 in order-list.spec.ts)".
- Traces and screenshots stay on disk; cite the path in the QA report instead of describing them.
