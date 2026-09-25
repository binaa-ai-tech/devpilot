# Angular Testing — fast unit and component tests with Vitest

Load this **when writing or fixing Angular specs.** Default runner is **Vitest** (the Angular 21
default via `ng test`); keep Jasmine/Karma only if the repo already uses it — never mix runners.

## What to test where
| Unit | Test | Layer |
|------|------|-------|
| Pure functions, pipes, validators | Plain Vitest, no TestBed | unit |
| Services with logic / HTTP | TestBed + `provideHttpClientTesting()` | unit |
| Presentational components | TestBed render, set inputs, assert DOM + outputs | component |
| Smart components / pages | TestBed with **stubbed services** (signals), assert states | component |
| Full journeys across API + UI | not here — `ui-e2e-playwright` | E2E |

## Patterns
- **Setup:** `TestBed.configureTestingModule({ imports: [Cmp], providers: [...] })` — standalone
  imports, no NgModules. Set inputs with `fixture.componentRef.setInput('name', value)`.
- **Async:** `await fixture.whenStable()` after changes. Apps are zoneless by default, so
  `fakeAsync`/`tick` need zone.js — prefer Vitest fake timers (`vi.useFakeTimers()`) instead.
- **HTTP:** `provideHttpClient(), provideHttpClientTesting()`, then `HttpTestingController`:
  `expectOne(url)` → `flush(body)` / `flush(err, { status: 500, statusText: 'x' })`;
  `httpMock.verify()` in `afterEach`.
- **Services in component tests:** provide a stub with signals
  (`{ items: signal([]), load: vi.fn() }`) — never hit real HTTP from a component spec.
- **Queries:** by role / label / `data-testid`, not CSS chains. For Material/CDK widgets use
  **component harnesses** (`TestbedHarnessEnvironment.loader(fixture)`).
- **Router:** `provideRouter([...])` + `RouterTestingHarness` for route-driven components.
- **Mocks:** `vi.fn()` / `vi.spyOn()`; reset in `afterEach` (`vi.restoreAllMocks()`).

## Every component spec covers
1. Renders correctly for the given inputs (the happy path of each AC it serves).
2. One interaction → the expected output emitted / service method called with the right args.
3. **Loading, empty, and error** states.
4. Accessibility basics the unit can see: labelled controls, button roles.

## Token-lean runs
- Iterate on one file: `npx ng test --watch=false --include='**/order-list*.spec.ts'`.
- Full suite via `bash scripts/run-tests.sh angular` — returns a short summary, not the log.

## Ship-with
- [ ] One `*.spec.ts` beside each new component/service/pipe; behavior asserted, not internals.
- [ ] HTTP verified with `HttpTestingController` (success + one error status).
- [ ] No real timers, network, or `setTimeout` waits; suite green via `run-tests.sh`.
