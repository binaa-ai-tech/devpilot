# Dev Process — AI Team System

This repository defines the development workflow for AI-assisted projects. It combines:

1. **`.aidev/`** — classic single-agent workflow (prompts, rules, templates)
2. **`.claude/commands/team-*`** — multi-agent AI dev team (new)

## CEO Entry Point

| Command | What it does |
|---------|-------------|
| `/ceo <description>` | Submit any task — auto-classifies as feature/bug/hotfix, runs the full team, delivers PR with status report and next steps |

This is the primary command. Use it to delegate any feature, bug, or production emergency.

## AI Team Commands

| Command | Role | When to Use |
|---------|------|-------------|
| `/team-task <description>` | Full team workflow | Used by `/ceo` internally — or run directly for more control |
| `/team-ba <description>` | Business Analyst only | Just need requirements written |
| `/team-lead <context>` | Team Lead only | Planning or review only |
| `/team-frontend <context>` | Frontend Developer only | UI work only |
| `/team-dotnet <context>` | .NET Developer only | Backend work only |
| `/team-qa <context>` | QA Engineer only | Testing only |

## Team Workflow (Full)

```
/ceo "description"  →  /team-task
      │
      ▼
[BA] Clarifying questions → docs/requirements/<slug>.md
      │
      ▼
[Team Lead] Plans + creates ticket + branch → docs/plans/<slug>.md
      │
      ├──────────────────────────┐
      ▼                          ▼
[Frontend Dev]              [.NET Dev]
Angular/React impl          API/service/DB impl
      │                          │
      └──────────┬───────────────┘
                 ▼
            [QA Agent]
        Test plan + tests → docs/qa/<slug>.md
                 │
                 ▼
          [Team Lead]
        Review + PR → docs/reviews/<slug>.md
```

## Deploy Pipeline Commands

| Command | When to run |
|---------|-------------|
| `/binaa-sit <version>` | DEV tested → promote to SIT (e.g. `/binaa-sit 1.1.0`) |
| `/binaa-uat` | SIT passed → approve UAT gate |
| `/binaa-prd <version>` | UAT signed off → deploy to production |
| `/binaa-hotfix <n> <slug> <version>` | Production emergency |
| `/binaa-dev <type>: <description>` | Developer-assisted flow (uses opencode) |

## Tech Stack

- **Frontend:** Angular 21+ / React
- **Backend:** .NET (C#), SQL Server
- **Rules:** `.aidev/rules.md` governs all agent-written code

## Docs Output per Task

| Document | Path | Written By |
|----------|------|------------|
| Requirements | `docs/requirements/<slug>.md` | BA |
| Implementation Plan | `docs/plans/<slug>.md` | Team Lead |
| QA Report | `docs/qa/<slug>.md` | QA Engineer |
| Review Report | `docs/reviews/<slug>.md` | Team Lead |

## Power Skills (All Agents)

Every agent loads applicable skills from `.aidev/skills/`:

| Skill | File | Applied By |
|-------|------|------------|
| Autonomous execution | `get-shit-done.md` | All agents |
| Security scanning | `security-scan.md` | Frontend Dev, .NET Dev, Team Lead |
| Performance review | `performance-review.md` | Frontend Dev, .NET Dev, Team Lead |
| Architecture guardrails | `architecture-guard.md` | Team Lead, .NET Dev, Frontend Dev |
| Self-healing | `self-heal.md` | All implementation agents |
| Definition of Done gate | `definition-of-done.md` | All agents |

## Additional Docs per Task

| Document | Path | Written By |
|----------|------|------------|
| Domain Model | `docs/domain-models/<slug>.md` | BA |
| Architecture Decision Records | `docs/adrs/ADR-<N>-<slug>.md` | Team Lead |
