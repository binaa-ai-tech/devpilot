# DevPilot Setup Guide — install into any project

Step-by-step instructions for installing DevPilot into a new or existing repo,
with a recommendation at every decision point. The wizard takes ~5 minutes; the
defaults are safe, so when in doubt press Enter.

---

## 1 · Before you start

| Need | Why | Required? |
|------|-----|-----------|
| `git` | branch management | **Yes** |
| One AI CLI — [Claude Code](https://claude.ai/code) and/or [opencode](https://opencode.ai) | runs the team | **Yes** (Claude Code recommended — orchestration always runs on Claude) |
| GitHub CLI (`gh`) | PR automation, auto-merge | Recommended |
| `jq` | JSON ops in checkpoint/config scripts | Recommended |
| A `develop` branch | the DEV→SIT→UAT→PRD pipeline | Recommended (the wizard can create it) |

Decide (or just take the recommendation):

1. **Who writes code** — Claude Code, or opencode (GitHub Copilot models)?
2. **How models map to the team** — recommended tiers, one model, or per-team?
3. **Issue tracker** — local files, GitHub Issues, or Jira?
4. **Merge policy** — auto-merge to `develop`, or human-merged PRs?

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

`--defaults` accepts every recommendation in this guide (claude engine, recommended
model tiers, local tracker, auto merge) — change anything later per §6.

## 3 · The wizard, step by step

### STEP 1–2 — Tool & stack scan (automatic)
Detects your AI CLIs and your stack (Angular/React/Vue/Next.js · .NET/Node/Python/Go/Java
· DB migrations · messaging). Nothing to answer; fix a ❌ on `git` before continuing.

### STEP 3 — Agent team
> **Recommendation: accept the detected team.** BA, Team Lead, and QA are always on;
> Frontend/Backend/DB/Integration agents are enabled only for layers your repo actually has.

### STEP 4 — Coding engine (who writes the implementation code)
| Choose | When |
|--------|------|
| **`claude`** *(recommended)* | You have Claude Code. Fully automatic — orchestration and coding in one lifecycle, subagents in parallel, no terminal handoffs. |
| `opencode` | You have a GitHub Copilot subscription you want to spend on coding while Claude handles PM/QA/review. Also works fully offline via Ollama. |
| `antigravity` | You use the antigravity CLI for coding. |

Then pick a **fallback engine** (used automatically when the primary hits rate limits).
> **Recommendation: keep a fallback** if you have a second CLI installed — a long sprint
> survives a limit without losing state (`docs/tasks/<KEY>-checkpoint.json`).

### STEP 5 — Model assignment (the important one)
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
  Upgrade the Team Lead to Opus for architecture-heavy projects. With a non-claude coding
  engine you pin a model **per layer** instead (frontend/backend/db/integration).

Everything here is changeable later in one command — see §6.

### STEP 6 — Terminal runner
How `bash scripts/ceo.sh` runs commands outside Claude Code.
> **Recommendation: `claude`** (or "same as coding engine" if you live in opencode).
> Inside Claude Code, slash commands always work regardless of this choice.

### STEP 8 — Project identity, tracker, merge policy
- **Ticket prefix** — e.g. `APP`; matches your Jira key if you use Jira.
- **Base branch** — accept `develop` (created if missing). Use `main` only for trunk-based repos.
- **Tracker** — **`local` (recommended to start)**: zero setup, full audit in `docs/tasks/`.
  Switch to `github`/`jira` later by editing one config line. Choosing `jira` starts the
  guided Jira walkthrough below (skippable).
- **Merge policy** — **`auto` (recommended)**: the team merges its own green PRs into
  `develop`; production (`/dp-release prd`) always requires you. Pick `pr-only` if every
  PR needs human eyes — e.g. a regulated codebase or a team new to DevPilot.
- **Docs language** — BA/QA docs in your language (`en`, `ar`, …); code stays English.

### Final steps — CI workflow & branch protection (after the confirm screen)
> **Recommendation: accept both.** The installer generates
> `.github/workflows/devpilot-ci.yml` — a stack-aware pipeline running the gate ladder
> (build → tests → test-guard strict → dependency audit) on every PR — and, when `gh` is
> authenticated, applies **branch protection** so that check is required and force-pushes
> are blocked on `develop`/`main`. This is what makes `merge_policy: auto` safe.
> Later: `bash scripts/generate-ci.sh --force` · `bash scripts/protect-branches.sh`.

### Jira setup (tracker: `jira`) — exactly these steps

1. **Create an API token** — https://id.atlassian.com/manage-profile/security/api-tokens
   → *Create API token* → copy it (shown once).
2. **Know your three values** — site URL (`https://<your-org>.atlassian.net`), your
   Atlassian account **email**, and the token.
3. **Enter them when the wizard asks** (after you choose tracker `jira`). The installer
   stores them in `.devpilot/config.sh` (gitignored) and **validates the connection live**
   at the end — HTTP 200 = working, 401 = wrong email/token, 403 = token lacks permission.
4. **Ticket prefix = Jira project key.** The wizard's "ticket prefix" (e.g. `APP`) must
   equal the key of the Jira project where Stories will be created
   (Jira → Projects → your project → the short key).
5. Skipped it, or rotating a token later? Same three values, anytime:
   ```bash
   bash scripts/devpilot-config.sh set jira_base_url=https://your-org.atlassian.net
   bash scripts/devpilot-config.sh set jira_email=<email>
   bash scripts/devpilot-config.sh set jira_api_token=<token>
   bash scripts/devpilot-config.sh validate
   ```

**What Jira looks like during implementation** (so you know what to expect): `/dp-plan`
writes Epic → Story with a self-contained brief; a build moves Stories
`To Do → In Progress → Done` and posts exactly **two** comments per Story — a start
comment and a DONE summary (detail lives in the PR and `docs/tasks/`). A QA **BLOCKED**
comment is the only exception. Until credentials are valid, tracking falls back to
local logs — nothing is lost; `/dp-status` shows the live board either way.

## 4 · After install — verify before first use

```bash
/dp-status health        # or: bash scripts/doctor.sh — checks config, branches, engines,
                         # model ids, agent sync, and missing values
/dp-config fix           # interactively repairs anything the doctor flagged
git add -A && git commit -m "chore: install devpilot"
```

Optional but worth 60 seconds — **notifications**: set `NOTIFY_WEBHOOK` (Slack/Teams/
Discord-compatible) in `.devpilot/config.sh` and the team pings you on sprint DONE,
QA BLOCKED, and autofix escalation. That's what makes "walk away" after `/ceo` real.

Two gates you should know from day one:
- **Test guard** (highly recommended, on by default in the merge ladder) —
  `bash scripts/test-guard.sh` proves every changed source file has a covering test;
  merge gates run it strict. See `.devpilot/skills/test-guard.md`.
- **Doctor** — run it whenever something feels off; every warning comes with the exact
  fix command, and `/dp-config fix` applies them interactively.

Then run your first task:

```bash
/ceo "add a CSV export to the orders page"      # plan → sprint → build → PR, end to end
# or step by step: /dp-plan "…" → /dp-sprint → /dp-build sprint-1
```

The standard process the team follows lives in `.devpilot/process.md`.

## 5 · Recommended setups by scenario

| Scenario | Engine | Model mode | Tracker | Merge policy |
|----------|--------|-----------|---------|--------------|
| **Solo developer** | claude | recommended (`auto`) | local | auto |
| **Small team** | claude | recommended (`auto`) | github | auto (pr-only while onboarding) |
| **Enterprise / regulated** | claude | recommended (`balanced`) or per-team | jira | pr-only |
| **Copilot-first shop** | opencode | recommended | github | auto |
| **Budget-capped** | claude | single (Haiku/Sonnet) or recommended (`save`) | local | auto |

## 6 · Changing your mind later

| Change | How |
|--------|-----|
| Model profile (recommended mode) | `/dp-config models save` — or `bash scripts/model-profiles.sh apply claude save` |
| One model for everything | `bash scripts/model-profiles.sh single claude claude-sonnet-4-6` |
| Per-team models | edit `models.*` / `layer_models.*` in `project.config.md` → `bash scripts/model-profiles.sh sync-agents` |
| Coding engine, agents, tracker, merge policy | edit `project.config.md` (one line each) or `/dp-config wizard` |
| Update DevPilot itself | `bash install.sh --update` — never touches `project.config.md` or credentials |
| Update every repo in your org | `bash scripts/update-org.sh <org> --merge` (from the devpilot clone) — clones each repo, runs `--update` on the base branch, opens/merges one PR per repo; `--install-missing` fresh-installs with defaults where devpilot isn't present. **Never delete + re-install** — that loses per-project config; `--update` exists precisely so you don't have to. |

Every routing decision is read from `project.config.md` at run time — no reinstall needed.
