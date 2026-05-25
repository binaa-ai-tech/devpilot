# AI Dev Team — How It Works

This project uses a team of specialized AI agents to handle development tasks end-to-end.

## Roles

| Role | Persona | Responsibilities |
|------|---------|-----------------|
| **Business Analyst** | Asks questions, writes specs | Clarifying questions, requirements docs, acceptance criteria |
| **Team Lead** | Plans and reviews | Jira tickets, branch creation, implementation plans, final code review, PR |
| **Frontend Developer** | Angular 21+ / React expert | UI components, services, Angular signals, SCSS, frontend tests |
| **.NET Developer** | C# / ASP.NET Core / SQL Server expert | APIs, services, repositories, DB migrations, backend tests |
| **QA Engineer** | Test coverage and verification | Test plans, missing test coverage, acceptance criteria verification, QA reports |

## Workflow

### Full Flow: `/team-task "description"`

```
Phase 1: BA
  └─ Asks 5–8 clarifying questions
  └─ Writes docs/requirements/<slug>.md

Phase 2: Team Lead
  └─ Creates Jira ticket
  └─ Creates feature branch
  └─ Writes docs/plans/<slug>.md

Phase 3: Implementation (parallel)
  ├─ Frontend Agent → implements UI, runs lint+build+test, commits
  └─ .NET Agent     → implements API/DB, runs build+test, commits

Phase 4: QA
  └─ Verifies acceptance criteria
  └─ Adds missing tests
  └─ Writes docs/qa/<slug>.md

Phase 5: Team Lead Review
  └─ Reviews diff against rules.md
  └─ Writes docs/reviews/<slug>.md
  └─ Opens PR → develop
```

### Standalone Commands

Use individual agent commands when you only need one phase:

```bash
/team-ba "Add a password reset flow"          # Just requirements
/team-lead docs/requirements/password-reset.md # Just planning
/team-frontend docs/plans/password-reset.md    # Just frontend impl
/team-dotnet docs/plans/password-reset.md      # Just backend impl
/team-qa docs/requirements/password-reset.md   # Just QA
```

## Output Docs

Every task generates four documents:

```
docs/
├── requirements/   # BA output — what to build
├── plans/          # Team Lead output — how to build it
├── qa/             # QA output — test results and coverage
└── reviews/        # Team Lead output — code review + PR body
```

## Rules All Agents Follow

All agents follow `.aidev/rules.md`. Key points:
- Angular: `OnPush`, `takeUntilDestroyed()`, signals, new control-flow syntax
- SQL: parameterized queries, idempotent migrations, `SET NOCOUNT ON`
- No `any` types, no magic strings, no secrets in code
- Tests live next to the code they test
