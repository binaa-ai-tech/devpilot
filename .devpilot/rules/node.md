# Node / TypeScript Backend Rules
> APPLIES ONLY IF `project.config.md → stack.backend = node`.

- TypeScript strict mode; no `any` (use `unknown` + narrowing). Declare return types on exported functions.
- Layer it: route/controller → service → repository/data. Keep handlers thin.
- Validate request input at the edge (zod / joi / class-validator) — never trust the body.
- `async`/`await` with proper error propagation; no unhandled promise rejections. Centralize error handling middleware.
- Config from environment (`process.env`) via a typed config module — no secrets in code.
- Use the project's existing framework conventions (Express/Nest/Fastify) — don't introduce a new one.
- Tests with the project runner (Jest/Vitest/node:test) next to the code; cover happy path + one error path.
- Build + test before commit: `npm run build` (if present) && `npm test`.
