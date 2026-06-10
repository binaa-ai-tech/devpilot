# E2E Testing — a few journeys, rock solid

Load when writing or maintaining end-to-end / UI-automation tests. The pyramid
(`test-strategy.md`) caps E2E at a few critical journeys — this skill makes
those few stable enough to gate a merge.

## What deserves an E2E test
- **Critical user journeys only** — login, the money path, the feature's
  primary flow. Aim for 5–15 per app, not hundreds.
- If it can be proven by a unit or integration test, it does not get an E2E
  test. E2E verifies the *wiring*, not the logic.

## Stability rules (non-negotiable)
- **Selectors:** `data-testid` or role + accessible name — never CSS chains,
  nth-child, or display text that a copy edit will break.
- **No sleeps.** Wait on conditions: element visible, request settled,
  navigation complete. A fixed `sleep` is a flake waiting to happen.
- **Own your data.** Each test creates what it needs (API call or fixture in
  setup) and cleans up after. Never depend on test order or shared mutable rows.
- **One journey per test**; assert the user-visible outcome (the row appears,
  the toast shows), not implementation internals.

## Tooling defaults
- **Web:** Playwright first choice (auto-wait, trace viewer, parallel);
  Cypress is fine if the repo already uses it. Don't mix both.
- **API journeys:** the stack's native client (supertest / httpx /
  RestAssured / WebApplicationFactory).
- Record trace/video **on failure** in CI — a red E2E with no trace is a
  debugging session, with one it's a screenshot.

## CI placement
- Full E2E suite runs **post-merge or nightly**, not on every PR push — it
  blows the ~10-min PR budget (`ci-cd.md`). A smoke subset (≤ 3 journeys) may
  run on PR.
- A flaky E2E is a bug: quarantine-tag it the day it flakes, fix it within the
  sprint. Blind `retry: 2` is how suites rot.
