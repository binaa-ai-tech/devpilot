# Skill: Performance Review

Check before every commit. Flag issues in the review doc.

## Frontend

### Change detection & rendering
- [ ] All new Angular components use `ChangeDetectionStrategy.OnPush`
- [ ] `@for` track expression uses a stable unique identifier — never `track $index` for mutable lists
- [ ] No method calls in templates that execute on every change detection cycle — use `computed()` or `pipe`
- [ ] `async` pipe or `toSignal()` used instead of manual subscriptions where possible

### Bundle & loading
- [ ] No new large dependencies added without documented justification
- [ ] Feature routes are lazy-loaded (not eagerly imported in root module / app.config)
- [ ] Images below the fold have `loading="lazy"` and explicit `width`/`height`
- [ ] Search/filter inputs debounced (≥ 300 ms) before triggering API calls

### Network
- [ ] API responses for list endpoints are paginated — no endpoint returning unbounded arrays

## Backend

### Database
- [ ] No N+1 query patterns — use `.Include()` / explicit joins when loading related data
- [ ] Every new foreign key column has a corresponding index in the migration script
- [ ] `WHERE` clause columns on frequently-queried tables have supporting indexes
- [ ] No `SELECT *` — only select the columns needed for the operation
- [ ] Large data operations are paginated or batched

### .NET runtime
- [ ] All I/O operations are `async`/`await` — zero `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()` blocking calls
- [ ] `HttpClient` is injected via DI (`IHttpClientFactory`) — never instantiated with `new HttpClient()`
- [ ] Frequently-read, rarely-changed reference data has a caching layer (in-memory or distributed)

## Severity
- 🔴 **BLOCKER**: N+1 on a hot path, blocking async call (`.Result`), unbounded list response, missing FK index
- 🟡 **WARNING**: missing lazy-load route, no debounce on search, `SELECT *` on a large table
