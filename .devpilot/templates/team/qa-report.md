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

### Frontend

```
ng test --watch=false
[paste summary output]
```

**Status:** ✅ All pass / ❌ X failures

### Backend

```
dotnet test
[paste summary output]
```

**Status:** ✅ All pass / ❌ X failures

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
