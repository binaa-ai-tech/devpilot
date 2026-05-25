# .aidev — Standard Development Process

> Every task — feature, bug, refactor, hotfix — follows this process.
> Claude handles steps 1–3 and 5–7. opencode handles step 4 (all code).

---

## Environments & Branch Map

```
feature/* ──┐
hotfix/*  ──┤─── CI (lint + test + build) ─────────────────── no deploy
            │
develop   ──┼─── CI ──────────────────────────────────────── → DEV   (auto)
            │
release/* ──┼─── CI ──────────────────────────────────────── → SIT   (auto)
            │                                         └──────► → UAT   (manual ✋)
            │
main      ──┘─── CI ──────────────────────────────────────── → PRD   (manual ✋)
```

| Environment | Branch | Deploy | Stability |
|-------------|--------|--------|-----------|
| DEV | `develop` | Auto on every merge | moving |
| SIT | `release/*` | Auto on push | stable |
| UAT | `release/*` | Manual approval in GitHub Actions | stable |
| PRD | `main` | Manual approval in GitHub Actions | sacred |

---

## The 7 Steps (Single-Agent Workflow)

| # | Step | Output | Tool | Prompt |
|---|------|--------|------|--------|
| 1 | **Intake & Triage** | Jira ticket | Claude | `prompts/1-triage.md` |
| 2 | **Investigation & Plan** | Impact map | Claude | `prompts/2-investigate.md` |
| 3 | **Branch & Setup** | `feature/{prefix}-N-slug` from `develop` | Script | — |
| 4 | **Implement** | Code commits | opencode | `prompts/4-implement-*.md` |
| 5 | **Self-Review** | Diff report | Claude | `prompts/5-self-review.md` |
| 6 | **Test & Verify** | Green CI | Claude + scripts | `prompts/6-*.md` |
| 7 | **PR + Pipeline** | Merged → DEV → SIT → UAT → PRD | Claude | `prompts/7-pr-description.md` |

---

## Branch naming

```
feature/{prefix}-{n}-{slug}    ← new capability        e.g. feature/key-42-user-search
fix/{prefix}-{n}-{slug}        ← bug fix               e.g. fix/key-99-login-error
refactor/{prefix}-{n}-{slug}   ← internal change       e.g. refactor/key-12-auth-service
hotfix/{prefix}-{n}-{slug}     ← emergency prod fix    e.g. hotfix/key-77-otp-crash
chore/{prefix}-{n}-{slug}      ← tooling/deps/docs     e.g. chore/key-5-bump-deps

release/{major}.{minor}.{patch}                         e.g. release/1.1.0
```

`{prefix}` is set in `.aidev/config.sh` → `TICKET_PREFIX`. All branches cut from **`develop`** except `hotfix/*` (cut from **`main`**).

---

## Commit convention

```
<type>(<scope>): <description>

Types:  feat | fix | chore | refactor | docs | test | ci | perf
```

Scopes are project-defined — see `.commitlintrc.json` and `.github/COMMIT_CONVENTION.md`.

---

## AI Team Workflow (Multi-Agent Alternative)

For fully autonomous execution, use the multi-agent team instead of the 7-step single-agent flow:

```
/ceo "description"          ← CEO entry point (auto-classifies + routes)
/team-task "description"    ← Full team: BA → Lead → Frontend+.NET → QA → Review+PR
```

| Agent | Model | Role |
|-------|-------|------|
| Team Lead | Opus 4.7 | Architecture, planning, review |
| Frontend Dev | Sonnet 4.6 | Angular/React implementation |
| .NET Dev | Sonnet 4.6 | API, services, database |
| BA | Haiku 4.5 | Requirements, domain modeling |
| QA | Haiku 4.5 | Testing, acceptance criteria |

See `docs/team/README.md` and `.claude/commands/team-task.md` for details.

---

## The golden rule

**Read `rules.md` before every step.** It is the single source of truth for code standards.
