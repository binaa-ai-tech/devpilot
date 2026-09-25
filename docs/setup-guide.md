# DevPilot Setup Guide — install into any project

Step-by-step instructions for installing DevPilot into a new or existing repo,
with a recommendation at every decision point. The 6-step wizard takes ~4 minutes; the
defaults are safe, so when in doubt press Enter.

---

## 1 · Before you start

| Need | Why | Required? |
|------|-----|-----------|
| `git` | branch management | **Yes** |
| [Claude Code](https://claude.ai/code) — CLI, desktop, IDE, or claude.ai/code | runs the whole team | **Yes** |
| GitHub CLI (`gh`) — code on GitHub | PR automation, auto-merge | Recommended (Claude Code on the web uses the GitHub MCP instead) |
| Azure DevOps PAT — code on Azure Repos | PRs, auto-complete, pipeline status | Required for Azure Repos |
| `curl` + `jq` | Jira / Azure DevOps / GitHub REST calls, config scripts | **Yes** |
| A `develop` branch | the DEV→SIT→UAT→PRD pipeline | Recommended (the wizard can create it) |

Decide (or just take the recommendation):

1. **How Claude models map to the team** — recommended tiers, one model, or per-team?
2. **Work tracker** — Jira, Azure DevOps Boards, GitHub Issues, or none (local files)?
3. **Merge policy** — auto-merge to `develop`, or human-merged PRs?

## 2 · Install

Run **from the root of your project**:

```bash
# Recommended — download, inspect, run:
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh -o /tmp/devpilot-install.sh && bash /tmp/devpilot-install.sh

# Or one-liner:
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh | bash

# Or from a local clone:
bash /path/to/devpilot/install.sh

# Non-interactive (CI, devcontainers, rolling out to many repos):
curl -fsSL https://raw.githubusercontent.com/binaa-ai-tech/devpilot/main/install.sh | bash -s -- --defaults
```

`--defaults` accepts every recommendation in this guide (recommended Claude model tiers,
local tracker, auto merge) — change anything later per §6.

## 3 · The wizard, step by step

### STEP 1–2 — Tool & stack scan (automatic)
Detects Claude Code, `gh`, `jq`, and your stack (Angular · .NET · DB migrations · messaging). Other
frontends/backends are reported and their agent left off — DevPilot's skills target Angular + .NET. Nothing to answer; fix a ❌ on `git` before continuing.

### STEP 3 — Agent team
> **Recommendation: accept the detected team.** BA, Team Lead, and QA are always on;
> Frontend/Backend/DB/Integration agents are enabled only for layers your repo actually has.

### STEP 4 — Claude model assignment (the important one)
Three modes:

| Mode | What it does | Choose when |
|------|--------------|-------------|
| **`recommended`** *(default)* | Task-balanced tiers: a power model for architectural/hard work, standard for normal coding, lite for BA/QA/simple changes. | Best cost ↔ quality for almost everyone. |
| `single` | ONE model for every team member. | You want predictable cost/behavior, or your plan only includes one model. |
| `per-team` | You pick a model for each role: BA, Team Lead, QA, Frontend dev, Backend dev. | You know your workload (e.g. heavy frontend → stronger FE model) or must control spend per role. |

Guidance inside the modes:
- **recommended** → take the `auto` profile (Opus for hard work, Sonnet normal, Haiku light).
  Choose `balanced` to avoid Opus, `save` to minimize tokens.
- **single** → **Sonnet** is the sweet spot. Opus everywhere is the highest-cost choice;
  Haiku everywhere is fine for small/simple projects.
- **per-team** → defaults already follow the role: BA/QA → Haiku, Team Lead/devs → Sonnet.
  Upgrade the Team Lead to Opus for architecture-heavy projects.

Everything here is changeable later in one command — see §6.

### STEP 5 — Team models (review)
Shows the model each role will use. Nothing to answer.

### STEP 6 — Project identity, tracker, merge policy
- **Ticket prefix** — e.g. `APP`; matches your Jira project key if you use Jira.
- **Base branch** — accept `develop` (created if missing). Use `main` only for trunk-based repos.
- **Tracker** — `local` (zero setup, items in `docs/tasks/`), `jira`, `azure` (Azure DevOps
  Boards) or `github` (GitHub Issues). Choosing Jira or Azure DevOps asks for credentials right
  away — **press Enter to skip**; the first `/dp-deliver` then offers to connect it or continue
  without a tracker. See §3a.
- **Merge policy** — **`auto` (recommended)**: the team merges its own green PRs into
  `develop`; production (`/dp-release prd`) always requires you. Pick `pr-only` if every
  PR needs human eyes — e.g. a regulated codebase or a team new to DevPilot.
- **Docs language** — BA/QA docs in your language (`en`, `ar`, …); code stays English.

### Final steps — CI workflow & branch protection (after the confirm screen)
> **Recommendation: accept both.** The installer generates the gate-ladder pipeline for your
> git host — **GitHub** → `.github/workflows/devpilot-ci.yml`, **Azure Repos** →
> `azure-pipelines.yml` (Angular lint/build/Vitest → .NET build/xUnit + SQL Server → Playwright
> → test-guard strict → dependency audit) — then protects `develop`/`main`: on GitHub it applies
> branch protection (with `gh`), on Azure Repos it prints the branch policies to set (Build
> validation, squash-only, no force push). This is what makes `merge_policy: auto` safe.
> Later: `bash scripts/generate-ci.sh --force` · `bash scripts/protect-branches.sh`.

## 3a · Trackers and git hosts

DevPilot talks to one **work tracker** and one **git host**. Mix freely — e.g. Jira + Azure
Repos, or Azure DevOps Boards + Repos, or GitHub Issues + GitHub.

| Tracker | Sprints are | Values | Connect |
|---------|-------------|--------|---------|
| **Jira Cloud** | Scrum sprints (Fix Versions on non-Scrum boards) | site URL, email, API token, project key | `/dp-setup tracker jira` |
| **Azure DevOps Boards** | team iterations | org URL, project, PAT | `/dp-setup tracker azure` |
| **GitHub Issues** | milestones (sub-issues for Epic → Story) | `gh auth login` or a token | `/dp-setup tracker github` |
| **local** | `docs/sprints/*.md` | none | default |

**Jira** — token at https://id.atlassian.com/manage-profile/security/api-tokens; the project key
must equal your ticket prefix.
```bash
bash scripts/tracker.sh setup jira jira_base_url=https://<org>.atlassian.net jira_email=<email> \
     jira_api_token=<token> jira_project_key=<KEY>
```
**Azure DevOps** — PAT from *User settings → Personal access tokens* with **Work Items (Read &
write), Code (Read & write), Build (Read)**. The Story type is detected from your process
(User Story · Product Backlog Item · Requirement · Issue).
```bash
bash scripts/tracker.sh setup azure azdo_org_url=https://dev.azure.com/<org> azdo_project=<project> azdo_pat=<token>
```
`setup` stores the values in `.devpilot/config.sh` (gitignored), switches `tracker.type`, and tests
the connection live. Then run the **self-test** — it performs every call a delivery makes on your real
project (Epic → Story → sprint → Done → Epic + sprint closed) and deletes what it created:
`bash scripts/tracker.sh selftest` (or `/dp-setup tracker test`). **CI or shared machines:** export the same names as environment variables
(`JIRA_API_TOKEN`, `AZDO_PAT`, `GITHUB_TOKEN`, …) — they override the file.

**Not configured?** The first `/dp-deliver` or `/dp-plan` asks once: *connect now* (paste the
values or set the env vars) or *continue without a tracker* — items are then kept in
`docs/tasks/` and later runs stop asking until you connect (`/dp-setup tracker`). For
unattended runs set `tracker.when_unconfigured: skip`.

**Git host** is read from the `origin` remote (`git_host: auto`): GitHub PRs go through `gh`
(or the GitHub MCP on Claude Code on the web); Azure Repos PRs go through the REST API with the
same `AZDO_PAT` and use **auto-complete** (squash, delete branch, merge when policies pass).

**What the tracker sees during a delivery:** Epic → Story (or one Bug) with a self-contained
brief → added to a sprint → `In Progress` with a start comment → after the PR merges, `Done` with
the version + PR link, the Epic closed once all its Stories are Done, and the sprint closed once
nothing in it is open. A QA **BLOCKED** comment is the only other one.

**Pipelines (`/dp-setup pipelines`):** CI on every PR plus CD that **builds once** and promotes the same
artifact `develop → DEV`, `release/* → SIT → UAT → PRD`, `hotfix/* → SIT → PRD`, with human approvals on
UAT and PRD (`scripts/setup-environments.sh`). Deploys run `deploy/deploy.sh <env> <dir> <version>` from
your repo, or call a `DEPLOY_HOOK` secret, then a smoke test against `API_URL` / `FRONTEND_URL`. On Azure
Repos, `protect-branches.sh` applies the branch policies over the API (CI required, squash only, comments
resolved; + 1 reviewer under `pr-only`), and PRs are never auto-completed into a branch without CI.

**Versions:** every `/dp-deliver` PR bumps the version from `develop`'s current one — a feature
bumps MINOR, a bug PATCH — in `VERSION`, `Directory.Build.props`, `package.json` and `*.csproj`
`<Version>`. The PR title carries it (`[v1.4.0] …`); `/dp-release sit` releases exactly that
version. Turn off with `versioning.bump: off`.

## 4 · After install — verify before first use

```bash
/dp-status health        # or: bash scripts/doctor.sh — checks config, tracker, git host,
                         # branches, Claude CLI, model ids, agent sync, and missing values
/dp-setup fix           # interactively repairs anything the doctor flagged
git add -A && git commit -m "chore: install devpilot"
```

Optional but worth 60 seconds — **notifications**: set `NOTIFY_WEBHOOK` (Slack/Teams/
Discord-compatible) in `.devpilot/config.sh` and the team pings you on sprint DONE,
QA BLOCKED, and `/dp-pr` escalation. That's what makes "walk away" after `/dp-deliver` real.

Two gates you should know from day one:
- **Test guard** (highly recommended, on by default in the merge ladder) —
  `bash scripts/test-guard.sh` proves every changed source file has a covering test;
  merge gates run it strict. See `.devpilot/skills/test-guard.md`.
- **Doctor** — run it whenever something feels off; every warning comes with the exact
  fix command, and `/dp-setup fix` applies them interactively.

Then run your first task:

```bash
/dp-deliver "add a CSV export to the orders page"          # plan → build → test → review → merged
/dp-deliver "add a CSV export to the orders page" --to sit # …and cut the SIT release
# or role by role: /dp-plan "…" → /dp-sprint → /dp-build sprint-1 → /dp-pr
```

The standard process the team follows lives in `.devpilot/process.md`.

## 5 · Recommended setups by scenario

| Scenario | Model mode | Tracker | Merge policy |
|----------|-----------|---------|--------------|
| **Solo developer** | recommended (`auto`) | local | auto |
| **Product team** | recommended (`auto`) | jira, azure or github | auto (`pr-only` while onboarding) |
| **Enterprise / regulated** | recommended (`balanced`) or per-team | jira or azure | pr-only + branch protection / policies + CODEOWNERS |
| **Budget-capped** | recommended (`save`) or single (Sonnet) | local | auto |

## 6 · Changing your mind later

| Change | How |
|--------|-----|
| Model profile (recommended mode) | `/dp-setup models save` — or `bash scripts/model-profiles.sh apply save` |
| One model for everything | `bash scripts/model-profiles.sh single claude-sonnet-5` |
| Per-team models | edit `models.*` in `project.config.md` → `bash scripts/model-profiles.sh sync-agents` |
| Tracker (Jira / Azure DevOps / GitHub / local) | `/dp-setup tracker` |
| Agents, merge policy, versioning | edit `project.config.md` (one line each) or `/dp-setup wizard` |
| Update DevPilot itself | `bash install.sh --update` — never touches `project.config.md` or credentials |
| Update every repo in your org | `bash scripts/update-org.sh <org> --merge` (from the devpilot clone) — clones each repo, runs `--update` on the base branch, opens/merges one PR per repo; `--install-missing` fresh-installs with defaults where devpilot isn't present. **Never delete + re-install** — that loses per-project config; `--update` exists precisely so you don't have to. |

Every routing decision is read from `project.config.md` at run time — no reinstall needed.
