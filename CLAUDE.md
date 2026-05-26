# Dev Process — AI Team System

One command. AI team delivers the full feature or bug fix from requirement to PR.

---

## Single Entry Point

```
/ceo <description of feature, bug, or production issue>
```

---

## How It Works

```
/ceo "description"
     ↓
[Classify: feature / bug / hotfix]
     ↓
[BA] Reads codebase → writes requirements autonomously (no stop)
     ↓
[Team Lead] Jira ticket → branch → implementation plan
     ↓
[Parallel — only agents enabled in project.config.md]
  ├── Frontend Dev   (if stack has frontend)
  ├── Backend Dev    (if stack has backend)
  ├── DB Agent       (if DB changes in plan)
  └── Integration    (if messaging/services in plan)
     ↓
[QA] Tests + verification
     ↓
[Team Lead] Code review → PR
     ↓
Report: PR URL + DEV URL + promote commands
```

---

## Implementation Engine

**Default: `engine: claude`** — fully automatic end-to-end. Claude subagents handle every phase with no manual steps.

**Optional: `engine: opencode`** — Claude does BA/planning/QA/review; you run opencode in your terminal for coding phases. Set this in `project.config.md` if you prefer opencode for implementation.

Change anytime with `/binaa reconfig` or `/binaa-models`.

---

## Commands

| Command | When to use |
|---------|-------------|
| `/ceo <description>` | Primary entry point — any task |
| `/ceo resume` | After opencode fallback completes |
| `/team-task <description>` | Full team flow with more control |
| `/team-ba` / `/team-lead` / `/team-frontend` / `/team-dotnet` / `/team-qa` | Individual agent |
| `/binaa reconfig` | Re-run model configuration wizard |

## Deploy Pipeline

| Command | Stage | When |
|---------|-------|------|
| `/binaa-sit <version>` | SIT | After DEV testing passes |
| `/binaa-uat` | UAT | After SIT QA passes |
| `/binaa-prd <version>` | PRD | After UAT sign-off |
| `/binaa-hotfix <n> <slug> <version>` | Emergency | Production issue |

---

## Model Configuration (3-Tier)

| Tier | Models | Trigger |
|------|--------|---------|
| Tier 1 | Claude Pro (Sonnet 4.6, Haiku 4.5) | Primary — always |
| Tier 2 | GitHub Copilot via opencode (GPT-5.4, Gemini 2.5 Pro, etc.) | Auto on Claude limit |
| Tier 3 | OpenCode Zen Free (DeepSeek, Nemotron) | Last resort |

Change anytime: `/binaa reconfig`

---

## Tech Stack

- **Frontend:** Angular 21+ / React
- **Backend:** .NET (C#), SQL Server
- **Rules:** `.devpilot/rules.md`
- **Skills:** `.devpilot/skills/` (get-shit-done, security-scan, performance-review, architecture-guard, self-heal, definition-of-done)

---

## Docs Output per Task

| Document | Path |
|----------|------|
| Requirements + Domain Model | `docs/requirements/<slug>.md`, `docs/domain-models/<slug>.md` |
| Implementation Plan + ADRs | `docs/plans/<slug>.md`, `docs/adrs/` |
| QA Report | `docs/qa/<slug>.md` |
| Review Report | `docs/reviews/<slug>.md` |
| Fallback prompts (if limit hit) | `docs/fallback/<slug>-<phase>-prompt.md` |
