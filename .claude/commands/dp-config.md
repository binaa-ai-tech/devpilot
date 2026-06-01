# /dp-config — Configure DevPilot

Usage: **/dp-config [section]** — `models` · `wizard` · `index` · empty = show current config.

One place to tune the engine. Reads `project.config.md` as the source of truth.

## (no arg) — show config
Summarize `project.config.md`: project name, base branch, tracker, active agents,
`engines.coding`, and per-layer model routing.

## models — set per-agent / per-layer models
Edit the `engines` + `models` block in `project.config.md` (frontend / backend / db /
integration → engine + model). Validate with `scripts/resolve-engine.sh effective`.

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
