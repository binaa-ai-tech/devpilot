# EF Core + SQL Server — fast queries, migrations that can't take prod down

Load this **before writing a migration, a query / access pattern, or when an endpoint is slow on
real data.** Pairs with `rules/sqlserver.md` (stored procedures, triggers, naming).

## Migrations — backward compatible and reversible
The pipeline rolls DEV→SIT→UAT→PRD with no downtime window, so each migration must work with the
**currently running** app version.
- **Expand / contract** across two deploys: add new column/table as nullable/additive → ship code
  that uses it (backfill in batches) → drop the old shape in a **later** release. Renames are
  add + backfill + switch + drop, never `RENAME` in the release that still needs the old name.
- `dotnet ef migrations add <Name>`; review the generated file — EF will happily emit a
  `DropColumn` for a rename. Every migration has a real `Down`.
- Ship to environments as an **idempotent script** (`dotnet ef migrations script --idempotent`)
  or a migration bundle — never `Database.Migrate()` at app startup in production.
- Don't lock hot tables: create indexes `ONLINE = ON` where the edition allows (raw
  `migrationBuilder.Sql`), batch big `UPDATE`/`DELETE`, keep transactions short.
- **Red flags — stop and redesign:** drop in the same PR as the code change · non-nullable column
  without default on a populated table · unbatched update over a big table · no `Down`.

## Queries
- **Read paths:** `AsNoTracking()`, project straight to DTOs with `Select(...)` — no loading whole
  entities to map later, no `SELECT *`.
- **Kill N+1:** no queries inside loops; use a projection, `Include`, or one `IN` query. Use
  `AsSplitQuery()` when multiple collection `Include`s explode the row count.
- Filter, sort, and aggregate **in SQL** — never `ToList()` then filter in memory. Watch for
  client-evaluation and implicit conversions (`nvarchar` vs `varchar` params kill index seeks).
- **Paginate** everything that lists; prefer keyset (`WHERE Id > @last ORDER BY Id`) for deep pages.
- Bulk changes: `ExecuteUpdateAsync` / `ExecuteDeleteAsync` instead of load-modify-save loops.
- Raw SQL only via `FromSql` / `SqlQuery` with interpolated **parameters** — never string concat.
- Concurrency-sensitive rows get a `rowversion` concurrency token; handle `DbUpdateConcurrencyException` → 409.

## Indexes
- Index what you **filter, join, and sort** on; FK columns always. Composite order: equality
  columns first, then range/sort (`(TenantId, CreatedAt)`); `INCLUDE` columns to cover hot reads.
- Check the actual plan on realistic volume (log the SQL with `ToQueryString()`), not 10 rows.
- Unused indexes are pure write cost — don't add speculatively.

## Ship-with
- [ ] Migration additive, reversible, idempotent script reviewed; no destructive step alongside code.
- [ ] Read queries no-tracking + projected; no N+1; lists paginated; no in-memory filtering.
- [ ] Indexes for new filter/join/FK columns; plan checked on representative data.
- [ ] Data-access tested against real SQL Server (Testcontainers — `dotnet-testing`), not the InMemory provider.
