# UI & E2E Testing — Playwright journeys across Angular + .NET

Load this **when a user journey, a UI acceptance criterion, or `/dp-test ui` is in scope.**
Unit and integration tests prove the logic (`angular-testing`, `dotnet-testing`); Playwright proves
the **wiring** — the real browser, the real Angular build, the real API. Playwright is the default;
keep Cypress only if the repo already has it. Never both.

## Scope — what deserves a browser test
- **Critical journeys** (login, the money path, each feature's primary flow) — roughly 5–15 per
  app, one per UI-facing AC at most. Logic already proven below does not get re-proven here.
- Per journey, test the **happy path + one failure the user can see** (validation message, 403
  page, server error toast).

## Project layout
```
e2e/
  playwright.config.ts   webServer starts API + Angular; baseURL; projects
  auth.setup.ts          logs in once per role → storageState files
  fixtures.ts            test.extend: page objects + an `api` seeding helper
  pages/                 page objects (one per screen)
  specs/<feature>.spec.ts
```
- `webServer`: an array starting the .NET API (`dotnet run --project <Api>` with a test DB
  connection) and Angular (`npx ng serve`), each with `url` + `reuseExistingServer: !process.env.CI`.
- **Auth once:** a `setup` project logs in per role and saves `storageState`; test projects
  depend on it. Never log in through the UI in every test.

## Stability rules (non-negotiable)
- **Locators:** `getByRole(name)`, `getByLabel`, `getByTestId` — never CSS chains, nth-child, or
  copy that marketing will edit. Add `data-testid` in the Angular template when no role fits.
- **No sleeps.** Web-first assertions auto-wait: `await expect(locator).toBeVisible()`,
  `toHaveText`, `toHaveURL`. `waitForTimeout` is a defect.
- **Own the data.** Seed through the API with the `request` fixture (same DTOs as the generated
  client — `api-contract`) in the test or fixture, unique per test (suffix with
  `testInfo.workerIndex` / a uuid). Never depend on order or on rows another test made.
- **Isolate the edge you're not testing.** `page.route('**/api/payments/**', …)` to stub a
  third party or force an error state; don't stub your own API in a journey test.
- **Assert what the user sees** (row appears, toast text, URL), not internals.

## Beyond happy paths
- **Accessibility:** `@axe-core/playwright` — `new AxeBuilder({ page }).analyze()` on each new
  screen; zero serious/critical violations (`accessibility`).
- **Visual regression:** `await expect(page).toHaveScreenshot()` only on stable, design-critical
  screens; mask dynamic regions; baselines are generated in CI's OS image, not locally.
- **Responsive:** add a mobile project (`devices['Pixel 7']`) for journeys that must work on phones.

## Config defaults
```ts
use: { baseURL, trace: 'retain-on-failure', screenshot: 'only-on-failure', video: 'off' },
retries: process.env.CI ? 1 : 0,   // a test that needs its retry is reported as flaky: fix it
reporter: process.env.CI ? [['line'], ['html', { open: 'never' }]] : 'line',
```

## Token-lean runs
- `bash scripts/run-tests.sh e2e` — summary + failing test names + first error lines only.
- Re-run just the failures: `npx playwright test --last-failed`; one spec: `npx playwright test specs/orders.spec.ts`.
- Debug from the trace (`npx playwright show-trace <zip>`), not by adding logging.

## CI placement
- PR: a smoke subset (tag `@smoke`, ≤ 3 journeys, `--grep @smoke`). Full suite post-merge / nightly.
- A flaky test is a bug: fix it within the sprint. Don't raise retries to hide it.

## Ship-with
- [ ] Each UI-facing AC has a journey (happy + one visible failure) or a written reason it's covered lower.
- [ ] Role/label/testid locators only; no `waitForTimeout`; data seeded via API per test.
- [ ] axe scan clean on new screens; traces kept on failure; suite green via `run-tests.sh e2e`.
