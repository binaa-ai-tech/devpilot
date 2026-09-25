# Angular (21+) Rules
> APPLIES ONLY IF `project.config.md → stack.frontend = angular`.

### Subscriptions
- Always use `takeUntilDestroyed()` for cleanup. Never manual `unsubscribe()` without a documented reason.
- `inject(DestroyRef)` at field initialization, pass to `takeUntilDestroyed`.

### Change detection
- OnPush everywhere: set `ChangeDetectionStrategy.OnPush` explicitly on Angular 21; on 22+ it is the default — don't set it.
- Use signals (`signal`, `computed`, `effect`) for reactive state in new code.
- For collections, always provide a `trackBy` / `@for` track expression.

### Typing
- Strict mode `true`. No `noImplicitAny` opt-outs.
- Inputs/outputs use signal syntax: `input<T>()`, `output<T>()`, `model<T>()` for two-way binding. `inject()`, not constructor injection.
- No `standalone: true` (default), no `@HostBinding`/`@HostListener` (use `host: {}`), no `CommonModule`, `ngClass` or `ngStyle`.
- Service methods declare explicit return types.

### Templates
- New control-flow only: `@if`, `@for`, `@switch`. No `*ngIf` / `*ngFor` in new code.
- No logic in templates beyond simple property access — move to `computed()`/methods.
- Sanitize `[innerHTML]` through `DomSanitizer`.

### State / DI / Styling
- New forms: Signal Forms on 22+, typed reactive forms otherwise — never template-driven.
- Services `providedIn: 'root'` (or `@Service()` on 22+) unless feature-scoped. No `BehaviorSubject` for new state — prefer signals.
- SCSS only, design tokens (`$primary`, `$radius-md`). No hardcoded hex/px, no inline styles.

### HTTP / API
- HTTP only in services; cross-cutting concerns in functional interceptors. Use the client generated from the
  committed OpenAPI spec when one exists — no hand-written duplicate DTOs (`.claude/skills/api-contract/SKILL.md`).
- Every data view renders loading, empty, and error states.

### Testing
- One `*.spec.ts` per new component/service (Vitest via `ng test`); cover rendering + one interaction/branch.
  `TestBed` with standalone imports; HTTP through `HttpTestingController` (`.claude/skills/angular-testing/SKILL.md`).
- Elements a Playwright journey will touch get a `data-testid` or an accessible name (`.claude/skills/ui-e2e-playwright/SKILL.md`).
- Run suites via `bash scripts/run-tests.sh angular` — never paste the raw log into context.
