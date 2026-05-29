# opencode config — devpilot

This directory configures opencode for the devpilot AI team workflow.

## How to use

```bash
# Run full pipeline
bash scripts/ceo.sh "add user authentication"

# Or pipe a command directly
opencode < .claude/commands/ceo.md
opencode < .claude/commands/ceo-fix.md
```

## Config files loaded automatically by opencode

| File | Purpose |
|---|---|
| `AGENTS.md` | Project context, workflow phases, rules |
| `.devpilot/rules.md` | Coding standards for this project's stack |
| `.opencode/config.json` | opencode project settings |

## Switching models

Edit `project.config.md → coding_models.opencode` or run:
```
/binaa-models   (from Claude Code)
```

Or edit `.opencode/config.json → model` directly for the default model when
running opencode without an explicit `--model` flag.
