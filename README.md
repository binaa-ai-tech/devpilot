# devpilot

> One person. Full AI dev team. One command delivers the PR.

Install devpilot on any project and hand off any feature, bug, or production emergency with a single `/ceo` command. An AI team of BA, Team Lead, developers, and QA handles everything — requirements, planning, code, tests, review, and PR — while you stay in control of when to ship.

---

## How It Works

```
/ceo "add Excel export to the user report"
         │
         ▼
  [Classify: feature]
         │
         ▼
  [BA] Reads codebase → writes requirements autonomously
         │
         ▼
  [Team Lead] Jira ticket → feature branch → implementation plan
         │
         ├─────────────────────────────┐
         ▼                             ▼
  [Frontend Dev]               [Backend Dev]
  Angular/React UI             .NET API + SQL
         │                             │
         └──────────────┬──────────────┘
                        ▼
                  [QA Engineer]
             Tests + verification report
                        │
                        ▼
                 [Team Lead]
              Code review → PR opened
                        │
                        ▼
    ✅ DONE — PR URL + DEV link + promote commands
```

No clarifying questions. No stopping. The team reads your codebase, makes smart assumptions, and delivers.

---

## Quick Install

Run from the root of any project:

```bash
curl -s https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/binaa-ai-tech/devpilot
bash devpilot/install.sh
```

The installer will:
1. **Scan your system** — detect Claude Code, opencode, GitHub CLI
2. **Scan your project stack** — detect Angular, React, .NET, Python, SQL migrations, etc.
3. **Recommend an agent team** — only installs agents relevant to your stack
4. **Run a model config wizard** — set primary + fallback models per agent
5. **Write `project.config.md`** — your per-project config, committed to git
6. **Download all files** — commands, agents, skills, scripts, templates

Setup time: ~5 minutes.

---

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| [Claude Code](https://claude.ai/code) | Yes | Primary AI engine |
| [GitHub CLI (`gh`)](https://cli.github.com) | Yes | PR creation + Actions |
| `git` | Yes | Branch management |
| [opencode](https://opencode.ai) | Recommended | Fallback when Claude hits limits |

---

## Commands

### Entry Point

```
/ceo <description>
```

That's the only command you need for day-to-day work. Everything else runs automatically.

```
/ceo add a dark mode toggle
/ceo fix the login redirect bug
/ceo production is down — users can't check out   ← hotfix mode
/ceo resume                                        ← continue after opencode fallback
```

### Individual Agents (when you need fine-grained control)

| Command | What it does |
|---------|-------------|
| `/team-task <description>` | Full team workflow (same as `/ceo` feature/bug) |
| `/team-ba <description>` | BA phase only — just write requirements |
| `/team-lead <context>` | Planning or review only |
| `/team-frontend <context>` | Frontend implementation only |
| `/team-dotnet <context>` | Backend (.NET) implementation only |
| `/team-qa <context>` | QA phase only |

### Deploy Pipeline

After your PR merges and CI deploys to DEV:

| Command | Stage | When to run |
|---------|-------|-------------|
| `/binaa-sit <version>` | SIT | DEV testing passed |
| `/binaa-uat` | UAT | SIT QA passed |
| `/binaa-prd <version>` | PRD | UAT signed off |
| `/binaa-hotfix <n> <slug> <ver>` | Emergency | Production incident |

Version convention: features → bump MINOR (`1.0.0 → 1.1.0`), fixes → bump PATCH (`1.0.0 → 1.0.1`).

### Configuration

```
/binaa reconfig    ← re-run model config wizard anytime
```

---

## Model Routing — 3-Tier Resilience

devpilot uses a 3-tier fallback so work never stops:

| Tier | Engine | Trigger |
|------|--------|---------|
| **Tier 1** | Claude Pro (Sonnet 4.6, Haiku 4.5) | Primary — always |
| **Tier 2** | GitHub Copilot via opencode | Auto when Claude hits rate/context limits |
| **Tier 3** | OpenCode Zen Free (DeepSeek, Nemotron) | Last resort — zero cost |

### Default Routing (Claude Pro + GitHub Copilot)

| Agent | Tier 1 | Tier 2 | Tier 3 |
|-------|--------|--------|--------|
| BA | claude-haiku-4-5 | Gemini 3.5 Flash | DeepSeek V4 Flash Free |
| Team Lead | claude-sonnet-4-6 | Gemini 2.5 Pro | DeepSeek V4 Flash Free |
| Frontend Dev | claude-sonnet-4-6 | GPT-5.4 | DeepSeek V4 Flash Free |
| Backend Dev | claude-sonnet-4-6 | GPT-5.4 | DeepSeek V4 Flash Free |
| DB Agent | claude-sonnet-4-6 | GPT-5.2 | DeepSeek V4 Flash Free |
| QA | claude-haiku-4-5 | GPT-5-mini | Nemotron 3 Super Free |

**No Opus** — Sonnet 4.6 handles all tasks well and keeps daily limits free for real work.

### When Claude Hits a Limit

The `self-heal` skill detects the limit automatically and outputs:

```
⚠️  CLAUDE LIMIT REACHED — Backend Dev phase

Fallback: GPT-5.4 via opencode

Run: opencode --model "GPT-5.4" < docs/fallback/user-export-backend.md

When opencode finishes → run: /ceo resume
```

No lost work. `/ceo resume` picks up exactly where Claude stopped.

---

## Project Configuration

After install, `project.config.md` in your repo root controls everything:

```yaml
project_name: "my-app"
project_type: fullstack
base_branch: main

stack:
  frontend: angular
  backend: dotnet
  database: sqlserver
  integration: none

agents:
  frontend: { enabled: true }
  backend:  { enabled: true }
  db:       { enabled: true }
  integration: { enabled: false }

models:
  frontend:
    tier1: claude-sonnet-4-6
    tier2: "copilot: GPT-5.4"
    tier3: "free: DeepSeek V4 Flash Free"
  # ...
```

Edit directly or run `/binaa reconfig` to use the interactive wizard.

---

## What Gets Produced per Task

| Artifact | Location |
|----------|---------|
| Requirements + domain model | `docs/requirements/<slug>.md`, `docs/domain-models/<slug>.md` |
| Implementation plan + ADRs | `docs/plans/<slug>.md`, `docs/adrs/` |
| QA report | `docs/qa/<slug>.md` |
| Code review report | `docs/reviews/<slug>.md` |
| Fallback prompts (if limit hit) | `docs/fallback/<slug>-<phase>-prompt.md` |

---

## File Structure

```
devpilot/
├── install.sh                    ← run this on any project
├── project.config.md             ← template (written per-project at install)
├── CLAUDE.md                     ← instructions for Claude Code
├── .devpilot/
│   ├── rules.md                  ← coding standards (all stacks)
│   ├── config.sh                 ← project secrets (gitignored)
│   ├── config/models.md          ← model routing reference
│   ├── skills/                   ← power skills loaded by agents
│   │   ├── get-shit-done.md      ← autonomous execution rules
│   │   ├── self-heal.md          ← error recovery + model fallback
│   │   ├── security-scan.md
│   │   ├── performance-review.md
│   │   ├── architecture-guard.md
│   │   └── definition-of-done.md
│   ├── prompts/team/             ← per-role agent prompts
│   └── templates/team/           ← document output templates
├── .claude/
│   ├── agents/                   ← agent definitions with model frontmatter
│   └── commands/                 ← slash commands
│       ├── ceo.md
│       ├── team-task.md
│       ├── team-*.md
│       ├── binaa-*.md            ← deploy pipeline commands
│       └── binaa-reconfig.md
├── scripts/                      ← git-flow, deploy, Jira automation
└── docs/                         ← task outputs (gitignored: fallback/)
```

---

## After Install — Setup Checklist

1. **Edit `.devpilot/config.sh`** (gitignored):
   ```bash
   JIRA_BASE_URL="https://your-org.atlassian.net"
   JIRA_EMAIL="you@example.com"
   JIRA_API_TOKEN="your-token"
   JIRA_PROJECT_KEY="APP"
   GITHUB_ORG="your-org"
   GITHUB_REPO="your-repo"
   DEV_FRONTEND_URL="https://your-app-dev.example.com"
   # ... SIT/UAT/PRD URLs
   ```

2. **Add GitHub Secrets** (repo → Settings → Secrets → Actions):
   `DEPLOY_HOOK_DEV`, `DEPLOY_HOOK_SIT`, `DEPLOY_HOOK_UAT`, `DEPLOY_HOOK_PRD`

3. **Create GitHub Environments**: `dev`, `sit`, `uat`, `prd`

4. **Start working**:
   ```
   /ceo your first task description
   ```

---

## License

MIT
