# Code Review: <TASK-TITLE>

**Ticket:** <JIRA-KEY>
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

## Issues Found

| Severity | File | Description |
|----------|------|-------------|
| ❌ BLOCKER | `<file>` | <description> |
| ⚠️ WARNING | `<file>` | <description> |

---

## Decision

**Rating:** ✅ APPROVED / ⚠️ APPROVED WITH WARNINGS / ❌ BLOCKED

> If BLOCKED — reason: <explain>

---

## Test Instructions

1. Checkout `feature/<n>-<slug>`
2. <Step to reproduce the feature>
3. <Expected result>
