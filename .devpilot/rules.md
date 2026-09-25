# Code Rules — Router

> Single source of truth for rules, split so each agent reads only what applies.
> DevPilot targets **Angular** frontends and **.NET (ASP.NET Core) + SQL Server** backends.
>
> **Every agent:** read `.claude/skills/core-rules/SKILL.md` first (the universal
> essentials). Then read ONLY the stack snippet(s) below that match your layer.

## Which snippet to read

| Layer | Read |
|-------|------|
| Frontend (`stack.frontend: angular`) | `.devpilot/rules/angular.md` |
| Backend (`stack.backend: dotnet`) | `.devpilot/rules/dotnet.md` |
| Database (`stack.database: sqlserver`) | `.devpilot/rules/sqlserver.md` |

> Anything outside these stacks: follow `core-rules` + the project's existing
> conventions (its lint config, CI, and neighboring code).

---

## Bug fixes (extra rules)
- **Reproduce first.** No fix without a written repro.
- **Add a regression test.** Fails before, passes after.
- **Root cause documented** in the PR — the cause, not just the symptom.

## Hotfixes (production emergencies)
- Branch from the deployed tag, not `main`.
- Minimum diff. No refactoring, no unrelated improvements.
- Test on UAT before prod even under pressure.
- Post-incident: cherry-pick or merge back into `main`.

## AI prompt rules (when briefing a coding tool)
1. Reference `.claude/skills/core-rules/SKILL.md` + the relevant stack snippet.
2. Be autonomous — no "should I continue?" pauses.
3. State which files/dirs are in/out of scope.
4. End with a verification step: `bash scripts/run-tests.sh <angular|dotnet|e2e|all>`.
