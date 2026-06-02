# SQL Server Rules
> APPLIES ONLY IF `project.config.md → stack.database = sqlserver`.

### Stored procedures
- Begin with `SET NOCOUNT ON;` and `SET XACT_ABORT ON;` unless justified.
- Wrap multi-statement work in `BEGIN TRY … BEGIN CATCH` with proper rollback.
- Parameterize everything — no concatenated dynamic SQL; use `sp_executesql` with params.
- Schema-qualify all objects (`dbo.Table`, never bare `Table`).

### Triggers
- Most common source of cross-env failures — document every trigger's purpose in a header comment.
- Must handle multi-row operations — never assume single-row.
- If a trigger writes to another table, validate cascade behavior dev → UAT before deploy.

### Transactions
- Be explicit about transaction scope; don't rely on `IMPLICIT_TRANSACTIONS`.
- For long operations, batch in chunks; avoid table-wide locks.

### Migrations
- Every schema change has an idempotent script: `IF NOT EXISTS … CREATE`, `IF COL_LENGTH … ALTER`.
- Run order in every environment: dev → UAT → prod. No skipping.
- Diff schema between environments before any release.

### Cross-environment failures
- Works in dev but fails in UAT/prod → do NOT edit SP code first. Diagnose with `prompts/6-env-diff.md`; fix at schema/trigger/server-config level when possible.

### Naming
- Tables `PascalCase` (plural where natural). SPs `usp_<verb>_<noun>` (or project prefix, e.g. `asp_`).
- Indexes `IX_<Table>_<Cols>`; unique `UQ_<Table>_<Cols>`.
