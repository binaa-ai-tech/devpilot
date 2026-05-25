# AI Dev Team — How It Works

This project uses a team of specialized AI agents to handle development tasks end-to-end.

## Roles

| Role | Responsibilities |
|------|-----------------|
| **Business Analyst** | Asks clarifying questions, writes requirements docs, defines acceptance criteria |
| **Team Lead** | Creates Jira tickets, plans branches, writes implementation plans, final code review, opens PR |
| **Frontend Developer** | Angular 21+ / React components, services, SCSS, frontend unit tests |
| **.NET Developer** | C# APIs, ASP.NET Core services, SQL Server migrations, backend unit/integration tests |
| **QA Engineer** | Test plans, missing test coverage, acceptance criteria verification, QA reports |

## Full Workflow: `/team-task "description"`

```
Phase 1 — BA
  └─ Asks 5–8 clarifying questions → waits for answers
  └─ Writes docs/requirements/<slug>.md

Phase 2 — Team Lead
  └─ Creates Jira ticket + feature branch
  └─ Writes docs/plans/<slug>.md

Phase 3 — Implementation (parallel when full-stack)
  ├─ Frontend Agent → UI, tests, lint+build, commit
  └─ .NET Agent     → API/DB, tests, build, commit

Phase 4 — QA
  └─ Verifies every acceptance criterion
  └─ Adds missing test coverage
  └─ Writes docs/qa/<slug>.md

Phase 5 — Team Lead Review
  └─ Reviews diff against .aidev/rules.md
  └─ Writes docs/reviews/<slug>.md
  └─ Opens PR → develop
```

## Standalone Commands

Use individual agent commands when you only need one phase:

```
/team-ba "Add a password reset flow"           # Requirements only
/team-lead docs/requirements/password-reset.md # Planning only
/team-frontend docs/plans/password-reset.md    # Frontend impl only
/team-dotnet docs/plans/password-reset.md      # Backend impl only
/team-qa docs/requirements/password-reset.md   # QA only
```

## Output Docs per Task

```
docs/
├── requirements/<slug>.md   ← BA output: what to build
├── plans/<slug>.md          ← Team Lead output: how to build it
├── qa/<slug>.md             ← QA output: test results & coverage
└── reviews/<slug>.md        ← Team Lead output: code review & PR body
```

## Rules All Agents Follow

All agents enforce `.aidev/rules.md`. Key rules:
- Angular: `OnPush`, `takeUntilDestroyed()`, signals, `@if`/`@for` control flow
- SQL: parameterized queries, idempotent migrations, `SET NOCOUNT ON; SET XACT_ABORT ON;`
- No `any` types, no magic strings, no secrets in code
- Tests live next to the code they test (`*.spec.ts` / `*.test.tsx`)
