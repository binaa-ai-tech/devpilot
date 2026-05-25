# devpilot

> One person. Full AI dev team. One command delivers the merged PR.

Install devpilot on any project and run any feature, bug, or production emergency with a single `/ceo` command. An AI team of BA, Team Lead, and QA handles requirements, planning, testing, and review — while **opencode** with your preferred coding model writes the actual code.

---

## How It Works

```
/ceo "add rental agreement PDF export"
         │
         ▼
  [BA — Claude Haiku]
  Reads codebase → writes requirements + domain model
  Creates Jira ticket (Epic + child Tasks for big features)
         │
         ▼
  [Team Lead — Claude Sonnet]
  Feature branch → implementation plan
  Updates Jira ticket with full user story
         │
         ▼
  ⏸  HANDOFF TO opencode
  Claude writes implementation briefs per agent:
    docs/implementation/<slug>-frontend.md
    docs/implementation/<slug>-backend.md

  You run in your terminal:
    opencode --model "github-copilot/gpt-4o" < docs/implementation/<slug>-frontend.md
    opencode --model "github-copilot/gpt-4o" < docs/implementation/<slug>-backend.md

  When done → /ceo resume
         │
         ▼
  [QA — Claude Haiku]
  Verifies all acceptance criteria → QA report
         │
         ▼
  [Team Lead — Claude Sonnet]
  Code review → opens PR → merges into base branch → closes Jira ticket
         │
         ▼
  ✅ DONE — PR merged + Jira closed + DEV link + promote commands
```

No clarifying questions. No stopping (except the opencode handoff). The team reads your codebase, makes smart assumptions, and delivers.

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
4. **Run a model config wizard** — set Claude models (BA/QA/Lead) + opencode coding model
5. **Write `project.config.md`** — your per-project config, committed to git
6. **Download all files** — commands, agents, skills, scripts, templates

Setup time: ~5 minutes.

---

## Requirements

| Tool | Required | Purpose |
|------|----------|---------|
| [Claude Code](https://claude.ai/code) | Yes | BA, planning, QA, review |
| [opencode](https://opencode.ai) | Yes (if engine: opencode) | Writes all implementation code |
| [GitHub CLI (`gh`)](https://cli.github.com) | Yes | PR creation, merge, Actions |
| `git` | Yes | Branch management |
| `jq` | Yes | JSON parsing in scripts |

---

## Commands

### Primary Entry Point

```
/ceo <description>
```

```
/ceo add a dark mode toggle
/ceo fix the login redirect bug
/ceo production is down — users can't check out   ← hotfix mode
/ceo resume                                        ← continue after opencode handoff
```

### Individual Agents (fine-grained control)

| Command | What it does |
|---------|-------------|
| `/team-task <description>` | Full team workflow (same as `/ceo` feature/bug) |
| `/team-ba <description>` | BA phase only — write requirements |
| `/team-lead <context>` | Planning or review only |
| `/team-qa <context>` | QA phase only |

### Deploy Pipeline

After the PR merges and CI deploys to DEV:

| Command | Stage | When to run |
|---------|-------|-------------|
| `/binaa-sit <version>` | SIT | DEV testing passed |
| `/binaa-uat` | UAT | SIT QA passed |
| `/binaa-prd <version>` | PRD | UAT signed off |
| `/binaa-hotfix <n> <slug> <ver>` | Emergency | Production incident |

Version convention: features → bump MINOR (`1.0.0 → 1.1.0`), fixes → bump PATCH (`1.0.0 → 1.0.1`).

### Configuration

```
/binaa reconfig    ← change implementation engine, opencode model, or Claude models anytime
```

---

## Model Architecture

devpilot separates concerns cleanly between Claude and opencode:

| Phase | Engine | Default Model |
|-------|--------|--------------|
| BA (requirements) | Claude | `claude-haiku-4-5` |
| Planning + Jira + branch | Claude | `claude-sonnet-4-6` |
| **All coding** | **opencode** | your configured model |
| QA (testing) | Claude | `claude-haiku-4-5` |
| Review + PR + merge | Claude | `claude-sonnet-4-6` |

**Why?** Claude excels at understanding codebases, writing precise requirements, and verifying acceptance criteria. opencode with GitHub Copilot models excels at generating large amounts of correct code across multiple files quickly.

### Configuring the Coding Model

Set in `project.config.md`:

```yaml
implementation:
  engine: opencode                       # opencode | claude
  model:  github-copilot/gpt-4o          # any model opencode supports
```

To see available models: `opencode model list`

Common choices:
- `github-copilot/gpt-4o` — best all-round
- `github-copilot/gpt-3.5-codex` — fast and cheap
- `github-copilot/claude-3.5-sonnet` — strong reasoning + code

Run `/binaa reconfig` → choose "engine" to change anytime.

---

## Jira Integration

devpilot tracks every task in Jira automatically:

| Event | What happens |
|-------|-------------|
| Phase 1 (BA) | Ticket created with full user story + ACs |
| Phase 2 (Plan) | Ticket moved to **In Progress** + comment with branch and plan link |
| Phase 3 (Code) | Comment per agent: model used + one-line summary |
| Phase 4 (QA) | Comment: PASS or BLOCKED verdict |
| Phase 5 (PR merge) | PR merged into base branch → ticket moved to **Done** + merge confirmation |

**Big features** (>5 ACs or 3+ agents): one **Epic** + one child **Task** per agent (Frontend, Backend, DB, Integration). All managed automatically.

The Jira ticket is **never closed before the PR is merged.**

---

## Project Configuration

After install, `project.config.md` in your repo root controls everything:

```yaml
project_name: "my-app"
project_type: fullstack
base_branch: develop          # branch all PRs target

stack:
  frontend: angular
  backend: dotnet
  database: sqlserver
  integration: none

implementation:
  engine: opencode             # opencode | claude
  model: "github-copilot/gpt-4o"

agents:
  ba:          { enabled: true }
  team_lead:   { enabled: true }
  frontend:    { enabled: true }
  backend:     { enabled: true }
  db:          { enabled: true }
  integration: { enabled: false }
  qa:          { enabled: true }

models:
  ba:         { tier1: claude-haiku-4-5 }
  team_lead:  { tier1: claude-sonnet-4-6 }
  qa:         { tier1: claude-haiku-4-5 }
```

Edit directly or run `/binaa reconfig` to use the interactive wizard.

---

## What Gets Produced per Task

| Artifact | Location |
|----------|---------|
| Requirements + domain model | `docs/requirements/<slug>.md`, `docs/domain-models/<slug>.md` |
| Implementation plan | `docs/plans/<slug>.md` |
| Implementation briefs (for opencode) | `docs/implementation/<slug>-frontend.md`, `<slug>-backend.md`, etc. |
| QA report | `docs/qa/<slug>.md` |
| Code review report | `docs/reviews/<slug>.md` |

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
│   ├── skills/                   ← power skills loaded by agents
│   │   ├── get-shit-done.md      ← autonomous execution rules
│   │   ├── spec-first.md         ← spec-driven development enforcement
│   │   ├── self-heal.md          ← error recovery
│   │   ├── security-scan.md
│   │   ├── performance-review.md
│   │   ├── architecture-guard.md
│   │   └── definition-of-done.md
│   ├── prompts/team/             ← per-role agent prompts
│   └── templates/team/           ← document output templates
├── .claude/
│   ├── agents/                   ← agent definitions with model frontmatter
│   └── commands/                 ← slash commands
│       ├── ceo.md                ← primary entry point
│       ├── team-task.md          ← full 5-phase workflow
│       ├── team-ba.md            ← BA agent standalone
│       ├── team-lead.md          ← Team Lead standalone
│       ├── team-qa.md            ← QA agent standalone
│       ├── binaa-*.md            ← deploy pipeline commands
│       └── binaa-reconfig.md     ← model config wizard
├── scripts/
│   ├── install.sh                ← project setup wizard
│   ├── git-flow.sh               ← feature / hotfix branch helpers
│   ├── create-jira-ticket.sh     ← create Task tickets
│   ├── create-jira-epic.sh       ← create Epic + child Tasks
│   ├── update-jira-status.sh     ← move ticket through workflow
│   ├── update-jira-description.sh← update ticket body with user story
│   └── add-jira-comment.sh       ← log agent activity to Jira
└── docs/                         ← task outputs (gitignored: fallback/)
```

---

## After Install — Setup Checklist

1. **Edit `.devpilot/config.sh`** (gitignored — never commit):
   ```bash
   JIRA_BASE_URL="https://your-org.atlassian.net"
   JIRA_EMAIL="you@example.com"
   JIRA_API_TOKEN="your-token"
   JIRA_PROJECT_KEY="APP"
   GITHUB_ORG="your-org"
   GITHUB_REPO="your-repo"
   DEV_FRONTEND_URL="https://your-app-dev.example.com"
   # SIT / UAT / PRD URLs...
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
