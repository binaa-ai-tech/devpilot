# /dp-setup — Admin: configure DevPilot

Usage: **/dp-setup [section]** — `fix` · `tracker [jira|azure|github|local|test]` · `pipelines` · `models [profile]` · `wizard` · `index` · empty = show current config.

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
   - **Tracker selected but not configured** → run the `tracker` section below.
   - **Git host can't automate PRs** → GitHub: `gh auth login` (the user runs it; on Claude Code
     on the web the GitHub MCP tools are used instead). Azure Repos: store a PAT with
     `bash scripts/devpilot-config.sh set azdo_pat=<token>` (scopes: Code R/W, Build Read).
3. Re-run `bash scripts/doctor.sh` and report before/after. Stop when clean or when the
   only remaining items need something outside the repo (an install, a login).

## (no arg) — show config
Summarize `project.config.md`: project name, base branch, tracker (`bash scripts/tracker.sh type`),
git host (`bash scripts/git-host.sh`), current version (`bash scripts/version.sh current`), merge
policy, active agents, the active model profile, and per-tier models:
```bash
bash scripts/model-profiles.sh show
```

## tracker [type] — connect Jira, Azure DevOps, GitHub Issues, or go local
Where Epics, Stories, Bugs and sprints live. No type given → ask with AskUserQuestion:
**Jira** · **Azure DevOps** · **GitHub Issues** · **Local only (no external tracker)**.

| Tracker | Values to collect | Where to get them |
|---------|-------------------|-------------------|
| `jira` | site URL, account email, API token, project key | https://id.atlassian.com/manage-profile/security/api-tokens |
| `azure` | org URL (`https://dev.azure.com/<org>`), project, PAT | User settings → Personal access tokens (Work Items R/W, Code R/W, Build Read) |
| `github` | nothing when `gh auth login` is done; otherwise a token with Issues R/W | GitHub → Settings → Developer settings → tokens |

Ask for the values (the user may paste them, or export them as environment variables of the same
name — `JIRA_API_TOKEN`, `AZDO_PAT`, `GITHUB_TOKEN` — and say "done"). Then one call stores them
in the gitignored `.devpilot/config.sh`, switches `tracker.type`, and tests the connection live:
```bash
bash scripts/tracker.sh setup jira   jira_base_url=https://<org>.atlassian.net jira_email=<email> jira_api_token=<token> jira_project_key=<KEY>
bash scripts/tracker.sh setup azure  azdo_org_url=https://dev.azure.com/<org> azdo_project=<project> azdo_pat=<token>
bash scripts/tracker.sh setup github github_token=<token>     # or just: gh auth login
bash scripts/tracker.sh use local && bash scripts/tracker.sh skip   # no external tracker
```
**Always finish with the live self-test** — it runs exactly the calls `/dp-deliver` makes against the
real tracker (create Epic → Story under it → child visible → search → sprint → In Progress → comment
→ description → Done → Epic closes → sprint closes) and deletes what it created:
```bash
bash scripts/tracker.sh selftest          # --keep leaves the test items for inspection
```
`/dp-setup tracker test` runs only this. Each ❌ names the step; the usual causes are permissions
(create / transition / delete / manage sprints) or a custom workflow with no path to Done. Search
⚠️ on Jira/GitHub is index delay — not a failure.

Optional Azure values: `azdo_team` (default "<project> Team") and `azdo_story_type` (auto-detected:
User Story · Product Backlog Item · Requirement · Issue). Then refresh the backlog map:
`bash scripts/generate-backlog-index.sh`. Existing local items stay in `docs/tasks/` for reference.

## pipelines — CI + CD + protection + environments (once per repo)
Everything between "PR merged" and "live in production", for the git host (`scripts/git-host.sh`):
```bash
bash scripts/generate-ci.sh           # CI (gate ladder on PRs) + CD (build once → DEV → SIT → UAT → PRD)
git add .github azure-pipelines*.yml && git commit -m "ci: devpilot CI/CD pipelines" && git push
bash scripts/protect-branches.sh      # CI required on develop + main (GitHub protection / Azure policies)
bash scripts/setup-environments.sh    # dev · sit · uat · prd — approvals on uat + prd
```
Then ask how each environment is deployed: a **deploy script** (`deploy/deploy.sh <env> <artifact-dir>
<version>` — App Service, IIS, Kubernetes …; offer to write it with the user) or a **deploy webhook**
(`DEPLOY_HOOK` secret per environment). Also collect `API_URL` / `FRONTEND_URL` per environment for
the smoke test. Azure needs a PAT with Code (Read, write & manage) + Build (Read & execute) and project
admin rights; without them each script prints the exact manual steps.
**Why protection matters on Azure:** without a build-validation policy, `azdo.sh pr-complete` refuses to
merge (CI would be skipped) unless `AZDO_ALLOW_UNPROTECTED=1`.

## secrets — where tokens / PATs live
`project.config.md → secrets.provider`: `file` (default, gitignored `.devpilot/config.sh`), `keychain`
(macOS Keychain / Linux Secret Service via `secret-tool`), or `azure-keyvault` (`az login` +
`secrets.vault`). Set it **before** `/dp-setup tracker` — `tracker.sh setup` then stores the token in the
provider and only the URLs / project names in config.sh. Environment variables always win (CI).

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
Walk the user through tracker (the `tracker` section), merge policy, versioning
(`versioning.bump: auto|off`), stack, active agents, and model profile, writing their answers into
`project.config.md`. Validate at the end:
```bash
bash scripts/devpilot-config.sh validate     # tracker ping + git host check
```

## index — refresh the project index (token-lean scoping source)
```bash
bash scripts/generate-project-index.sh
```
Regenerates `docs/project-index.md`, the file the team uses to scope codebase reading to
3–8 files instead of broad-scanning.
