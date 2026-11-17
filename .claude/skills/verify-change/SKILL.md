---
name: verify-change
description: "Verification means running the change: start the app, drive the journeys the diff touches in a real browser against the feature map, keep screenshots and a pass/fail report as evidence."
when_to_use: "In /dp-build before the final commit, in /dp-pr before a PR is opened or merged, and whenever someone claims a change works."
user-invocable: false
---
# Verify — run the change, keep the evidence

A green suite proves the tests pass. **Verify proves the change works**: the app starts, a real
browser walks the affected journeys, and the expected result is seen. "It should work" is not a
result. `smoke.sh` is a different thing — it checks a deployed environment is up.

## Run it
```bash
bash scripts/verify.sh run <KEY>            # start → journeys the diff touches → report → stop
bash scripts/verify.sh features             # which features the diff maps to
bash scripts/verify.sh gate <KEY>           # exit 0 only with a passing report
```
1. **Start** — `VERIFY_API_CMD` / `VERIFY_FE_CMD`, then wait for `VERIFY_API_HEALTH` /
   `VERIFY_FE_URL` (bounded by `VERIFY_TIMEOUT`, default 120 s). A service that already answers is
   reused. Whatever the script started is always stopped, on failure too.
2. **Select** — changed files → features, through the `Files:` globs of the feature map. Only
   touched features run (`--all` runs every one).
3. **Drive** — one Playwright journey per feature (`--grep @<id>`, retries 0) in a real browser.
4. **Evidence** — `docs/tasks/<KEY>-evidence/`: `<feature>/` screenshots, `console-errors.log`,
   `network-failures.log`, `journey.log`, and `verify-report.md` with one pass/fail line per journey.

Settings live in `.devpilot/config.sh` (environment variables win):
`bash scripts/devpilot-config.sh set verify_fe_cmd="npm --prefix web start"` — also
`verify_fe_url`, `verify_api_cmd`, `verify_api_health`, `verify_timeout`, `verify_e2e_dir`.

## The feature map — `docs/feature-map.md`
One entry per feature **as the user sees it**. It is the list of journeys and the **grading
rubric**: a journey passes only if its `Expected` result is observed.

```markdown
## F-01 · Export orders as CSV
- Route: /orders
- Files: web/src/app/orders/*, api/Controllers/Orders*
- Steps: open Orders → filter "This month" → click "Export CSV"
- Selectors: getByRole('button', { name: 'Export CSV' }) · getByTestId('orders-table')
- Expected: orders-<date>.csv downloads with one row per listed order; toast "Export ready"
```
- **No map?** `verify.sh run` writes a draft from `docs/requirements/` and the routes, marked
  `DRAFT — needs owner review`. Fill the entries this change touches, use it, and **flag the
  draft in the PR**. Only an owner removes the draft note.
- A changed runtime file that no entry owns fails the run: add it to a `Files:` line, or add
  the missing feature. New feature → new entry in the same PR.
- `Expected` is what a user could confirm by looking — a value, a row, a message, a download.
  "Page loads" is not an expected result.

## The journey
A Playwright test tagged with the feature id, written per `ui-e2e-playwright`. It asserts the
map's `Expected` and leaves evidence where the script points:

```ts
test('export orders as CSV @F-01', async ({ page }, testInfo) => {
  const dir = process.env.VERIFY_EVIDENCE_DIR ?? testInfo.outputDir;
  const consoleErrors: string[] = [], failed: string[] = [];
  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('requestfailed', r => failed.push(`${r.method()} ${r.url()} ${r.failure()?.errorText}`));
  page.on('response', r => { if (r.status() >= 400) failed.push(`${r.status()} ${r.url()}`); });

  await page.goto('/orders');
  await page.getByRole('button', { name: 'Export CSV' }).click();
  await expect(page.getByText('Export ready')).toBeVisible();          // the Expected result
  await page.screenshot({ path: `${dir}/orders-export.png`, fullPage: true });

  if (consoleErrors.length) fs.writeFileSync(`${dir}/console-errors.log`, consoleErrors.join('\n') + '\n');
  if (failed.length) fs.writeFileSync(`${dir}/network-failures.log`, failed.join('\n') + '\n');
});
```
Put the listeners in a shared fixture once the second journey needs them. A journey that passes
without a screenshot counts as a fail — there is nothing to show.

## Reading the report
- `Result: ✅ PASS` — every touched journey observed its expected result.
- `Result: ❌ FAIL` — read `<feature>/journey.log`, then `self-heal`: the same 3-attempt protocol,
  then the escalation template. Fix the code or the journey's locator — never the `Expected` line
  to match broken behavior.
- `Result: ❌ UNSTABLE` (`--repeat N`) — the same journeys gave different results. That is a
  harness or journey defect; fix it before trusting any pass (`test-design` → flaky tests).
- Console errors and failed requests are listed per journey. A new one is a finding even when
  the journey passed — explain it or fix it.

## No runtime surface
Docs, config, CI or tooling only? The script records it itself when the diff has no runtime
file. Otherwise write the reason — it is reviewed like code:
```bash
bash scripts/verify.sh skip <KEY> "CI workflow change only — nothing a user or API caller can observe"
```

## Rules
- Verify **before the final commit** and attach the evidence folder to the PR
  (`definition-of-done`). `/dp-pr` refuses a PR with no passing report and no written reason.
- Never edit the report by hand, lower an `Expected`, or delete a failing journey to get a pass.
- Keep it fast: only touched features, services reused when already up. If a run is slow or
  inconsistent, fix the harness first — an unreliable check gets skipped.
