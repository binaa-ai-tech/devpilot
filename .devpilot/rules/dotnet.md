# .NET / C# Rules
> APPLIES ONLY IF `project.config.md → stack.backend = dotnet`.

- Clean architecture: Controller → Service/Handler → Repository → Entity. Never skip a layer.
- Prefer CQRS handlers (`*Command`, `*Query`, `*Handler`) where the project already uses them.
- DTOs at the boundary — never expose entities directly from controllers.
- `async`/`await` all the way down for I/O; no `.Result` / `.Wait()` (deadlock risk).
- Dependency injection via the built-in container; constructor injection only.
- Nullable reference types enabled; no `!` null-forgiving without justification.
- Validate input with FluentValidation or data annotations at the API edge.
- Tests: xUnit/NUnit next to or mirroring the code; cover handler logic + one failure branch.
- Build + test before commit: `dotnet build` && `dotnet test`.
