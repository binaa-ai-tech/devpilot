# /binaa reconfig — Re-run Configuration Wizard

Re-configure this project without reinstalling everything.

---

## Step 1 — Show current config

Read `project.config.md` and display:

```
Coding engine:  <engines.coding>
Runner:         <engines.runner>
Fallback:       <engines.fallback>

Coding models — opencode:
  Frontend:    <coding_models.opencode.frontend>
  Backend:     <coding_models.opencode.backend>
  DB:          <coding_models.opencode.db>
  Integration: <coding_models.opencode.integration>

Coding models — antigravity:
  Frontend:    <coding_models.antigravity.frontend>
  Backend:     <coding_models.antigravity.backend>
  DB:          <coding_models.antigravity.db>
  Integration: <coding_models.antigravity.integration>

Claude model routing (non-coding phases):
  BA:        <models.ba.tier1> → <tier2> → <tier3>
  Team Lead: <models.team_lead.tier1> → <tier2> → <tier3>
  QA:        <models.qa.tier1> → <tier2> → <tier3>

Active agents: <list enabled agents>
Base branch:   <base_branch>
```

Ask: "What would you like to change? [engine / models / claude-models / agents / branch / all]"

---

## Step 2 — Coding engine wizard (if engine or all)

```
Who writes the code?

  Current: <engines.coding>

  [1] claude (subagents)
      All phases run inside Claude. No external CLI needed.

  [2] opencode
      Claude handles BA, planning, QA, review.
      You run opencode in your terminal for all coding.

  [3] antigravity
      Claude handles BA, planning, QA, review.
      You run antigravity in your terminal for all coding.

  [4] keep current engine
```

Also ask:
```
Terminal runner (runs /ceo commands from bash scripts/ceo.sh)?
  Current: <engines.runner>
  [1] claude  [2] opencode  [3] antigravity  [4] keep current
```

```
Fallback when coding engine hits limits?
  Current: <engines.fallback>
  [1] opencode  [2] antigravity  [3] none  [4] keep current
```

If opencode is selected for coding or runner:

```
Configure opencode model per developer role:
(run: opencode model list — to see all available)

Common GitHub Copilot models:
  github-copilot/gpt-4o           — best all-round
  github-copilot/gpt-3.5-codex    — fast and cheap
  github-copilot/claude-3.5-sonnet — strong reasoning + code quality

Press Enter to keep current value for each.

  Frontend dev (Angular/React/Vue): [<current>] →
  Backend dev (.NET/Node/Python):   [<current>] →
  DB dev (migrations/SQL):          [<current>] →
  Integration dev (messaging):      [<current>] →
```

If antigravity is selected for coding or runner:

```
Configure antigravity model per developer role:
(run: antigravity model list — to see all available)

Press Enter to keep current value for each.

  Frontend dev (Angular/React/Vue): [<current>] →
  Backend dev (.NET/Node/Python):   [<current>] →
  DB dev (migrations/SQL):          [<current>] →
  Integration dev (messaging):      [<current>] →
```

Update `project.config.md → engines`, `coding_models.opencode`, `coding_models.antigravity` as needed.

---

## Step 3 — Claude model routing (BA, Team Lead, QA only)

For each of BA, Team Lead, and QA:

```
<Agent Name>
  Tier 1 (Claude Pro — primary):
    Current: <current>
    Options:
      [1] claude-sonnet-4-6      ← recommended for planning (Team Lead)
      [2] claude-haiku-4-5       ← recommended for lightweight tasks (BA, QA)
      [3] keep current
      [4] enter custom model ID
```

---

## Step 4 — Agent enable/disable wizard (if agents or all)

```
Active agents (Y/N):
  BA:          [Y] — always required
  Team Lead:   [Y] — always required
  Frontend:    [Y/N] — disable if no frontend in this project
  Backend:     [Y/N] — disable if no backend in this project
  DB:          [Y/N] — disable if no DB changes expected
  Integration: [Y/N] — enable if project has messaging/queues/services
  QA:          [Y] — always required
```

---

## Step 5 — Write updated config

Update `project.config.md` with all changes.

Sync `.claude/agents/` frontmatter — update `model:` for BA, Team Lead, QA only:
- `.claude/agents/team-lead.md` → `models.team_lead.tier1`
- `.claude/agents/team-ba.md` → `models.ba.tier1`
- `.claude/agents/team-qa.md` → `models.qa.tier1`

---

## Step 6 — Confirm

Display the updated config and confirm:

```
✅ Config updated.

Engines:
  Coding:   <engines.coding>
  Runner:   <engines.runner>
  Fallback: <engines.fallback>

Claude routing (non-coding phases):
  BA:        <tier1>
  Team Lead: <tier1>
  QA:        <tier1>

Coding models (opencode):  frontend · backend · db · integration
Coding models (antigravity): frontend · backend · db · integration

Agent files synced: .claude/agents/team-ba.md, team-lead.md, team-qa.md
Config saved: project.config.md
```
