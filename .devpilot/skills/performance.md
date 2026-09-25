# Performance — review the code, then prove the budget

Two passes. **Code review** (before every commit with queries, loops, rendering, or state) and
**performance testing** (when an AC carries a performance requirement, before a major release, or
on `/dp-test perf`). Database depth lives in `efcore-sqlserver`.

## Part 1 — Code checklist

### Angular
- [ ] `OnPush` everywhere; `@for` tracks a stable id (never `$index` on mutable lists).
- [ ] No method calls in templates that run every cycle — `computed()` or a pure pipe.
- [ ] Feature routes lazy; `@defer` for heavy below-the-fold blocks; no large new dependency
      without justification (check the bundle budget in `angular.json`).
- [ ] Search/filter inputs debounced (≥ 300 ms) before calling the API; lists paginated or virtualized.
- [ ] Images: `NgOptimizedImage` or `loading="lazy"` + explicit `width`/`height`.

### .NET / SQL Server
- [ ] No N+1; read queries `AsNoTracking()` + projected; no `SELECT *`; lists paginated.
- [ ] Indexes for new filter/join/FK columns (in the migration).
- [ ] Fully async I/O — zero `.Result`, `.Wait()`, `.GetAwaiter().GetResult()`.
- [ ] `HttpClient` via `IHttpClientFactory` with timeouts; no `new HttpClient()` per call.
- [ ] Hot, rarely-changing reference data cached (`IMemoryCache` / `HybridCache`) with expiry.

### Severity
- 🔴 **BLOCKER**: N+1 on a hot path, blocking async call, unbounded list response, missing FK index.
- 🟡 **WARNING**: eager route, no debounce, `SELECT *` on a large table, uncached hot lookup.

## Part 2 — Performance testing

### Budgets first
Take budgets from the requirements; when silent, hold these and record them in the QA report:

| Surface | Budget |
|---------|--------|
| API reads | p95 < 300 ms, p99 < 1 s at target load |
| API writes | p95 < 800 ms |
| Error rate | < 0.1 % at target load |
| Web vitals | LCP < 2.5 s · INP < 200 ms · CLS < 0.1 |
| Throughput | expected peak × 2 without the knee |

### How
- **k6** is the default for APIs (scripts under `perf/`, versioned like code). Web vitals via
  Lighthouse CI or Playwright + the `web-vitals` library on the key pages.
- Test a prod-like environment with **realistic data volume**; never load-test PRD.
- **Smoke** (1 VU, always) · **Load** (expected peak, 10–15 min, for hot-path changes) ·
  **Stress** (find the knee) · **Soak** (leaks) · **Spike** (recovery).
- Report **percentiles, never averages**; warm up first; pin dataset + duration so runs compare.

### Gate
A budget violation on a hot path is a 🔴 **BLOCKER** in the QA report — attach the numbers
(baseline vs. now, percentile table), not adjectives.
