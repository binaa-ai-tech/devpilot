# Dev Process — AI Team System

This repository defines the development workflow for Maskan projects. It combines:

1. **`.aidev/`** — classic single-agent workflow (prompts, rules, templates)
2. **`.claude/commands/team-*`** — multi-agent AI dev team (new)

## AI Team Commands

| Command | Role | When to Use |
|---------|------|-------------|
| `/team-task <description>` | Full team workflow | Start any feature, bug, or story end-to-end |
| `/team-ba <description>` | Business Analyst only | Just need requirements written |
| `/team-lead <context>` | Team Lead only | Planning or review only |
| `/team-frontend <context>` | Frontend Developer only | UI work only |
| `/team-dotnet <context>` | .NET Developer only | Backend work only |
| `/team-qa <context>` | QA Engineer only | Testing only |

## Team Workflow (Full)

```
/team-task "description"
      │
      ▼
[BA] Asks clarifying questions → docs/requirements/<slug>.md
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
