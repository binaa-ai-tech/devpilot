# Model Routing — 3-Tier Configuration

Agent model assignments are stored in `project.config.md` (per-project)
and synced to `.claude/agents/<name>.md` frontmatter by the install/reconfig wizard.

Run `/binaa reconfig` anytime to change model assignments.

---

## Your Setup: Claude Pro + GitHub Copilot via opencode

### 3-Tier Model Stack

```
Tier 1 — Claude Pro (primary, in-process)
Tier 2 — GitHub Copilot via opencode CLI (fallback when Claude hits limits)
Tier 3 — OpenCode Zen Free (last resort, zero cost)
```

---

## Recommended Routing (Normal Projects — No Opus)

| Agent | Tier 1 (Claude Pro) | Tier 2 (Copilot/opencode) | Tier 3 (Free) |
|-------|--------------------|-----------------------------|----------------|
| BA | claude-haiku-4-5 | Gemini 3.5 Flash | DeepSeek V4 Flash Free |
| Team Lead | claude-sonnet-4-6 | Gemini 2.5 Pro | DeepSeek V4 Flash Free |
| Frontend Dev | claude-sonnet-4-6 | GPT-5.4 | DeepSeek V4 Flash Free |
| Backend Dev | claude-sonnet-4-6 | GPT-5.4 | DeepSeek V4 Flash Free |
| DB Agent | claude-sonnet-4-6 | GPT-5.2 | DeepSeek V4 Flash Free |
| Integration | claude-sonnet-4-6 | GPT-5.4 | DeepSeek V4 Flash Free |
| QA | claude-haiku-4-5 | GPT-5-mini | Nemotron 3 Super Free |

**Why no Opus:** Normal projects don't need it. Sonnet 4.6 handles architecture,
planning, and review well. Opus burns daily limits fast on routine work.

---

## Available Models in opencode (GitHub Copilot)

| Model | Best for |
|-------|---------|
| GPT-5.4 | Heavy implementation — best coder available |
| GPT-5.2 | Strong coding, SQL, migrations |
| GPT-5-mini | Light tasks, boilerplate, structured writing |
| GPT-5.4 Mini | Fast medium tasks |
| GPT-4.1 | Reliable general coding |
| Gemini 2.5 Pro | Architecture, reasoning, planning |
| Gemini 3.1 Pro Preview | Strong reasoning |
| Gemini 3.5 Flash | Fast docs, BA tasks, lightweight |
| Gemini 3 Flash | Fast lightweight tasks |
| Claude Sonnet 4.6 | Same as Tier 1 but different quota pool |
| Claude Sonnet 4.5 | Slightly older, reliable fallback |
| Claude Haiku 4.5 | Fast lightweight via Copilot quota |

## Available Models (OpenCode Zen Free)

| Model | Best for |
|-------|---------|
| DeepSeek V4 Flash Free | Code generation, boilerplate — free |
| Nemotron 3 Super Free | Doc writing, simple rewrites — free |

---

## Fallback Trigger — How It Works

When Claude hits a rate/context limit during an agent phase:

1. `self-heal.md` detects the limit signal
2. Saves full task context to `docs/fallback/<slug>-<phase>.md`
3. Reports to user with exact opencode command:
   ```
   ⚠️  Claude limit hit — Backend Dev phase
   Fallback: GPT-5.4 via opencode

   Run: opencode --model "GPT-5.4" < docs/fallback/user-export-backend.md

   Then: /ceo resume
   ```
4. `/ceo resume` reads `docs/fallback/<slug>-state.md` and continues from QA phase

---

## Changing Models

Edit `project.config.md` → `models` section, then run:

```bash
bash scripts/sync-model-config.sh
```

This updates `.claude/agents/<name>.md` frontmatter to match `project.config.md`.
Or re-run the full wizard: `/binaa reconfig`
