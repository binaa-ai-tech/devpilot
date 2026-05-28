# Skill: Test Strategy

Used by developers and QA. Tests are the contract that lets the team move fast
without breaking things. Untested behavior is unfinished behavior.

## The pyramid (most → fewest)
1. **Unit** — pure logic, fast, no I/O. The bulk of your tests.
2. **Integration** — a slice through real boundaries (DB, API, queue).
3. **End-to-end** — a few critical user journeys only. Slow and brittle; keep rare.

## What to test (every change)
- The **happy path** for each acceptance criterion.
- At least one **edge** case (boundary, empty, max).
- At least one **error / failure** path (invalid input, dependency down).
- The **regression** the bug exposed (for fixes — see `bugfix` flow: fail first, pass after).

## How
- Write the test name as a sentence: `returns_403_when_user_lacks_role`.
- Arrange → Act → Assert. One logical assertion per test.
- Test behavior and contracts, not implementation details — don't assert on private internals.
- New code is the coverage target; don't chase a global % by testing trivia.
- Tests live next to the code and run in the standard suite (no manual-only checks).

## Mutation mindset (QA)
Ask "what wrong code would still pass these tests?" Then add the test that
catches it: flipped conditionals, off-by-one, null/empty, swapped arguments.

## Rules
- A green suite with no test for the new behavior is a fail.
- Never weaken an assertion to make a test pass — fix the code.
- Flaky tests are bugs; quarantine and fix, don't ignore.
