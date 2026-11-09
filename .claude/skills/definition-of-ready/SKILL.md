---
name: definition-of-ready
description: "Entry gate a Story must pass before it joins a sprint (clear, testable, sized, sliced, deduplicated, spec reviewed), plus how to cut work into thin vertical slices and sequence them."
when_to_use: "When writing, slicing or sprint-planning Stories (/dp-plan, /dp-spec, /dp-sprint)."
user-invocable: false
---
# Definition of Ready — thin, testable slices that may enter a sprint

Used by the **BA / Team Lead** in `/dp-plan` (before writing a Story), `/dp-spec` (before the
spec review) and `/dp-sprint` (before a Story joins a sprint). The mirror of
`definition-of-done`: DoD gates the exit, DoR gates the entry. A "not ready" Story stays in the
backlog — never pull unclear work into a sprint.

## The gate — all must be true
- [ ] **Clear value** — one user story (`As a … I want … so that …`), not a vague title.
- [ ] **Testable ACs** — every acceptance criterion is observable and verifiable; no "should work nicely".
- [ ] **Scoped** — the layers it touches are named (frontend / backend / DB / integration).
- [ ] **Sized and sliced** — S or M (see sizing below); an L is split into vertical slices first.
- [ ] **Dependencies known** — blocking Stories identified; nothing depends on undone foundational work.
- [ ] **No open question that changes scope** — assumptions are documented, not pending answers.
- [ ] **Deduped** — checked against the backlog index; not a duplicate or unmerged overlap.
- [ ] **Spec reviewed** (`spec_review` on, M/L Stories) — the spec passed the Goldfish review
      (`/dp-spec`, `spec-review` skill): no open 🔴 findings in `docs/specs/<slug>/review.md`.

## Slice vertically, not horizontally
- A good slice goes end-to-end (UI → API → DB) for ONE small capability and is independently
  shippable and testable.
- Bad slice: "build all the backend", then "build all the frontend" — nothing works until the end.
- Start with a **walking skeleton**: the thinnest path that runs end-to-end, then add capability
  slice by slice.

## Sizing (relative, not hours)
| Size | Meaning | Route |
|------|---------|-------|
| **S** | one file/component, no new contracts | fast path |
| **M** | one layer or a small cross-layer slice, a few files | layer-locked or full team flow |
| **L** | multiple layers or new contracts | **split** into S/M slices before building |

## Sequencing
1. Order slices so each builds on a working state (no big-bang integration).
2. Do the riskiest / most-uncertain slice early to surface unknowns.
3. Define the acceptance criteria per slice — they are the test contract (`test-design`).

## On failure
Don't block silently. Record the missing item on the Story (tracker comment / `docs/requirements`),
keep it in the backlog as **needs grooming**, and surface it in the `/dp-sprint` recommendation
("3 Stories not ready: …"). Readiness is the BA/PM's job to resolve, autonomously where possible —
record assumptions, don't pause to ask (`core-rules` #1).
