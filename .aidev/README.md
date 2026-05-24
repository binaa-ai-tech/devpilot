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

## The 7 Steps

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
feature/{prefix}-{n}-{slug}    ← new capability        e.g. feature/mas-42-map-filters
fix/{prefix}-{n}-{slug}        ← bug fix               e.g. fix/mas-99-otp-expiry
refactor/{prefix}-{n}-{slug}   ← internal change       e.g. refactor/mas-12-auth-service
hotfix/{prefix}-{n}-{slug}     ← emergency prod fix    e.g. hotfix/mas-77-login-crash
chore/{prefix}-{n}-{slug}      ← tooling/deps/docs     e.g. chore/mas-5-bump-deps

release/{major}.{minor}.{patch}                         e.g. release/1.1.0
```

All branches cut from **`develop`** except `hotfix/*` (cut from **`main`**).

---

## Commit convention

```
<type>(<scope>): <description>

Types:  feat | fix | chore | refactor | docs | test | ci | perf
```

Scopes are project-defined — see `.commitlintrc.json`.

---

## The golden rule

**Read `rules.md` before every step.** It is the single source of truth for code standards.
