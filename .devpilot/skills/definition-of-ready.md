# Definition of Ready — a story may enter a sprint only when it passes

Used by the **PM** in `/dp-plan` (before writing a Story) and `/dp-sprint` (before a
Story joins a sprint). The mirror of `definition-of-done`: DoD gates the exit, DoR gates
the entry. A "not ready" Story stays in the backlog — never pull unclear work into a sprint.

## The gate — all must be true
- [ ] **Clear value** — one user story (`As a … I want … so that …`), not a vague title.
- [ ] **Testable ACs** — every acceptance criterion is observable and verifiable; no "should work nicely".
- [ ] **Scoped** — the layers it touches are named (frontend / backend / DB / integration).
- [ ] **Sized** — a rough S / M / L; an L that can't be sliced is split first (see `estimation-and-slicing`).
- [ ] **Dependencies known** — blocking Stories identified; nothing depends on undone foundational work.
- [ ] **No open question that changes scope** — assumptions are documented, not pending answers.
- [ ] **Deduped** — checked against the backlog index; not a duplicate or unmerged overlap.

## On failure
Don't block silently. Record the missing item on the Story (Jira comment / `docs/requirements`),
keep it in the backlog as **needs grooming**, and surface it in the `/dp-sprint` recommendation
("3 Stories not ready: …"). Readiness is the BA/PM's job to resolve, autonomously where possible.
