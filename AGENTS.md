# devpilot — AI Team System

> This file is automatically loaded by opencode and antigravity as project context.
> Claude Code users: see CLAUDE.md instead.

---

## Single Entry Point

```
bash scripts/ceo.sh "description of feature, bug, or production issue"
```

Or pipe a command directly:
```
opencode     < .claude/commands/ceo.md    # replace ceo with any command
antigravity  < .claude/commands/ceo.md
```

---

## How You Work Here (opencode / antigravity mode)

You are the **entire AI dev team** running in a single context. There are no subagents.
Execute all phases sequentially — BA → planning → implementation → QA → PR.

**You handle everything:**
- Read the codebase to understand context before writing any code
- Write requirements, plan, implementation, QA report, review report to `docs/`
- Run git commands, create Jira tickets, open PRs via `gh`
- Follow `.devpilot/rules.md` for all coding decisions

**Key rule: No clarifying questions.** Make reasonable assumptions, document them, proceed.

---

## Workflow Phases

### Phase 1 — BA
Read the codebase. Write:
- `docs/requirements/<slug>.md` (use `.devpilot/templates/team/requirements.md`)
- `docs/domain-models/<slug>.md`

### Phase 2 — Planning
Create Jira ticket → feature branch → implementation plan:
```bash
KEY=$(bash scripts/create-jira-ticket.sh "<summary>" "<description>" "Task")
bash scripts/update-jira-status.sh "$KEY" "In Progress"
bash scripts/git-flow.sh feature-start <ticket-number> <slug>
```
Write `docs/plans/<slug>.md`.

### Phase 3 — Implementation
Write all code. Follow `.devpilot/rules.md`.
Run lint + build + tests. Fix all failures before moving on.
Commit with conventional commits: `feat(<slug>): <description>`

### Phase 4 — QA
Verify every acceptance criterion from `docs/requirements/<slug>.md`.
Write `docs/qa/<slug>.md`. Verdict: PASS or BLOCKED.
Fix any BLOCKED items, then re-verify.

### Phase 5 — Review & PR
Review diff against `.devpilot/rules.md`.
Write `docs/reviews/<slug>.md`.
```bash
git add docs/
git commit -m "docs(<slug>): add requirements, plan, qa, review"
gh pr create --base <base_branch> --title "<KEY>: <desc>" --body "$(cat docs/reviews/<slug>.md)"
```

---

## Project Config

Read `project.config.md` at the start of every task:
- `engines.coding` — who is writing code right now
- `engines.runner` — how this session was launched
- `base_branch` — PR target
- `agents.*` — which agents are enabled
- `coding_models.*` — model config per engine

---

## Rules

Always read `.devpilot/rules.md` before writing any code.
Apply `.devpilot/skills/core-rules.md` throughout (it folds in get-shit-done).

---

## Commands Available

| Command file | What it does |
|---|---|
| `.claude/commands/ceo.md` | Express — plan → sprint → build, end to end |
| `.claude/commands/dp-plan.md` | PM brain: dedup against the backlog, write Epic→Story (no code) |
| `.claude/commands/dp-sprint.md` | Group the backlog into sprints, recommend run order |
| `.claude/commands/dp-build.md` | Build a whole sprint → one PR → develop |
| `.claude/commands/dp-test.md` | Derive test cases from ACs → write the missing tests → run the suite |
| `.claude/commands/dp-autofix.md` | Drive a PR's CI to green (bounded fix loop) → merge per `auto-merge.md` |
| `.claude/commands/dp-review-fix.md` | Read PR review comments → apply fixes → push |

Run any command:
```bash
bash scripts/run-command.sh dp-plan "your feature, issue, or requirement"
# or directly:
opencode    < .claude/commands/ceo.md   # pipe full prompt
antigravity < .claude/commands/ceo.md
```

---

## Deploy Pipeline

```
/dp-release sit <version>   → cut release branch → SIT
/dp-release uat             → approve UAT
/dp-release prd <version>   → merge to main → production
```

These are Claude Code slash commands. From terminal:
```bash
bash scripts/deploy-sit.sh <version>
bash scripts/deploy-prd.sh <version>
```
