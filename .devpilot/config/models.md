# Model Configuration — Claude, balanced per task

DevPilot runs on **Claude only**. Every agent has a role model, and each task is routed to a
tier by complexity so hard work gets the strongest model and simple work stays cheap.

## Tiers

| Tier | When | Model (`auto` profile) |
|------|------|------------------------|
| `power` | architectural / cross-cutting / high-risk / large changes | `claude-opus-5-5` |
| `standard` | normal feature & bug work (default) | `claude-sonnet-5` |
| `lite` | simple / mechanical changes, BA and QA work | `claude-haiku-4-5-20251001` |

`scripts/resolve-model.sh suggest "<task>"` classifies a task and returns its tier + model;
`/dp-build` spawns implementation agents on Opus when a sprint resolves to `power`.

## Role models (`project.config.md → models.*`, synced to `.claude/agents/*.md`)

| Agent | `auto` | `balanced` | `save` |
|-------|--------|------------|--------|
| BA (`team-ba`) | Haiku | Haiku | Haiku |
| Team Lead (`team-lead`) | Sonnet | Sonnet | Haiku |
| QA (`team-qa`) | Haiku | Haiku | Haiku |
| Frontend — Angular (`team-frontend`) | Sonnet | Sonnet | Haiku |
| Backend — .NET (`team-dotnet`) | Sonnet | Sonnet | Haiku |
| Power tier (escalation) | Opus | Sonnet | Sonnet |

## Profiles and modes

| Mode | Meaning | Set with |
|------|---------|----------|
| `recommended` *(default)* | a one-word profile over the tiers: `auto` · `balanced` · `save` | `/dp-setup models <profile>` |
| `single` | one model for the whole team | `bash scripts/model-profiles.sh single <model-id>` |
| `per-team` | a model per role | edit `models.*` → `bash scripts/model-profiles.sh sync-agents` |

```bash
bash scripts/model-profiles.sh apply auto      # or balanced | save
bash scripts/model-profiles.sh show            # current profile + tiers
bash scripts/resolve-model.sh show             # the three tier models
```

## Usage limits

When a run hits a Claude usage limit (`self-heal` Part 2) it first finishes the phase on the
standard tier if it was on power; if the limit is hard it checkpoints to
`docs/tasks/<KEY>-checkpoint.json`, pushes what's green, and stops. `/dp-deliver resume`
continues from the exact phase once the limit resets.
