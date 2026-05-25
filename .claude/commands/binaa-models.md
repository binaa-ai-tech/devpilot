# /binaa-models — Configure LLM models per agent

Arguments: **$ARGUMENTS**

Set or view the LLM model for any agent. Changes are written to `project.config.md` immediately.

---

## Usage

```
/binaa-models                                        ← show config + interactive wizard
/binaa-models backend github-copilot/gpt-5.3-codex  ← set one agent directly
/binaa-models frontend github-copilot/gpt-4o
/binaa-models ba claude-haiku-4-5-20251001
/binaa-models list                                   ← show available models
```

Agent names: `ba` · `lead` · `qa` · `frontend` · `backend` · `db` · `integration`

---

## Step 1 — Read and display current config

Read `project.config.md`, then display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Model Configuration — <project_name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  PLANNING + QA  (Claude — non-coding phases)
  ─────────────────────────────────────────────────────
  ba          → <models.ba.tier1>
  lead        → <models.team_lead.tier1>
  qa          → <models.qa.tier1>

  CODING  (opencode — all implementation)
  ─────────────────────────────────────────────────────
  frontend    → <implementation.model_frontend>
  backend     → <implementation.model_backend>
  db          → <implementation.model_db>
  integration → <implementation.model_integration>

  Engine: <implementation.engine>
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

  OPENCODE / GITHUB COPILOT MODELS (frontend · backend · db · integration)
  ─────────────────────────────────────────────────────
  github-copilot/gpt-4o              ← best all-round
  github-copilot/gpt-5.3-codex       ← strong code generation
  github-copilot/gpt-3.5-codex       ← fast and cheap
  github-copilot/claude-3.5-sonnet   ← strong reasoning + code quality
  github-copilot/gemini-2.5-pro      ← Google alternative

  Run: opencode model list   ← to see the full live list
```

### Case B — `<agent> <model>` (direct set)

Parse:
- `AGENT` = first word (ba / lead / qa / frontend / backend / db / integration)
- `MODEL` = everything after the first space

Map agent → config field:
| Agent | Config field |
|-------|-------------|
| `ba` | `models.ba → tier1` |
| `lead` | `models.team_lead → tier1` |
| `qa` | `models.qa → tier1` |
| `frontend` | `implementation.model_frontend` |
| `backend` | `implementation.model_backend` |
| `db` | `implementation.model_db` |
| `integration` | `implementation.model_integration` |

→ Go to **Step 3** to apply the change.

### Case C — no arguments (interactive wizard)

Ask for each agent in order. Press Enter to keep the current value:

```
Press Enter to keep the current model for each agent.

PLANNING + QA (Claude):
  ba    [<current>]: 
  lead  [<current>]: 
  qa    [<current>]: 

CODING (opencode):
  frontend    [<current>]: 
  backend     [<current>]: 
  db          [<current>]: 
  integration [<current>]: 
```

Collect all changes, apply all in one go → **Step 3**.

---

## Step 3 — Apply changes to project.config.md

Use the **Edit tool** to update each changed field in `project.config.md`.

**For opencode agents** (frontend / backend / db / integration):
Find and replace the `model_<agent>:` line under `implementation:`:
```yaml
# before:
  model_backend:     "github-copilot/gpt-4o"
# after:
  model_backend:     "github-copilot/gpt-5.3-codex"
```

**For Claude agents** (ba / lead / qa):
Find and replace the `tier1:` line under the agent's section in `models:`:
```yaml
# before:
  ba:
    tier1: claude-haiku-4-5-20251001
# after:
  ba:
    tier1: claude-sonnet-4-6
```

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

  backend     → github-copilot/gpt-5.3-codex   ✅ changed
  frontend    → github-copilot/gpt-4o           (unchanged)

  Saved: project.config.md
  <if Claude agent changed: Synced: .claude/agents/team-<agent>.md>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If nothing changed, output:
```
No changes made. Current config is unchanged.
```
