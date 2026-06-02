# Database Performance — indexes, queries, and access patterns

Load this **before writing queries, designing how code reads/writes a table, or when an
endpoint is slow on real data.** The deep-dive behind `performance-review`'s DB line;
`data-migration-safety` covers *changing* schema safely, this covers making it *fast*.

## Index what you query
- **Index the columns you filter, join, and sort on** — not every column. An index that no query
  uses is pure write-cost.
- **Composite index column order matters:** equality columns first, then the range/sort column
  (`WHERE tenant=? AND created>?` → index `(tenant, created)`).
- **Read the plan** (`EXPLAIN`/`EXPLAIN ANALYZE`) on realistic data volumes — not 10 rows. Look
  for full table scans on big tables and the wrong index being chosen.

## Query shape
- **Kill N+1** — one query with a join / `IN` / eager-load, not one query per row in a loop.
- **Select only the columns you need** — no `SELECT *`; it bloats I/O and breaks covering indexes.
- **Paginate**; for deep pages prefer **keyset/seek** pagination over large `OFFSET`.
- Push filtering/aggregation into the DB; don't pull rows to filter in app code.

## Don't create new problems
- **Over-indexing slows writes** and bloats storage — index selectively and drop unused ones.
- **Keep transactions short**; avoid long locks and lock-order deadlocks under concurrency.
- Use **connection pooling**; don't open a connection per call.

## Ship-with
- [ ] Filter/join/sort columns indexed; plan checked on representative data (no surprise scans).
- [ ] No N+1; queries select needed columns and paginate large result sets.
- [ ] No needless indexes added; transactions short, connections pooled.
