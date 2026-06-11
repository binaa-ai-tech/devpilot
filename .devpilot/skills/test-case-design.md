# Test-Case Design — turn acceptance criteria into cases on paper first

Load when deriving test cases from acceptance criteria (QA phase, `/dp-test`) —
**before** writing any test code. Cases are cheap to review on paper and expensive
to retrofit in code. `test-strategy.md` says *what layers* to test; this says
*how to derive the cases*.

## The derivation ladder — per acceptance criterion
1. **Happy path** — one Given/When/Then straight from the AC's wording.
2. **Boundaries** — split inputs into equivalence partitions; one case per
   partition, plus each edge: `min−1, min, max, max+1`, empty, exactly-one, many.
3. **Negative** — invalid/malformed input, missing or wrong-role auth,
   dependency down/timeout, duplicate submission.
4. **State** — empty state, concurrent change, repeat/idempotency where the
   operation can run twice.

## Traceability matrix
Record the cases in the QA report (`docs/qa/<slug>.md`) before implementing them:

| Case | AC | Given / When / Then | Type | Priority | Automated at |
|------|----|---------------------|------|----------|--------------|
| TC-1 | AC-1 | logged-in user / clicks export / CSV downloads | happy | P0 | integration |

- Every AC has ≥ 1 case; every case traces back to an AC (or names the
  regression/bug it pins). Orphan cases mean the spec is incomplete — flag it.

## Prioritize, then automate
- **P0** — money, data loss, security, auth. **P1** — the core user journey.
  **P2** — everything else.
- P0/P1 are always automated (unit/integration per the pyramid). P2 may be
  deferred with a note in the QA report — never silently skipped.

## Rules
- A case that cannot fail is not a case — apply the mutation mindset to the
  design, not just the code: "what wrong implementation would still pass this?"
- Name the eventual test after the Then: `returns_403_when_user_lacks_role`.
- One behavior per case. Compound cases hide which behavior broke.
