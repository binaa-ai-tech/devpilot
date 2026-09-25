# Angular (21+) Rules
> APPLIES ONLY IF `project.config.md → stack.frontend = angular`.

### Subscriptions
- Always use `takeUntilDestroyed()` for cleanup. Never manual `unsubscribe()` without a documented reason.
- `inject(DestroyRef)` at field initialization, pass to `takeUntilDestroyed`.

### Change detection
- `ChangeDetectionStrategy.OnPush` on every new component. Default is forbidden.
- Use signals (`signal`, `computed`, `effect`) for reactive state in new code.
- For collections, always provide a `trackBy` / `@for` track expression.

### Typing
- Strict mode `true`. No `noImplicitAny` opt-outs.
- Inputs/outputs use signal syntax: `input<T>()`, `output<T>()`.
- Service methods declare explicit return types.

### Templates
- New control-flow only: `@if`, `@for`, `@switch`. No `*ngIf` / `*ngFor` in new code.
- No logic in templates beyond simple property access — move to `computed()`/methods.
- Sanitize `[innerHTML]` through `DomSanitizer`.

### State / DI / Styling
- Services `providedIn: 'root'` unless feature-scoped. No `BehaviorSubject` for new state — prefer signals.
- SCSS only, design tokens (`$primary`, `$radius-md`). No hardcoded hex/px, no inline styles.

### HTTP / API
- HTTP only in services; cross-cutting concerns in functional interceptors. Use the client generated from the
  committed OpenAPI spec when one exists — no hand-written duplicate DTOs (`skills/api-contract.md`).
- Every data view renders loading, empty, and error states.

### Testing
- One `*.spec.ts` per new component/service (Vitest via `ng test`); cover rendering + one interaction/branch.
  `TestBed` with standalone imports; HTTP through `HttpTestingController` (`skills/angular-testing.md`).
- Elements a Playwright journey will touch get a `data-testid` or an accessible name (`skills/ui-e2e-playwright.md`).
- Run suites via `bash scripts/run-tests.sh angular` — never paste the raw log into context.
