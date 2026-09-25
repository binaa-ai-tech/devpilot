# Angular Development — modern, signal-first, zoneless-ready

Load this **before writing Angular feature code** (components, services, routes, forms, HTTP).
`rules/angular.md` holds the one-line non-negotiables; this is the how. Targets Angular 21+.

## Components
- **Standalone only**, `ChangeDetectionStrategy.OnPush`, signal `input()` / `output()` / `model()`.
- **Smart/dumb split** (`architecture-guard`): pages/containers inject services; presentational
  components take inputs, emit outputs, inject nothing.
- New control flow (`@if` / `@for` with `track item.id` / `@switch`); `@defer` for heavy,
  below-the-fold blocks.
- **Zoneless-safe:** state that drives the template lives in signals (or reaches it via
  `toSignal` / `async` pipe). Never rely on zone.js noticing a mutation or `setTimeout`.

## State
- Local state → `signal()`; derived → `computed()`; `effect()` only for side effects that leave
  Angular (storage, logging, a third-party widget) and never to copy one signal into another.
- Shared state → a `providedIn: 'root'` (or route-scoped) service exposing **read-only** signals
  (`asReadonly()`) and intent methods (`addItem()`), never a public writable signal.
- Server data → `resource()` / `httpResource()` where the project uses them, else a service that
  calls `HttpClient` and exposes `{ data, loading, error }` signals. Every view handles
  **loading, empty, and error** states.

## HTTP
- One typed service per API area; return typed DTOs (ideally the generated client — `api-contract`).
- Cross-cutting concerns go in **functional interceptors** (`HttpInterceptorFn`): auth header,
  correlation id, error → user message. Components never build URLs or headers.
- Base URLs come from environment config, never hardcoded.

## Routing
- Every feature is **lazy** (`loadComponent` / `loadChildren`); guards and resolvers are
  functional (`CanActivateFn`); route params bound via `withComponentInputBinding()`.

## Forms
- Typed reactive forms (`FormGroup<{…}>`, `nonNullable`), validators next to the form, errors
  shown per field and linked with `aria-describedby` (`accessibility`). Server-side validation
  errors (ProblemDetails `errors`) map back onto the matching control.

## i18n
- No hardcoded user-facing strings when the app is localized — use the project's i18n
  mechanism (`$localize` / `i18n` attributes or the existing library), placeholders not
  concatenation. Dates/numbers/currency through locale-aware pipes; timestamps stored in UTC.
  RTL: logical CSS properties (`margin-inline-start`), `dir` on the root.

## Ship-with
- [ ] OnPush, signal inputs/outputs, no `any`, no manual `subscribe` without `takeUntilDestroyed`.
- [ ] Loading / empty / error states rendered; stable `data-testid` on elements E2E will touch.
- [ ] Feature route lazy; HTTP only through services; interceptors hold cross-cutting logic.
- [ ] Specs written per `angular-testing`; verified with `bash scripts/run-tests.sh angular`.
