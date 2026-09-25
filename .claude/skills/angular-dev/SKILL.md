---
name: angular-dev
description: "How to write Angular 21+ feature code: standalone, signals, zoneless-safe components, HTTP services + functional interceptors, lazy routes, typed or signal forms, i18n."
when_to_use: "Before writing or changing Angular components, services, routes or forms."
paths:
  - "**/*.component.ts"
  - "**/*.component.html"
  - "**/*.service.ts"
  - "**/*.routes.ts"
  - "**/app.config.ts"
  - "**/*.directive.ts"
  - "**/*.pipe.ts"
user-invocable: false
---
# Angular Development — modern, signal-first, zoneless-ready

Load this **before writing Angular feature code** (components, services, routes, forms, HTTP).
`rules/angular.md` holds the one-line non-negotiables; this is the how. Targets Angular 21+ —
check `@angular/core` in `package.json` and follow the **version notes** below.

## Version notes
| | Angular 21 | Angular 22+ |
|--|--|--|
| Change detection | set `changeDetection: ChangeDetectionStrategy.OnPush` | OnPush is the default — don't set it |
| Standalone | default since v20 — never write `standalone: true` | same |
| New forms | typed reactive forms | **Signal Forms** (`@angular/forms/signals`), else reactive |
| Singleton services | `@Injectable({ providedIn: 'root' })` | `@Service()` for new ones |

## Components
- **Standalone only** (no NgModules, no `standalone: true` flag), OnPush per the version notes,
  `input()` / `output()` functions — `model()` for two-way `[(prop)]` bindings, never an
  `input()` + `output()` pair. `inject()`, not constructor injection.
- Small, single-responsibility components; inline templates for small ones; external
  template/style paths relative to the component file.
- Host bindings in the decorator's `host: {}` object — no `@HostBinding` / `@HostListener`.
- Templates import only what they use (`DatePipe`, `AsyncPipe`) — never `CommonModule`.
  `[class.x]` / `[style.x]` bindings, not `ngClass` / `ngStyle`. `NgOptimizedImage` for static
  images (not inline base64).
- **Smart/dumb split** (`architecture-guard`): pages/containers inject services; presentational
  components take inputs, emit outputs, inject nothing.
- New control flow (`@if` / `@for` with `track item.id` / `@switch`); `@defer` for heavy,
  below-the-fold blocks.
- **Zoneless-safe:** state that drives the template lives in signals (or reaches it via
  `toSignal` / `async` pipe). Never rely on zone.js noticing a mutation or `setTimeout`.

## State
- Local state → `signal()`; derived → `computed()`; state that must stay in sync with several
  sources but stays writable → `linkedSignal()`; `update()` / `set()`, never `mutate`; `effect()` only for side effects that leave
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
- Angular 22+: **Signal Forms** for new forms (schema validation, typed field access). Otherwise
  typed reactive forms (`FormGroup<{…}>`, `nonNullable`) — never template-driven for new
  forms. Validators next to the form, errors
  shown per field and linked with `aria-describedby` (`accessibility`). Server-side validation
  errors (ProblemDetails `errors`) map back onto the matching control.

## i18n
- No hardcoded user-facing strings when the app is localized — use the project's i18n
  mechanism (`$localize` / `i18n` attributes or the existing library), placeholders not
  concatenation. Dates/numbers/currency through locale-aware pipes; timestamps stored in UTC.
  RTL: logical CSS properties (`margin-inline-start`), `dir` on the root.

## Ship-with
- [ ] OnPush (explicit on 21, default on 22+), signal inputs/outputs, no `any` (use `unknown`), no manual `subscribe` without `takeUntilDestroyed`.
- [ ] Loading / empty / error states rendered; stable `data-testid` on elements E2E will touch.
- [ ] Feature route lazy; HTTP only through services; interceptors hold cross-cutting logic.
- [ ] Specs written per `angular-testing`; verified with `bash scripts/run-tests.sh angular`.

_Aligned with Angular's official AI best practices (`angular/angular` →
`packages/core/resources/best-practices.md`, MIT)._
