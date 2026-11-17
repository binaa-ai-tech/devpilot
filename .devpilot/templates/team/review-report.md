# Code Review: <TASK-TITLE>

<!-- If `bash scripts/rules-guard.sh touched` exits 1, the first line of this report is:
⚠️ This change edits the checks that judge it — human review required. -->

**Ticket:** <KEY>
**Branch:** `feature/<n>-<slug>`
**Date:** <DATE>
**Reviewer:** AI Team Lead

---

## Summary

<2–3 sentences describing what was implemented and why.>

---

## Changes Included

- <Change 1>
- <Change 2>
- <Change 3>

---

## Review Checklist

### Code Quality
- [ ] No `any` types
- [ ] No magic numbers/strings
- [ ] No commented-out code
- [ ] No secrets in code
- [ ] One concern per commit

### Angular
- [ ] `OnPush` on all new components
- [ ] `takeUntilDestroyed()` for subscriptions
- [ ] New control-flow syntax used (`@if`, `@for`)
- [ ] Signals for reactive state

### .NET / SQL
- [ ] All SQL parameterized
- [ ] DB migrations are idempotent
- [ ] Clean architecture followed

### Testing
- [ ] Tests cover all new components/services
- [ ] All tests pass

### Documentation
- [ ] Requirements doc complete
- [ ] Implementation plan complete
- [ ] QA report clean (no blockers)

---

## Reliability (`bash scripts/reliability.sh match` — triggered items only)

| Item | Triggered by | Check | Answer + evidence |
|------|--------------|-------|-------------------|
| R-0n · <title> | `<file or line>` | <question> | ✅ yes — `<test name / command output / file:line>` |

---

## Issues Found

| Severity | File:line | Finding | Why (one line) |
|----------|-----------|---------|----------------|
| 🔴 Important | `<file:line>` | <what is wrong> | <the failure it causes> |
| 🟢 Nit | `<file:line>` | <polish> | <why it is better> |
| 🟣 Pre-existing | `<file:line>` | <already on the base branch> | <impact> → follow-up <KEY> |

---

## Decision

**Rating:** ✅ APPROVED / ⚠️ APPROVED WITH WARNINGS / ❌ BLOCKED

> If BLOCKED — reason: <explain>

---

## Test Instructions

1. Checkout `feature/<n>-<slug>`
2. <Step to reproduce the feature>
3. <Expected result>
