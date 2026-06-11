# /dp-config — Configure DevPilot

Usage: **/dp-config [section]** — `models [profile]` · `wizard` · `index` · empty = show current config.

One place to tune the engine. Reads `project.config.md` as the source of truth.

## (no arg) — show config
Summarize `project.config.md`: project name, base branch, tracker, active agents,
`engines.coding`, the active `coding_profile`, and per-tier model routing. Helper:
```bash
bash scripts/model-profiles.sh show
```

## models [profile] — switch the model assignment
Three **model modes** (recorded as `engines.model_mode`):
| Mode | What it means | How to set |
|------|---------------|------------|
| `recommended` *(default)* | task-balanced tiers via a named profile (below) | `model-profiles.sh apply <family> <profile>` |
| `single` | ONE model for the whole team | `model-profiles.sh single <family> <model-id>` |
| `per-team` | a model per role — edit `models.*` (Claude roles) / `layer_models.*` (non-claude layers) | edit config → `model-profiles.sh sync-agents` |

A **profile** is a one-word preset over the `power / standard / lite` tiers. Per-task
routing (`resolve-engine.sh` + skills) still picks the tier per task — the profile only
decides which model each tier maps to. The default profile is `auto`.

**Claude** (`engines.coding: claude`):
| Profile | Behavior |
|---------|----------|
| `auto` *(default)* | Opus for hard/architectural work, Sonnet normal, Haiku for light/BA/QA |
| `balanced` | Sonnet for real work, Haiku for light tasks — no Opus |
| `save` | token-saving: Haiku by default, Sonnet only when complex |

**opencode** (`engines.coding: opencode`) — models are read live from `opencode models`:
| Profile | Behavior |
|---------|----------|
| `recommended` *(default)* | strongest coder / solid all-round / fast-cheap |
| `balanced` | solid all-round on every tier |
| `save` | fast & cheap everywhere |

**antigravity** (`engines.coding: antigravity`) — same `recommended | balanced | save`, mapped
from the live `antigravity model list`. No curated fallback ids: if antigravity isn't installed,
tiers are left blank — re-run this after installing it.

Apply a profile or mode (updates `project.config.md` + syncs Claude agent frontmatter):
```bash
bash scripts/model-profiles.sh apply claude auto             # or balanced | save
bash scripts/model-profiles.sh apply opencode recommended    # or balanced | save
bash scripts/model-profiles.sh apply antigravity recommended # or balanced | save
bash scripts/model-profiles.sh single claude claude-sonnet-4-6   # one model for the whole team
bash scripts/model-profiles.sh sync-agents                   # after editing models.* by hand (per-team)
bash scripts/model-profiles.sh opencode-list                 # see your live opencode models
bash scripts/model-profiles.sh antigravity-list              # see your live antigravity models
```
For fine-grained control, edit `coding_models.<family>.{power,standard,lite}` (tiers),
`models.<role>.tier1` (Claude roles incl. `frontend_dev`/`backend_dev`), or
`layer_models.<layer>` (per-layer pins) directly.
Validate with `scripts/resolve-engine.sh effective`.

## wizard — re-run configuration interactively
Walk the user through tracker, stack, active agents, engines, and model routing, writing
their answers into `project.config.md`. Helper for non-interactive defaults:
```bash
bash scripts/devpilot-config.sh   # if present — seeds/validates project.config.md
```

## index — refresh the project index (token-lean scoping source)
```bash
bash scripts/generate-project-index.sh
```
Regenerates `docs/project-index.md`, the file the team uses to scope codebase reading to
3–8 files instead of broad-scanning.
