# Java Rules
> APPLIES ONLY IF `project.config.md → stack.backend = java`.

- Follow the project's build (Maven/Gradle) and its formatter/checkstyle config — don't hand-format.
- Layer it: Controller → Service → Repository → Entity. Keep controllers thin.
- Constructor injection (Spring) — no field injection. Program to interfaces.
- Use `Optional` for absent values; never return `null` from public APIs. Avoid `null` arguments.
- Validate input at the boundary (Bean Validation `@Valid` / explicit checks).
- DTOs at the API boundary — don't expose JPA entities directly.
- Handle exceptions deliberately; no empty `catch` blocks. Use a global exception handler for APIs.
- Tests with JUnit 5 (+ Mockito) mirroring the package; cover service logic + one failure path.
- Verify before commit: `mvn -q verify` (or `gradle build`).
