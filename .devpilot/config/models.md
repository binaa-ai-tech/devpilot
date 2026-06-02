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

## Model profiles (pick one word — powerful + easy)

Setup and `/dp-config models` ask for a **profile**, not a tier matrix. A profile is a
preset over the `power / standard / lite` tiers; per-task routing (`resolve-engine.sh` +
skills) still picks the tier per task — the profile only decides which model each tier
maps to. Stored as `project.config.md → engines.coding_profile`. Default: `auto`.

**Claude profiles**
| Profile | power → | standard → | lite → | Use when |
|---------|---------|------------|--------|----------|
| `auto` *(default)* | Opus | Sonnet | Haiku | You want max capability when a task is genuinely hard |
| `balanced` | Sonnet | Sonnet | Haiku | Solid everywhere, never spend Opus quota |
| `save` | Sonnet | Haiku | Haiku | Keep tokens low; escalate to Sonnet only when complex |

**opencode profiles** — mapped onto whatever `opencode models` reports live:
| Profile | power → | standard → | lite → |
|---------|---------|------------|--------|
| `recommended` *(default)* | strongest coder (e.g. gpt-5) | solid all-round (gpt-4o) | fast-cheap (gpt-4o-mini) |
| `balanced` | gpt-4o | gpt-4o | gpt-4o-mini |
| `save` | gpt-4o-mini | gpt-4o-mini | gpt-4o-mini |

**antigravity profiles** — same `recommended | balanced | save`, mapped from the live
`antigravity model list` (heuristics: `pro/ultra` → power, `flash/mini` → lite). There are **no
curated fallback ids** — if antigravity isn't installed, tiers stay blank until you re-run
`/dp-config models <profile>` once it is.

Apply / inspect:
```bash
bash scripts/model-profiles.sh apply claude auto         # or balanced | save
bash scripts/model-profiles.sh apply opencode recommended
bash scripts/model-profiles.sh apply antigravity recommended
bash scripts/model-profiles.sh opencode-list             # your live opencode models
bash scripts/model-profiles.sh antigravity-list          # your live antigravity models
bash scripts/model-profiles.sh show                      # current profile + tiers
```

### Underlying tiers
Profiles write these; you can also edit them directly under `project.config.md →
coding_models.<family>`:

| Tier | When | Claude (`auto`) | opencode (`recommended`) |
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

Easiest — switch the profile (one word):
```bash
/dp-config models save          # or: auto | balanced  (claude)
/dp-config models recommended   # or: balanced | save  (opencode)
```
Or apply directly: `bash scripts/model-profiles.sh apply claude save`.

Fine-grained — edit `project.config.md → coding_models` (or `models`) and run
`/dp-config models` to confirm. Or re-run the full wizard: `/dp-config wizard`.
