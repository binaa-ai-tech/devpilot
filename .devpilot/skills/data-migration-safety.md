# Data-Migration Safety — schema changes that can't take prod down

Load this **before writing any DB migration** (backend / DB layer). The deploy pipeline rolls
forward through DEV→SIT→UAT→PRD with no downtime window — so migrations must be **backward
compatible** with the currently-running app, and **reversible**.

## Expand / contract (never break in one step)
Roll a breaking change across **two** deploys:
1. **Expand** — add the new column/table/index as **nullable / additive**. Old code ignores it; new code can use it. Backfill in batches, not one giant `UPDATE`.
2. **Migrate** — ship code that writes/reads the new shape; dual-write if needed.
3. **Contract** — only after all instances run the new code, drop the old column/constraint (a later deploy).

Renames = add-new + backfill + switch + drop-old. Never `RENAME`/`DROP` in the same release that needs the old name.

## Every migration must
- [ ] Be **reversible** — a real `Down`/rollback, tested, not a stub.
- [ ] Be **idempotent / re-runnable** — guard with `IF NOT EXISTS` etc.; safe if retried.
- [ ] Be **ordered** — sequential, no gaps; dev → UAT → prod apply in the same order.
- [ ] **Not lock hot tables** — add indexes online; batch large backfills; mind lock escalation (SQL Server).
- [ ] Be **separated from app deploy** when destructive — schema first, verified, then code.

## Red flags (stop and redesign)
`DROP COLUMN` / `DROP TABLE` in the same PR as the feature using it · non-nullable column with no
default on a populated table · unbatched `UPDATE`/`DELETE` over a big table · no `Down` · data
transform with no backup/rollback plan.
