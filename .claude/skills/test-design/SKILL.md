---
name: test-design
description: "Design tests before writing them: derive cases from acceptance criteria (boundaries, negatives, traceability), pick the pyramid layer that proves each one, and apply the mutation mindset."
when_to_use: "In the QA phase or /dp-test before any test code, and whenever deciding what to test and at which layer."
user-invocable: false
---
# Test Design — cases on paper first, each at the cheapest layer that proves it

Used by developers and QA. Load it **before writing test code** (QA phase, `/dp-test`, or a
developer covering their own layer). Cases are cheap to review on paper and expensive to
retrofit in code. Untested behavior is unfinished behavior.

## 1. Derive the cases — per acceptance criterion
1. **Happy path** — one Given/When/Then straight from the AC's wording.
2. **Boundaries** — split inputs into equivalence partitions; one case per partition, plus each
   edge: `min−1, min, max, max+1`, empty, exactly-one, many.
3. **Negative** — invalid/malformed input, missing or wrong-role auth, dependency down/timeout,
   duplicate submission.
4. **State** — empty state, concurrent change, repeat/idempotency where the operation can run twice.
5. **Regression** (bug fixes) — the case the bug exposed: fails before the fix, passes after.

## 2. Pick the layer — the pyramid (most → fewest)
1. **Unit** — pure logic, fast, no I/O. The bulk of your tests.
2. **Integration** — a slice through real boundaries (DB, API, queue).
3. **End-to-end** — a few critical user journeys only. Slow and brittle; keep rare.

| Layer | Angular | .NET | Python |
|-------|---------|------|--------|
| Unit | Vitest specs — services, pipes, components (`angular-testing`) | xUnit — services/handlers/validators (`dotnet-testing`) | pytest (`python-testing`) |
| Integration | Component + `HttpTestingController` | `WebApplicationFactory` + SQL Server via Testcontainers | `httpx` against the real app |
| Contract | Generated client compiles against committed OpenAPI | OpenAPI snapshot test (`api-contract`) | OpenAPI snapshot |
| E2E / UI | Playwright journeys across the real app + API (`ui-e2e-playwright`) | | |

Choose the **cheapest layer that can actually fail** for the behavior. Run every layer through
`bash scripts/run-tests.sh` (`token-lean-testing`).

## 3. Traceability matrix
Record the cases in the QA report (`docs/qa/<slug>.md`) before implementing them:

| Case | AC | Given / When / Then | Type | Priority | Automated at |
|------|----|---------------------|------|----------|--------------|
| TC-1 | AC-1 | logged-in user / clicks export / CSV downloads | happy | P0 | integration |

- Every AC has ≥ 1 case; every case traces back to an AC (or names the regression it pins).
  Orphan cases mean the spec is incomplete — flag it.
- **P0** — money, data loss, security, auth. **P1** — the core user journey. **P2** — everything else.
  P0/P1 are always automated. P2 may be deferred with a note in the QA report — never silently skipped.

## 4. Mutation mindset
Ask "what wrong code would still pass these tests?" Then add the test that catches it: flipped
conditionals, off-by-one, null/empty, swapped arguments. A case that cannot fail is not a case —
apply this to the design, not just the code.

## How to write them
- Name the test after the Then, as a sentence: `returns_403_when_user_lacks_role`.
- Arrange → Act → Assert. One behavior per test; compound tests hide which behavior broke.
- Test behavior and contracts, not implementation details — don't assert on private internals.
- New code is the coverage target; don't chase a global % by testing trivia.
- Tests live next to the code and run in the standard suite (no manual-only checks).

## Rules
- A green suite with no test for the new behavior is a fail.
- Never weaken an assertion to make a test pass — fix the code.
- Flaky tests are bugs; quarantine and fix, don't ignore.
- `test-guard` is the mechanical enforcement of this skill at every merge gate.
