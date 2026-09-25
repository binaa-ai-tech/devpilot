# QA Report: <TASK-TITLE>

**Ticket:** <JIRA-KEY>
**Branch:** `feature/<n>-<slug>`
**Date:** <DATE>
**QA Agent:** AI QA Engineer

---

## Acceptance Criteria Coverage

| # | Criterion | Test File | Status |
|---|-----------|-----------|--------|
| 1 | <AC text> | `<file:line>` | ✅ Pass / ❌ Fail / ⚠️ Partial |

---

## Test Results

Run via `bash scripts/run-tests.sh all` — paste the summary lines only; full logs stay in `.devpilot/logs/`.

| Suite | Result | Notes |
|-------|--------|-------|
| .NET (`dotnet`) | ✅ <passed>/<total> / ❌ <n> failing | <failing tests, if any> |
| Angular (`angular`) | ✅ <passed>/<total> / ❌ <n> failing | |
| UI / E2E (`e2e`) | ✅ <passed>/<total> / ❌ <n> failing / n/a | <trace path for failures> |
| Accessibility (axe) | ✅ clean / ❌ <violations> / n/a | |

---

## Edge Cases Verified

- [ ] <Edge case 1> — <result>
- [ ] <Edge case 2> — <result>

---

## Blockers

> List items that prevent PR approval. Leave empty section header if none.

- ❌ **BLOCKER:** <which AC is not met and why>

---

## Warnings

- ⚠️ <Non-blocking concern>

---

## QA Sign-off

**Result:** ✅ PASS / ❌ BLOCKED
**Ready for PR:** Yes / No (resolve blockers first)
