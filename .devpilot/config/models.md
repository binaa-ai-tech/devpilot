# Model Routing — 3-Tier Configuration

Agent model assignments are stored in `project.config.md` (per-project)
and synced to `.claude/agents/<name>.md` frontmatter by the install/reconfig wizard.

Run `/dp-config wizard` anytime to change model assignments.
Run `/dp-config models` to switch the coding engine / per-layer models.

---

## Coding Engines

Three engines are supported for implementation code. Set in `project.config.md → engines.coding`.

| Engine | How to use | When to use |
|--------|-----------|-------------|
| `claude` | Fully automatic — Claude subagents write all code | Default, no external CLI needed |
| `opencode` | You run `opencode < brief.md` in terminal | GitHub Copilot models, external quota |
| `antigravity` | You run `antigravity < brief.md` in terminal | Antigravity models |

Claude always handles: BA, planning, QA, code review, PR.

---

## Task-balanced model tiers (power vs token)

Within the active engine family, the **model is chosen per task** by complexity
(`resolve-engine.sh`), balancing capability against token cost. Configure under
`project.config.md → coding_models.<family>`:

| Tier | When | Claude | opencode (GitHub Copilot) |
|------|------|--------|----------------------------|
| `power` | architectural / cross-cutting / high-risk | `claude-opus-4-8` | `github-copilot/gpt-5` |
| `standard` | normal feature & bug work (default) | `claude-sonnet-4-6` | `github-copilot/gpt-4o` |
| `lite` | simple / mechanical / BA / QA | `claude-haiku-4-5` | `github-copilot/gpt-4o-mini` |

**opencode + no Copilot:** if GitHub Copilot isn't available in opencode, devpilot
uses `coding_models.opencode.fallback`, or opencode's own default model when that's empty.

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

## Available Models — opencode (GitHub Copilot)

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

## Available Models — antigravity

Run `antigravity model list` in your terminal to see the current list.
Add model IDs to `project.config.md → coding_models.antigravity`.

---

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
3. Reports to user with exact fallback engine command (from `engines.fallback`):
   ```
   ⚠️  Claude limit hit — Backend Dev phase
   Fallback: <engines.fallback> engine

   Run: <fallback-engine> --model "<model>" < docs/fallback/user-export-backend.md

   Then: /ceo resume
   ```
4. `/ceo resume` reads `docs/fallback/<slug>-state.md` and continues from QA phase

---

## Changing Models

Edit `project.config.md` → `coding_models` or `models` section, then run `/dp-config models`
to confirm changes are applied.

Or re-run the full wizard: `/dp-config wizard`
