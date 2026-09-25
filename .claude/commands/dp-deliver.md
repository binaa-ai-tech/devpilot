# /dp-deliver — Requirement → versioned PR → merged into develop → tickets & sprint closed

Input: **$ARGUMENTS** — a feature, bug, or requirement in plain words, or an existing tracker
key (`MSK-12`, `ADO-345`, `GH-7`). Optional trailing flag: `--to sit` also cuts the SIT release
after the merge. `/dp-deliver resume` continues an interrupted run from its checkpoint.

The walk-away path. One command runs the **whole team**:

```
tracker check → PLAN (dedup vs tracker + child tasks) → SPRINT → BUILD (Angular ║ .NET)
→ QA (Vitest · xUnit + SQL Server · Playwright) → REVIEW → version bump → PR into develop
→ CI green → merge → close items, Epic, sprint → back on develop  [→ SIT with --to sit]
```

Works with any tracker — **Jira, Azure DevOps Boards, GitHub Issues, or none (local)** — and any
git host — **GitHub or Azure Repos**. Every tracker call goes through `scripts/tracker.sh`; every
PR call through `scripts/open-pr.sh` / `scripts/azdo.sh` / `gh` / GitHub MCP.

> ## 🚦 Invariant 1 — the tracker comes first
> The PLAN phase (Step 1) MUST produce a work item key before a single line of code —
> an existing one (DUPLICATE / FOLD-IN) or a new Epic→Story / Bug. Step 1 ends with
> `tracker.sh assert-key`; never branch, edit, or spawn a build agent before it passes.
> With no external tracker the key is a local one (`LOCAL-12`, `docs/tasks/`) — the rule still holds.
> **A P0/P1 bug is refused** (`tracker.sh hotfix-gate`) and redirected to `/dp-hotfix`.

> ## 🤖 Invariant 2 — autonomous; the only questions allowed
> 1. **Tracker not configured** (Step 0) — once: connect it now or continue without it.
> 2. **Gray-zone dedup** (Step 1) — the request might be a duplicate; the user decides.
>
> Never pause to ask the user to test, review, or approve before merge. QA is `team-qa` + the
> automated suites, review is the Team Lead gate, the merge gate is `auto-merge.md`.
> Legitimate stops short of merge: a red gate the bounded fix loop couldn't clear (escalate with
> the self-heal template) or `merge_policy: pr-only`. Production is never touched.

Models are Claude only, balanced per task by `scripts/resolve-model.sh`.

---

## Step 0 — Parse input + tracker preflight

```bash
TASK="$ARGUMENTS"; PROMOTE_TO=""
case "$TASK" in *"--to sit"*) PROMOTE_TO="sit"; TASK="${TASK/--to sit/}" ;; esac
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | awk '{print $2}' | tr -d '"')
bash scripts/tracker.sh check; TRK_RC=$?
bash scripts/git-host.sh check || true      # informs the PR step; never blocks here
```

If `$TASK` is `resume`: `bash scripts/checkpoint.sh latest`, then
`bash scripts/checkpoint.sh show <KEY>`, and continue from its `next_phase` — never redo a
completed phase.

**`TRK_RC = 0`** → continue. **`TRK_RC = 2`** (a tracker is selected but has no credentials) or
**`TRK_RC = 3`** (no tracker chosen yet) → ask **one** question with AskUserQuestion:

> *"No work tracker is connected. Connect one now, or continue without it?"*
> Options: **Connect Jira** · **Connect Azure DevOps** · **Connect GitHub Issues** ·
> **Continue without a tracker** (put the configured one first when `TRK_RC = 2`).

- **Connect …** → ask for the values it needs (the question's "Other" box or a follow-up
  message). Mention they may instead export them as environment variables
  (`JIRA_API_TOKEN`, `AZDO_PAT`, `GITHUB_TOKEN`, …) and say "done" — secrets never land in git
  (`.devpilot/config.sh` is gitignored). Then:
  ```bash
  bash scripts/tracker.sh setup jira   jira_base_url=… jira_email=… jira_api_token=… jira_project_key=…
  bash scripts/tracker.sh setup azure  azdo_org_url=https://dev.azure.com/<org> azdo_project=… azdo_pat=…
  bash scripts/tracker.sh setup github github_token=…        # or: gh auth login
  ```
  `setup` stores, switches `tracker.type`, and tests live. On failure show the error and offer
  **Retry** or **Continue without a tracker** — never loop more than once.
- **Continue without a tracker** → `bash scripts/tracker.sh skip`. The run uses local items
  (`docs/tasks/`); later runs stop asking until a tracker is connected (`/dp-setup tracker`).
- **No human available** (CI, scheduled run) or `tracker.when_unconfigured: skip` → skip
  automatically, never block.

---

## Step 1 — PLAN (the /dp-plan brain)

Execute **`/dp-plan` Steps 1–6** on `$TASK`:
- classify intent + severity + slug (carry `$INTENT`, `$SLUG`)
- `tracker.sh hotfix-gate "$INTENT" "$SEVERITY"` — P0/P1 stops here
- **dedup against the live tracker** (`tracker.sh search`) and the backlog index, then
  **open the top 1–3 candidates with `tracker.sh show`** — their description AND their child
  items (existing Stories/Tasks under them) — so no work is created twice
- write the spec to git + the item(s) into the tracker

**Stop only** for a gray-band dedup verdict (ask, then continue), or when the request is
**already delivered / in flight** — a matching item is Done, or has an open branch/PR — in which
case report the existing key + link and end the run (nothing to build).

Capture `<STORY_KEYS>` (and `<EPIC_KEY>` when there is one). **Hard gate:**
```bash
bash scripts/tracker.sh assert-key <STORY_KEYS> || exit 1
```

---

## Step 2 — SPRINT (routed by intent)

- **`feature` / `enhancement` / `task` / `requirement`** → its own sprint:
  ```bash
  SPRINT_ID=$(bash scripts/tracker.sh sprint create "deliver-${SLUG}-$(date +%Y%m%d)")
  bash scripts/tracker.sh sprint assign "$SPRINT_ID" <STORY_KEYS>
  bash scripts/tracker.sh sprint start "$SPRINT_ID"
  ```
- **`bug` / `issue`** (P2/P3) → joins the active sprint; creates one only if none is active:
  ```bash
  SPRINT_ID=$(bash scripts/tracker.sh sprint active)
  [ -z "$SPRINT_ID" ] && SPRINT_ID=$(bash scripts/tracker.sh sprint create "deliver-bugfix-$(date +%Y%m%d)")
  bash scripts/tracker.sh sprint assign "$SPRINT_ID" <STORY_KEYS>
  ```

Jira → a Scrum sprint (or a Fix Version on boards without Scrum) · Azure DevOps → an iteration ·
GitHub → a milestone · local → `docs/sprints/<id>.md`.

---

## Step 3 — BUILD → QA → REVIEW → VERSION → PR → MERGE → CLOSE (the /dp-build pipeline)

Execute **`/dp-build` Steps 0–7** for `$SPRINT_ID` with `<STORY_KEYS>` and `$INTENT`:
one branch (`feature/<key>-<slug>`) → Angular ║ .NET implementation → QA → review gate →
**version bump from develop's current version** (feature → MINOR, bug → PATCH) → **one PR into
`develop` titled `[vX.Y.Z] …`** → gates green → **merge** → `close-delivery.sh` closes the
Stories, the Epic (once all its children are Done) and the sprint (once nothing in it is open),
then checks out `develop` and pulls.

If CI goes red after the PR opens, run the `/dp-pr` loop on it — never stop at "PR opened".
Checkpoint after every phase (`bash scripts/checkpoint.sh save <KEY> <phase> <next_phase>`).

## Step 4 — Promote (only with `--to sit`)

After a **confirmed** merge: `/dp-release sit` — it releases the version develop now carries
(the one this run set). UAT and PRD stay separate, human-gated steps.

---

## Final Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖  /dp-deliver — planned → built → tested → reviewed → merged
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧭  Dedup:    <NEW | FOLD-IN into KEY | RELATED to EPIC>
📌  Items:    <KEYS> → Done   ·  Epic: <EPIC_KEY> <Done | open (n left)>
🗂  Sprint:   <SPRINT_ID> <closed | open (n left)>
🔖  Version:  v<X.Y.Z>  (<minor|patch>)
🔀  PR:       <PR_URL> → develop  (merged, branch deleted)
🧪  QA:       Vitest ✅ · xUnit ✅ · Playwright ✅  → docs/qa/<slug>.md
📍  Now on:   develop (pulled)
──────────────────────────────────────────────────────
🚀  Next:  /dp-release sit → uat → prd
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
With `--to sit`, replace the last line with the SIT release branch + URL.
