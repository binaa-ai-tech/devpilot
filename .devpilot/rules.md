# Code Rules — Router

> Single source of truth for rules, split so each agent reads only what applies.
>
> **Every agent:** read `.devpilot/skills/core-rules.md` first (the universal
> essentials). Then read ONLY the stack snippet(s) below that match your
> project's `project.config.md → stack`. Ignore the rest.

## Which snippet to read

| If `stack.` … is | Read |
|------------------|------|
| `frontend: angular` | `.devpilot/rules/angular.md` |
| `frontend: react` / `vue` / `nextjs` | `.devpilot/rules/react-vue.md` |
| `backend: dotnet` | `.devpilot/rules/dotnet.md` |
| `backend: node` | `.devpilot/rules/node.md` |
| `backend: python` | `.devpilot/rules/python.md` |
| `backend: go` | `.devpilot/rules/go.md` |
| `backend: java` | `.devpilot/rules/java.md` |
| `database: sqlserver` | `.devpilot/rules/sqlserver.md` |
| `database: postgres` / `mysql` | `.devpilot/rules/postgres-mysql.md` |

> Any other stack: follow `core-rules.md` + the project's existing conventions
> (its lint config, CI, and neighboring code).

---

## Bug fixes (extra rules — all stacks)
- **Reproduce first.** No fix without a written repro.
- **Add a regression test.** Fails before, passes after.
- **Root cause documented** in the PR — the cause, not just the symptom.

## Hotfixes (production emergencies)
- Branch from the deployed tag, not `main`.
- Minimum diff. No refactoring, no unrelated improvements.
- Test on UAT before prod even under pressure.
- Post-incident: cherry-pick or merge back into `main`.

## AI prompt rules (when briefing a coding tool)
1. Reference `.devpilot/skills/core-rules.md` + the relevant stack snippet.
2. Be autonomous — no "should I continue?" pauses.
3. State which files/dirs are in/out of scope.
4. End with a verification step (build / test / lint).
