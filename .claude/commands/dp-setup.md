# /dp-setup — Admin: configure DevPilot

Usage: **/dp-setup [section]** — `fix` · `models [profile]` · `wizard` · `index` · empty = show current config.

One place to tune the team. Reads `project.config.md` as the source of truth.

## fix — repair missing or invalid configuration (re-config without reinstalling)
Run the doctor, then fix every ⚠️/❌ that is a configuration problem — interactively,
one value at a time. Never touch values that are already valid.

1. ```bash
   bash scripts/doctor.sh
   ```
2. For each flagged item, resolve it with the user (AskUserQuestion when a choice is
   needed; sensible default offered):
   - **Missing identity values** (`project_name`, `ticket_prefix`, `base_branch`,
     `merge_policy`, `tracker.type`, `language`) → ask, then edit `project.config.md` in place.
   - **Invalid/empty model tiers or `model_mode`** → offer the three modes; apply with
     `bash scripts/model-profiles.sh apply|single …` (never hand-edit tiers if a command exists).
   - **Agent frontmatter drift** → `bash scripts/model-profiles.sh sync-agents`.
   - **Jira credentials incomplete** (`tracker: jira`) → walk the 3 steps: API token from
     https://id.atlassian.com/manage-profile/security/api-tokens, then
     ```bash
     bash scripts/devpilot-config.sh set jira_base_url=https://<org>.atlassian.net
     bash scripts/devpilot-config.sh set jira_email=<email>
     bash scripts/devpilot-config.sh set jira_api_token=<token>
     bash scripts/devpilot-config.sh validate     # live connection check
     ```
   - **gh missing/unauthenticated** with `tracker: github` or `merge_policy: auto` →
     tell the user to run `gh auth login` (can't be done for them).
3. Re-run `bash scripts/doctor.sh` and report before/after. Stop when clean or when the
   only remaining items need something outside the repo (an install, a login).

## (no arg) — show config
Summarize `project.config.md`: project name, base branch, tracker, merge policy, active
agents, the active model profile, and per-tier models:
```bash
bash scripts/model-profiles.sh show
```

## models [profile] — switch the model assignment
DevPilot runs on Claude only. Three **model modes** (recorded as `model_policy.model_mode`):
| Mode | What it means | How to set |
|------|---------------|------------|
| `recommended` *(default)* | task-balanced tiers via a named profile (below) | `model-profiles.sh apply <profile>` |
| `single` | ONE model for the whole team | `model-profiles.sh single <model-id>` |
| `per-team` | a model per role — edit `models.*` in `project.config.md` | then `model-profiles.sh sync-agents` |

A **profile** is a one-word preset over the `power / standard / lite` tiers; per-task routing
(`scripts/resolve-model.sh`) still picks the tier per task.
| Profile | Behavior |
|---------|----------|
| `auto` *(default)* | Opus for hard/architectural work, Sonnet normal, Haiku for light/BA/QA |
| `balanced` | Sonnet for real work, Haiku for light tasks — no Opus |
| `save` | token-saving: Haiku by default, Sonnet only when complex |

```bash
bash scripts/model-profiles.sh apply auto                  # or balanced | save
bash scripts/model-profiles.sh single claude-sonnet-5      # one model for the whole team
bash scripts/model-profiles.sh sync-agents                 # after editing models.* by hand
bash scripts/resolve-model.sh show                         # verify the tiers
```

## wizard — re-run configuration interactively
Walk the user through tracker, merge policy, stack, active agents, and model profile, writing
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
