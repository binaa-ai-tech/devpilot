# .NET / C# Rules
> APPLIES ONLY IF `project.config.md → stack.backend = dotnet`.

- Clean architecture: Controller → Service/Handler → Repository → Entity. Never skip a layer.
- Prefer CQRS handlers (`*Command`, `*Query`, `*Handler`) where the project already uses them.
- DTOs at the boundary — never expose entities directly from controllers.
- `async`/`await` all the way down for I/O; no `.Result` / `.Wait()` (deadlock risk).
- Dependency injection via the built-in container; constructor injection only.
- Nullable reference types enabled; no `!` null-forgiving without justification.
- Validate input with FluentValidation or data annotations at the API edge.
- Errors as RFC 7807 ProblemDetails; `CancellationToken` passed through every async call.
- EF Core reads: `AsNoTracking()` + projection to DTOs; no N+1; lists paginated (`.claude/skills/efcore-sqlserver/SKILL.md`).
- Migrations additive + reversible; ship as `dotnet ef migrations script --idempotent`, never `Migrate()` on prod startup.
- OpenAPI spec regenerated and committed with every contract change (`.claude/skills/api-contract/SKILL.md`).
- Tests: xUnit mirroring the code; unit tests for handlers + one failure branch; integration tests per endpoint
  with `WebApplicationFactory` on real SQL Server via Testcontainers — never the EF InMemory provider (`.claude/skills/dotnet-testing/SKILL.md`).
- Build + test before commit via `bash scripts/run-tests.sh dotnet`.
