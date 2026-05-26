# /binaa — Command Reference

---

## Work — choose the right command

### Full pipeline (BA → plan → code → QA → PR)
| Command | When to use | Example |
|---------|-------------|---------|
| `/ceo <description>` | Large feature or complex bug — full BA + QA + PR | `/ceo add property search with filters` |

### Planning only (no code)
| Command | When to use | Example |
|---------|-------------|---------|
| `/ceo-plan <description>` | Analyze and save a plan to Jira — decide later when to execute | `/ceo-plan add PDF export for reports` |
| `/ceo-run <KEY>` | Execute a plan saved by `/ceo-plan` | `/ceo-run MSK-22` |

### Fast paths (no BA, no QA docs)
| Command | When to use | Example |
|---------|-------------|---------|
| `/ceo-fix <description>` | Bug fix — Team Lead scopes it, implement, PR | `/ceo-fix sessions table not created on startup` |
| `/ceo-fe <description>` | Frontend-only change you can describe precisely | `/ceo-fe fix mobile padding on listing card` |
| `/ceo-be <description>` | Backend-only change you can describe precisely | `/ceo-be fix GET /matches returning 500` |
| `/ceo-db <description>` | DB migration or schema change only | `/ceo-db add SavedByUser column to Matches` |
| `/ceo-int <description>` | Integration / external service change only | `/ceo-int wire Firebase push for new matches` |

---

## Decision guide

```
New capability or large change?
  └─ Yes → /ceo

Plan now, code later?
  └─ Yes → /ceo-plan  →  /ceo-run <KEY> when ready

Bug fix (root cause clear)?
  └─ Yes → /ceo-fix

Know it's one layer only?
  ├─ Frontend  → /ceo-fe
  ├─ Backend   → /ceo-be
  ├─ DB only   → /ceo-db
  └─ External  → /ceo-int
```

---

## Configuration
| Command | When to use | Example |
|---------|-------------|---------|
| `/binaa-models` | View + set LLM model per agent | `/binaa-models backend github-copilot/gpt-5.3-codex` |
| `/binaa-models list` | Show all available model options | `/binaa-models list` |
| `/binaa-index` | Force-refresh project index | `/binaa-index` |
| `/binaa reconfig` | Full config wizard (engine, agents, branch) | `/binaa reconfig` |

---

## Deploy pipeline
| Command | Stage | When |
|---------|-------|------|
| `/binaa-sit <version>` | SIT | After DEV testing passes |
| `/binaa-uat` | UAT | After SIT QA passes |
| `/binaa-prd <version>` | PRD | After UAT sign-off |
| `/binaa-hotfix <n> <slug> <version>` | Emergency | Production issue |

---

## Task logs

Every command writes a task log to `docs/tasks/<KEY>.md` with:
- Start time, end time, total duration
- Branch + commit hashes
- PR URL
- What was built

Read any past task: `cat docs/tasks/<KEY>.md`

---

## Full pipeline flow

```
/ceo-plan "feature"       ← analyze, save to Jira, no code
        ↓ review plan
/ceo-run MSK-XX           ← implement plan → QA → PR
        ↓ PR merged to develop
        ↓ CI auto-deploys DEV
/binaa-sit 1.2.0          ← CI auto-deploys SIT
/binaa-uat                ← Manual approval in GitHub Actions
/binaa-prd 1.2.0          ← Manual approval → PRD deploy
```
