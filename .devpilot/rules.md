# Code Rules — Single Source of Truth

> Every AI prompt in this repo must respect these rules. Update here, not in individual prompts.
>
> **Stack-specific sections** (Angular, SQL Server, etc.) apply ONLY if that technology
> is detected in `project.config.md → stack`. Read the stack section for your project only.
> An agent working on a Python/React project must ignore the Angular and SQL Server sections.

---

## Universal (all stacks)

- **No `any` type.** Use proper types or `unknown` with narrowing.
- **No clarifying-question pauses in AI prompts.** Make reasonable assumptions; document them in code comments or PR description.
- **One concern per commit.** No mixed-purpose commits.
- **No commented-out code.** Delete it; git remembers.
- **No magic numbers / strings.** Extract to named constants.
- **Tests live next to code.** `*.spec.ts` beside the file it tests.
- **No secrets in code.** Use environment configuration.

---

## Angular (21+)
> **APPLIES ONLY IF:** `project.config.md → stack.frontend = angular`
> Skip this entire section if the project uses React, Vue, Next.js, or no frontend.

### Subscriptions

- **Always use `takeUntilDestroyed()`** for subscription cleanup. Never `unsubscribe()` manually unless there's a documented reason.
- `inject(DestroyRef)` at field initialization, pass to `takeUntilDestroyed`.

```ts
private destroyRef = inject(DestroyRef);

ngOnInit() {
  this.service.data$
    .pipe(takeUntilDestroyed(this.destroyRef))
    .subscribe(...);
}
```

### Change detection

- **`ChangeDetectionStrategy.OnPush` on every new component.** Default is forbidden.
- Use signals (`signal`, `computed`, `effect`) for reactive state in new code.
- For collection rendering, always provide `trackBy` or use `@for` track expression.

### Typing

- Strict mode `true` in `tsconfig.json`. No `noImplicitAny` opt-outs.
- Component inputs/outputs use the new signal-input syntax: `input<T>()`, `output<T>()`.
- Service methods declare return types explicitly.

### Templates

- Use the new control-flow syntax: `@if`, `@for`, `@switch`. No `*ngIf` / `*ngFor` in new code.
- No logic in templates beyond simple property access. Move to `computed()` or methods.
- Sanitize any HTML binding (`[innerHTML]`) through `DomSanitizer`.

### State / DI

- Services use `providedIn: 'root'` unless feature-scoped.
- No `BehaviorSubject` for new state — prefer signals.

### Styling

- SCSS only. Use design tokens from the project's design system (e.g. `$primary`, `$radius-md`). No hardcoded hex/px in components.
- No inline styles in templates.

### Testing

- Minimum: one `*.spec.ts` per new component/service.
- Cover: rendering + at least one interaction or business-logic branch.
- Use `TestBed` with standalone component imports.

---

## SQL Server
> **APPLIES ONLY IF:** `project.config.md → stack.database = sqlserver`
> Skip this entire section if the project uses PostgreSQL, MySQL, or no database.

### Stored procedures

- Begin with `SET NOCOUNT ON;` and `SET XACT_ABORT ON;` unless explicitly justified.
- Wrap multi-statement work in `BEGIN TRY ... BEGIN CATCH` with proper rollback.
- Parameterize everything. No dynamic SQL via concatenation — use `sp_executesql` with parameters.
- Schema-qualify all object references (`dbo.Table`, never bare `Table`).

### Triggers

- **Triggers are the most common source of cross-env failures.** Document every trigger's purpose in a header comment.
- Triggers must handle multi-row operations — never assume single-row.
- If a trigger writes to another table, validate cascade behavior in dev → UAT before deploy.

### Transactions

- Be explicit about transaction scope. Don't rely on session-level `IMPLICIT_TRANSACTIONS`.
- For long operations, batch in chunks; avoid table-wide locks.

### Migrations

- Every schema change has an idempotent migration script: `IF NOT EXISTS ... CREATE`, `IF COL_LENGTH ... ALTER`.
- Migrations run in this order in every environment: dev → UAT → prod. No skipping.
- Diff schema between environments before any release.

### Cross-environment failures

- When something works in dev but fails in UAT/prod, do NOT modify SP code first. Diagnose using the env-diff prompt (`prompts/6-env-diff.md`) — fix at schema/trigger/server-config level when possible.

### Naming

- Tables: `PascalCase`, plural where natural.
- SPs: `usp_<verb>_<noun>` or project convention (e.g. `asp_` for app prefix).
- Indexes: `IX_<Table>_<Cols>`. Unique: `UQ_<Table>_<Cols>`.

---

## Bug fixes (extra rules)

- **Reproduce first.** No fix without a written repro in the ticket.
- **Add a regression test.** No fix merged without a test that fails before, passes after.
- **Root cause documented.** PR description must state the cause, not just the symptom.

---

## Hotfixes (production emergencies)

- Branch from the deployed tag, not `main`.
- Minimum diff. No refactoring, no unrelated improvements.
- Test on UAT before prod even under pressure.
- Post-incident: cherry-pick or merge back into `main`.

---

## AI prompt rules

Every prompt sent to an AI coding tool must:

1. Reference this file: "Follow the rules in `.devpilot/rules.md`."
2. Be **autonomous** — no "should I continue?" pauses.
3. State which files/dirs are in/out of scope.
4. End with a verification step (run tests / build / lint).
