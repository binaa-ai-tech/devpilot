# PostgreSQL / MySQL Rules
> APPLIES ONLY IF `project.config.md → stack.database` is `postgres` or `mysql`.

- Every schema change ships as a migration via the project's tool (Prisma/TypeORM/Alembic/Flyway/EF). Never hand-edit a live schema.
- Migrations are reversible (or have a documented forward-only reason) and idempotent where the tool allows.
- Parameterized queries only — never string-concatenate user input (SQL injection).
- Add indexes for foreign keys and frequent filter/sort columns; name them `ix_<table>_<cols>`.
- Use transactions for multi-statement writes; keep them short to avoid lock contention.
- Prefer explicit column lists over `SELECT *` in application queries.
- Naming: `snake_case` tables/columns (Postgres convention) unless the project already uses another style — match the project.
- Run the migration against a dev DB and the test suite before committing.
