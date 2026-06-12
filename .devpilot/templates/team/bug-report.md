# Bug: <BUG-TITLE>

**Ticket:** <JIRA-KEY>  ·  **Type:** Bug  ·  **Severity:** <P0 | P1 | P2 | P3>
**Date:** <DATE>  ·  **Reported via:** <user report / monitoring / QA / hotfix>
**Affected version / area:** <version or component>

---

## Summary

<One sentence: what is broken, for whom.>

---

## Steps to Reproduce

1. <step>
2. <step>
3. <step>

**Reproducibility:** <always | intermittent (~%) | once>

---

## Expected vs. Actual

- **Expected:** <what should happen>
- **Actual:** <what happens instead — include the error/stack/screenshot path>

---

## Blast Radius

<Who/what is affected, data impact, whether a workaround exists.>

---

## Root Cause (hypothesis → confirmed)

<Where the defect lives and why. Fill the hypothesis at intake; confirm during the fix.>

---

## Acceptance Criterion (the bug's DoD)

- [ ] A test **reproduces** the bug on the current code (fails before the fix).
- [ ] After the fix that test **passes**, and it is committed as a **regression test**.
- [ ] No new regressions introduced; root cause (not just the symptom) is addressed.

---

## Severity → Path

| Severity | Path |
|----------|------|
| **P0 / P1** (prod down / data loss / security) | `/dp-hotfix` — branch from `main`, expedited, postmortem |
| **P2** (broken in prod, workaround exists) | join the **active sprint** |
| **P3** (minor / cosmetic) | backlog, batched into the next sprint |

---

## Related

- **Duplicates / related bugs:** <keys, or "None">
- **Introduced by:** <commit/PR if known, or "Unknown">
