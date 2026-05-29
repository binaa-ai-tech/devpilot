# Core Rules — the essentials every agent follows

> Read this once at spawn. It replaces re-reading several long skill files.
> Stack-specific rules live in `.devpilot/rules/<stack>.md` — read only yours.

1. **No pauses.** Make reasonable assumptions; document them. Never ask
   "should I continue?".
2. **One concern per commit.** Conventional message: `feat|fix|chore(scope): …`.
3. **Tests live next to the code** and cover the happy path + one edge/error
   branch for each acceptance criterion you implement.
4. **No secrets in code.** Use environment configuration.
5. **No dead code / commented-out blocks.** Git remembers.
6. **No magic numbers or strings.** Extract named constants.
7. **Strong typing.** No `any`/untyped escapes; declare return types.
8. **Stay in scope.** Touch only files the plan names for your layer.
9. **Always end with verification** — run the stack's build + tests; never
   leave the build red.
10. **Reach for heavier skills on demand only** — `self-heal` on a failure,
    `security-scan` on auth/input handling, `architecture-guard` on structural
    change. Don't pre-load them.
11. **Process logging — two altitudes, no echo.** The blow-by-blow lives in the
    repo, not the ticket:
    - **`docs/tasks/<KEY>.md`** is the live per-step log — append who/what/when,
      decisions, and deviations as you go. This is the durable, diffable audit.
    - **Jira gets exactly two routine comments:** a **start** comment (branch,
      scope, engine, intent) and a **DONE** summary (what shipped as bullets, PR
      link, QA verdict, duration). Status transitions track real phases
      (`In Progress → In Review/Done`).
    - **Do not post routine progress comments** (plan-complete, impl-complete,
      QA-passed, merged) — they restate the PR and the DONE block and bury the
      summary. **Exception:** a **QA BLOCKED** (or hard-failure) state _is_ worth
      a comment, because it's an exception, not narration.
    - Technical detail belongs in the **PR description**; the ticket links to it.
