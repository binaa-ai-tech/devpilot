# /binaa-models — Configure LLM models per agent

Arguments: **$ARGUMENTS**

Set or view the LLM model for any agent. Changes are written to `project.config.md` immediately.

---

## Usage

```
/binaa-models                                        ← show config + interactive wizard
/binaa-models backend github-copilot/gpt-5.3-codex  ← set one coding agent directly
/binaa-models frontend github-copilot/gpt-4o
/binaa-models ba claude-haiku-4-5-20251001
/binaa-models engine opencode                        ← switch coding engine
/binaa-models list                                   ← show available models
```

Agent names: `ba` · `lead` · `qa` · `frontend` · `backend` · `db` · `integration`
Engine names: `claude` · `opencode` · `antigravity`

---

## Step 1 — Read and display current config

Read `project.config.md`, then display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Model Configuration — <project_name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ENGINES
  ─────────────────────────────────────────────────────
  Coding:   <engines.coding>      (writes implementation code)
  Runner:   <engines.runner>      (runs /ceo from terminal)
  Fallback: <engines.fallback>    (when coding engine hits limits)

  PLANNING + QA  (Claude — non-coding phases)
  ─────────────────────────────────────────────────────
  ba          → <models.ba.tier1>
  lead        → <models.team_lead.tier1>
  qa          → <models.qa.tier1>

  CODING MODELS — opencode
  ─────────────────────────────────────────────────────
  frontend    → <coding_models.opencode.frontend>
  backend     → <coding_models.opencode.backend>
  db          → <coding_models.opencode.db>
  integration → <coding_models.opencode.integration>

  CODING MODELS — antigravity
  ─────────────────────────────────────────────────────
  frontend    → <coding_models.antigravity.frontend>
  backend     → <coding_models.antigravity.backend>
  db          → <coding_models.antigravity.db>
  integration → <coding_models.antigravity.integration>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Step 2 — Parse $ARGUMENTS

### Case A — `list`

Output the reference table below and stop:

```
  CLAUDE MODELS (ba · lead · qa)
  ─────────────────────────────────────────────────────
  claude-sonnet-4-6           ← best for planning + review (Team Lead)
  claude-haiku-4-5-20251001   ← fast + cheap (BA, QA)
  claude-opus-4-7             ← most capable, use sparingly

  OPENCODE / GITHUB COPILOT MODELS (coding engine: opencode)
  ─────────────────────────────────────────────────────
  github-copilot/gpt-4o              ← best all-round
  github-copilot/gpt-5.3-codex       ← strong code generation
  github-copilot/gpt-3.5-codex       ← fast and cheap
  github-copilot/claude-3.5-sonnet   ← strong reasoning + code quality
  github-copilot/gemini-2.5-pro      ← Google alternative

  Run: opencode model list   ← to see the full live list

  ANTIGRAVITY MODELS (coding engine: antigravity)
  ─────────────────────────────────────────────────────
  Run: antigravity model list   ← to see all available models
```

### Case B — `engine <name>` (switch coding engine)

Set `engines.coding` in `project.config.md` to `claude`, `opencode`, or `antigravity`.
Also offer to update `engines.runner` and `engines.fallback` to match.

Valid values: `claude` · `opencode` · `antigravity`

→ Go to **Step 3** to apply.

### Case C — `<agent> <model>` (direct set)

Parse:
- `AGENT` = first word (ba / lead / qa / frontend / backend / db / integration)
- `MODEL` = everything after the first space

Map agent → config field:

| Agent | Config field |
|-------|-------------|
| `ba` | `models.ba → tier1` |
| `lead` | `models.team_lead → tier1` |
| `qa` | `models.qa → tier1` |
| `frontend` | `coding_models.opencode.frontend` AND `coding_models.antigravity.frontend` |
| `backend` | `coding_models.opencode.backend` AND `coding_models.antigravity.backend` |
| `db` | `coding_models.opencode.db` AND `coding_models.antigravity.db` |
| `integration` | `coding_models.opencode.integration` AND `coding_models.antigravity.integration` |

For coding agents (frontend/backend/db/integration): if MODEL contains `github-copilot/`, update only the `opencode` block. Otherwise ask which engine's model the user wants to update, or update both if they confirm.

→ Go to **Step 3** to apply the change.

### Case D — no arguments (interactive wizard)

Ask for each agent in order. Press Enter to keep the current value:

```
Press Enter to keep the current model for each agent.

PLANNING + QA (Claude):
  ba    [<current>]: 
  lead  [<current>]: 
  qa    [<current>]: 

CODING ENGINE — opencode:
  frontend    [<current>]: 
  backend     [<current>]: 
  db          [<current>]: 
  integration [<current>]: 

CODING ENGINE — antigravity:
  frontend    [<current>]: 
  backend     [<current>]: 
  db          [<current>]: 
  integration [<current>]: 
```

Collect all changes, apply all in one go → **Step 3**.

---

## Step 3 — Apply changes to project.config.md

Use the **Edit tool** to update each changed field in `project.config.md`.

**For engine switch** (`engines.coding`, `engines.runner`, `engines.fallback`):
Find and replace the relevant line under `engines:`.

**For opencode coding agents** (frontend / backend / db / integration):
Find and replace the line under `coding_models:` → `opencode:` section.

**For antigravity coding agents**:
Find and replace the line under `coding_models:` → `antigravity:` section.

**For Claude agents** (ba / lead / qa):
Find and replace the `tier1:` line under the agent's section in `models:`.

---

## Step 4 — Sync agent frontmatter (Claude agents only)

For `ba`, `lead`, `qa` — update the `model:` line in the agent definition file:

```bash
# ba
sed -i.bak "s/^model: .*/model: <new-model>/" .claude/agents/team-ba.md && rm -f .claude/agents/team-ba.md.bak

# lead
sed -i.bak "s/^model: .*/model: <new-model>/" .claude/agents/team-lead.md && rm -f .claude/agents/team-lead.md.bak

# qa
sed -i.bak "s/^model: .*/model: <new-model>/" .claude/agents/team-qa.md && rm -f .claude/agents/team-qa.md.bak
```

Only run the sed for agents that were actually changed.

---

## Step 5 — Confirm

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  Models updated
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  engines.coding  → antigravity   ✅ changed
  backend (opencode)     → github-copilot/gpt-5.3-codex   ✅ changed
  frontend (antigravity) → <model>   ✅ changed
  qa             → claude-haiku-4-5-20251001  (unchanged)

  Saved: project.config.md
  <if Claude agent changed: Synced: .claude/agents/team-<agent>.md>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If nothing changed, output:
```
No changes made. Current config is unchanged.
```
