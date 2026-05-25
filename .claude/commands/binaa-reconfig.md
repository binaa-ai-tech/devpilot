# /binaa reconfig — Re-run Model Configuration Wizard

Re-configure model routing for this project without reinstalling everything.

---

## Step 1 — Show current config

Read `project.config.md` and display:

```
Current model routing:
  BA:           <tier1> → <tier2> → <tier3>
  Team Lead:    <tier1> → <tier2> → <tier3>
  Frontend Dev: <tier1> → <tier2> → <tier3>
  Backend Dev:  <tier1> → <tier2> → <tier3>
  DB Agent:     <tier1> → <tier2> → <tier3>
  QA:           <tier1> → <tier2> → <tier3>

Active agents: <list enabled agents>
Base branch:   <base_branch>
```

Ask: "What would you like to change? [models / agents / branch / all]"

---

## Step 2 — Model routing wizard (if models or all)

For each enabled agent, present:

```
<Agent Name>
  Tier 1 (Claude Pro primary):
    Current: <current>
    Options:
      [1] claude-sonnet-4-6      ← recommended for planning/implementation
      [2] claude-haiku-4-5       ← recommended for lightweight tasks (BA, QA)
      [3] keep current
      [4] enter custom model ID

  Tier 2 (opencode fallback when Claude hits limits):
    Current: <current>
    Options:
      [1] copilot: GPT-5.4       ← best for implementation (Frontend, Backend)
      [2] copilot: GPT-5.2       ← strong for SQL/migrations (DB)
      [3] copilot: Gemini 2.5 Pro ← best for planning/reasoning (Team Lead)
      [4] copilot: Gemini 3.5 Flash ← fast lightweight (BA, QA)
      [5] copilot: GPT-5-mini    ← cheapest (QA)
      [6] keep current
      [7] enter custom model name

  Tier 3 (free last resort):
    Current: <current>
    Options:
      [1] free: DeepSeek V4 Flash Free  ← recommended for code tasks
      [2] free: Nemotron 3 Super Free   ← recommended for doc tasks
      [3] keep current
```

---

## Step 3 — Agent enable/disable wizard (if agents or all)

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

## Step 4 — Write updated config

Update `project.config.md` with all changes.

Sync `.claude/agents/` frontmatter — update each `model:` field to match the new Tier 1 model:
- `.claude/agents/team-lead.md` → `models.team_lead.tier1`
- `.claude/agents/team-ba.md` → `models.ba.tier1`
- `.claude/agents/team-frontend.md` → `models.frontend.tier1`
- `.claude/agents/team-dotnet.md` → `models.backend.tier1`
- `.claude/agents/team-qa.md` → `models.qa.tier1`

---

## Step 5 — Confirm

Display the updated routing table and confirm:

```
✅ Model config updated.

New routing:
  BA:           claude-haiku-4-5 → Gemini 3.5 Flash → DeepSeek V4 Flash Free
  Team Lead:    claude-sonnet-4-6 → Gemini 2.5 Pro → DeepSeek V4 Flash Free
  ...

Agent files synced: .claude/agents/*.md
Config saved: project.config.md
```
