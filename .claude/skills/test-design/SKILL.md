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

| Case | AC | Given / When / Then | Type | Kind | Priority | Automated at |
|------|----|---------------------|------|------|----------|--------------|
| TC-1 | AC-1 | logged-in user / clicks export / CSV downloads | happy | example | P0 | integration |
| TC-2 | AC-2 | any deposit/withdrawal sequence / applied / balance never negative | state | property | P0 | unit |

- **Kind** — every planned test is one of `example | property | differential | e2e`:
  `example` (hand-picked inputs, the default) · `property` (§5) · `differential` (§6) ·
  `e2e` (a Playwright journey).

- Every AC has ≥ 1 case; every case traces back to an AC (or names the regression it pins).
  Orphan cases mean the spec is incomplete — flag it.
- **P0** — money, data loss, security, auth. **P1** — the core user journey. **P2** — everything else.
  P0/P1 are always automated. P2 may be deferred with a note in the QA report — never silently skipped.

## 4. Mutation mindset
Ask "what wrong code would still pass these tests?" Then add the test that catches it: flipped
conditionals, off-by-one, null/empty, swapped arguments. A case that cannot fail is not a case —
apply this to the design, not just the code.

## 5. Property tests — state the invariant, let the library attack it
An example test checks the inputs you thought of. A property test states something that must
hold for **every** input and lets a generator try to break it, then shrinks a failure to the
smallest counter-example. Use one where the input space is large and the rule is simple to say.

| Kind | The property | Example from our domain |
|------|--------------|-------------------------|
| **Round-trip** | serialize, then parse, gives the original | A cheque-book request → JSON / MT-style message → parsed back equals the request (amounts, IBAN, Arabic names intact) |
| **Invariant** | a rule holds after any sequence of operations | After any sequence of deposits, withdrawals and reversals a balance is never negative; issued cheque-book serial ranges never overlap; a raffle never sells more tickets than exist |
| **Idempotency** | running it twice equals running it once | Re-applying a migration, re-normalizing an IBAN or phone number, retrying a payment with the same idempotency key, re-running the raffle draw with the same seed |
| **Equivalence** | the optimized code matches the naive reference | The batched / SQL prize-allocation or interest calculation returns exactly what the simple loop does |

Libraries (in the **target project**): **fast-check** (Angular / TS, runs inside Vitest) ·
**FsCheck** (.NET, `FsCheck.Xunit` `[Property]`) · **Hypothesis** (Python, `@given`).
- Generate **valid domain values** (amounts as integers of the minor unit, real serial ranges),
  not raw noise — a generator that mostly produces rejected input tests the validator only.
- Keep the failing seed / shrunk case the library prints and add it as an `example` test.
- A property is extra to, not instead of, the AC's example cases. Money, serial ranges, draws and
  parsers are the first candidates; a CRUD screen is not.

## 6. Differential tests — old and new on the same inputs
When behavior must **not** change (a framework upgrade, an API migration, a stored-procedure
rewrite, a performance refactor), run the old and the new implementation on the same inputs and
compare the outputs. Anything that differs is a bug or an unapproved breaking change, unless it
is listed in `docs/tests/approved-differences.md`. Recipes, normalization and the approved list:
`stack-upgrade` → Differential tests.

## Flaky tests — find the cause, or delete the test
A test that passes and fails on the same code tells you nothing either way, and teaches the team
to ignore red.
- **Never** skip it (`.skip`, `[Fact(Skip=…)]`, `@pytest.mark.skip`, `xit`), give it a `sleep` or a
  fixed wait, or retry it until green. Playwright runs with `retries: 0` — locally **and in CI**.
- **Find the root cause** — ordering, shared state, time, network, or a missing await / locator
  wait: it depends on another test having run · rows, files, statics or an account are shared ·
  clock, timezone, midnight, timers · a real third party or a race between requests · an assertion
  made before the app settled. Reproduce it: run the test alone, 20× in a loop, in reverse order,
  with the clock moved.
- **Not found within the 3-attempt protocol (`self-heal`) → delete the test.** Record it in
  `docs/tests/removed-tests.md` and open a follow-up item (`tracker.sh new Task …`) to rewrite it:

  | Test | File | Symptom | Ruled out | Date | Story |
  |------|------|---------|-----------|------|-------|
  | `exports orders as CSV` | `e2e/specs/orders.spec.ts` | fails ~1 in 8 on the download assertion | ordering, shared rows, clock | 2026-11-17 | MSK-12 |

  A deleted test with a written reason is honest: the gap is visible and owned. A skipped or
  retried one hides the same gap behind a green run. This is the only sanctioned way a test leaves
  the suite because it fails — and never for a test that fails **every** time (that is a real bug).

## How to write them
- Name the test after the Then, as a sentence: `returns_403_when_user_lacks_role`.
- Arrange → Act → Assert. One behavior per test; compound tests hide which behavior broke.
- Test behavior and contracts, not implementation details — don't assert on private internals.
- New code is the coverage target; don't chase a global % by testing trivia.
- Tests live next to the code and run in the standard suite (no manual-only checks).

## Rules
- A green suite with no test for the new behavior is a fail.
- Never weaken an assertion to make a test pass — fix the code.
- A flaky test is a bug with a root cause — see **Flaky tests** below. No skip, no sleep, no retry.
- `test-guard` is the mechanical enforcement of this skill at every merge gate.
