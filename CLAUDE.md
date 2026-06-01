# DevPilot — AI Team System

Two phases. **Plan** builds a deduplicated Jira backlog; **Build** ships it sprint by sprint.
Describe what you want — the AI team runs project management → code → QA → PR.

---

## The 10 commands

**Workflow**
| Command | Does |
|---------|------|
| `/ceo <description>` | **Express** — plan → sprint → build, end to end. Walk away. Stops only on a gray-zone dedup question. Flags: `--claude` / `--opencode` / `--max`. |
| `/dp-plan <feature\|issue\|task\|requirement>` | **Plan only** — PM dedups against the backlog (merges duplicates), writes Epic→Story in Jira. No code. Accepts raw text or a Jira key. |
| `/dp-sprint` | Organize the backlog into sprints, recommend which to run first. |
| `/dp-build [sprint]` | Build a whole sprint on one branch → one PR → `develop`. |

**Deploy** · `/dp-release <sit\|uat\|prd> [version]` · `/dp-rollback [version]` · `/dp-hotfix <ticket> <slug> <version>`
**Utility** · `/dp-status [health\|board\|metrics]` · `/dp-config [models\|wizard\|index]` · `/dp-review-fix <PR>`

---

## How it works

```
PLAN                                   BUILD
/dp-plan "add CSV export"              /dp-sprint
  → classify intent                     → group Stories into sprints
  → dedup ladder ↓                      → recommend run order
     DUPLICATE / FOLD-IN /            /dp-build sprint-1
     RELATED / UNRELATED                → one branch
  → spec to git                         → frontend/backend/db/integration in parallel
  → Epic→Story to Jira                  → QA every AC
  (auto on high confidence,            → one PR → develop
   asks only in the gray zone)         → Stories → Done

/ceo "…"  = the whole column, autonomous.
```

**Dedup brain:** `/dp-plan` matches each new item against `docs/backlog/index.md` (a small,
always-loadable map), reading full specs of only the top 1–3 candidates. Merges are
reversible Jira links + one Story with combined ACs.

---

## Token discipline (works in any repo)

- **Scope via indexes** — read `docs/project-index.md` + `docs/backlog/index.md` first;
  cap codebase reading to 3–8 files. Never broad-scan.
- **Read-once core** — `.devpilot/skills/core-rules.md` replaces re-reading long skill files.
- Pull a specific skill from `.devpilot/skills/` only when the task needs it.

---

## Implementation engine

- **`engine: claude`** (default) — Claude subagents handle every phase, fully automatic.
- **`engine: opencode`** — Claude does PM/QA/review; opencode writes code (run via Bash directly,
  never a manual handoff). Set in `project.config.md`. Change anytime: `/dp-config models`.

3-tier model routing: Claude (primary) → Copilot-via-opencode (on limit) → OpenCode Zen (last resort).

---

## Tech stack & rules

- **Frontend:** Angular 21+ / React · **Backend:** .NET (C#), SQL Server (stack-aware: node/python/go/java).
- **Rules:** `.devpilot/rules.md` (router) + `.devpilot/rules/<stack>.md`.
- **Skills:** `.devpilot/skills/` — operating manual. Index: `.devpilot/skills/README.md`.
- **Agents:** `.claude/agents/` — team-ba, team-lead, team-frontend, team-backend, team-dotnet, team-qa
  (spawned by the workflow commands; no manual slash wrappers).

---

## Docs output per task

| Document | Path |
|----------|------|
| Backlog index | `docs/backlog/index.md` |
| Requirements + Domain Model | `docs/requirements/<slug>.md`, `docs/domain-models/<slug>.md` |
| Sprint plan | `docs/sprints/plan.md` |
| Implementation Plan + ADRs | `docs/plans/<slug>.md`, `docs/adrs/` |
| QA Report | `docs/qa/<slug>.md` |
| Review Report | `docs/reviews/<slug>.md` |
