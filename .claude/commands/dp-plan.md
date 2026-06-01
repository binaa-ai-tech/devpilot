# /dp-plan — Plan Phase (no code)

Input: **$ARGUMENTS** — a feature, issue, task, requirement, or enhancement.
May be raw text (`/dp-plan add CSV export to reports`) or an existing Jira key
(`/dp-plan MSK-50` → expand that issue into a full plan).

You are the **Project Manager**. You triage the input against the existing backlog,
**deduplicate and merge** related work, then write it into Jira as **Epic → Story**.
**No branch. No code.** When the backlog is ready, the user runs `/dp-sprint`.

---

## Step 0 — Load config

Read `project.config.md`. Extract `project_name`, `ticket_prefix`, `base_branch`, active agents.

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
```

If `$ARGUMENTS` is a Jira key (matches `^[A-Z]+-[0-9]+$`), fetch that issue's summary
+ description and use it as the input text; otherwise use `$ARGUMENTS` verbatim.

---

## Step 1 — Classify + slug

Classify intent: `feature` / `enhancement` / `bug` / `issue` / `task` / `requirement`.
Derive `SLUG` (lowercase, hyphens, ≤6 words). Carry `INTENT` forward.

---

## Step 2 — Scope reading via indexes (token-lean — do NOT broad-scan)

```bash
# Project index: caps codebase reading to 3–8 files.
find docs/project-index.md -mmin -120 2>/dev/null | grep -q . \
  || bash scripts/generate-project-index.sh
# Backlog index: the dedup brain. Refresh so matching is against current state.
bash scripts/generate-backlog-index.sh
```

Read `docs/project-index.md` and `docs/backlog/index.md`.

---

## Step 3 — Dedup ladder (the PM decision)

Match the new input against `docs/backlog/index.md` **only** — do not load full specs yet.

1. Extract `{area/components, keywords, intent}` from the input.
2. Score each backlog row by keyword + component overlap.
3. Read the full spec (`docs/requirements/<slug>.md`) of **only the top 1–3** candidates.
4. Classify against the best match:

| Verdict | Condition | Action |
|---------|-----------|--------|
| **DUPLICATE** | High match, same intent | Don't create new. Link `duplicates`, comment, optionally bump priority. |
| **FOLD-IN** | Same Story scope | Append the new ACs into the existing Story; link + close source as Duplicate. |
| **RELATED** | Same Epic, different slice | Create a new Story (Task) under the existing Epic. |
| **UNRELATED** | No strong match | Create a new Epic + its first Story. |

**Confidence gate:** act automatically on a **high-confidence** verdict. If the top score
is in the **gray band** (ambiguous), STOP and ask the user, showing the 1–2 candidates
(`key + title`) and your recommendation. Otherwise proceed.

---

## Step 4 — BA: write the durable spec to git

**Adopt the BA persona.** Read `.devpilot/prompts/team/ba-agent.md`. Apply
`.devpilot/skills/spec-first.md` — every Story must trace to verifiable acceptance criteria.

1. Read the relevant source files identified from the project index (3–8 max).
2. Write `docs/requirements/<SLUG>.md` from `.devpilot/templates/team/requirements.md`
   — user story, acceptance criteria, scope, data/API changes, edge cases. Document all
   assumptions; do not ask clarifying questions (except the Step 3 gray-band gate).
3. Write `docs/domain-models/<SLUG>.md` from `.devpilot/templates/team/domain-model.md`.
4. Count ACs → `AC_COUNT`. Determine scope: frontend / backend / DB / integration.
5. **Definition of Ready gate** — apply `.devpilot/skills/definition-of-ready.md`. If the
   Story passes (clear value, testable ACs, scoped, sized, deps known, deduped), mark it
   `ready`. If not, record what's missing on the Story and mark it `needs grooming` — it
   stays in the backlog and is flagged at `/dp-sprint`, never pulled into a sprint unclear.

---

## Step 5 — Write to Jira (per the Step 3 verdict)

```bash
SUMMARY="<one-line summary>"
USER_STORY=$(grep -A 5 "## User Story" docs/requirements/<SLUG>.md | head -5)
```

- **UNRELATED** → create Epic, then first Story under it:
  ```bash
  EPIC=$(bash scripts/create-jira-epic.sh "<epic summary>" "<epic goal>")          # no parent → Epic
  KEY=$(bash scripts/create-jira-epic.sh "$SUMMARY" "$USER_STORY" "$EPIC")         # parent → Story/Task
  ```
- **RELATED** → create Story under the matched Epic `<EPIC_KEY>`:
  ```bash
  KEY=$(bash scripts/create-jira-epic.sh "$SUMMARY" "$USER_STORY" "<EPIC_KEY>")
  ```
- **FOLD-IN** → target is the matched Story `<TARGET_KEY>`:
  ```bash
  bash scripts/add-jira-comment.sh "<TARGET_KEY>" "➕ Folded in: <SUMMARY>
New ACs appended — see docs/requirements/<SLUG>.md"
  # If the input was an existing key, link + close it as a duplicate of the target:
  [ -n "<SOURCE_KEY>" ] && bash scripts/link-jira-issues.sh "<SOURCE_KEY>" Duplicate "<TARGET_KEY>" \
    && bash scripts/update-jira-status.sh "<SOURCE_KEY>" "Done"
  KEY="<TARGET_KEY>"
  ```
- **DUPLICATE** → no new issue:
  ```bash
  [ -n "<SOURCE_KEY>" ] && bash scripts/link-jira-issues.sh "<SOURCE_KEY>" Duplicate "<EXISTING_KEY>"
  bash scripts/add-jira-comment.sh "<EXISTING_KEY>" "🔁 Duplicate request noted [$START_TIME]: <SUMMARY>"
  KEY="<EXISTING_KEY>"
  ```

Attach the spec to the resulting/target issue and log the plan:
```bash
bash scripts/update-jira-description.sh "$KEY" "$(head -80 docs/requirements/<SLUG>.md)"
bash scripts/add-jira-comment.sh "$KEY" "📋 Planned [$START_TIME] · Verdict: <VERDICT>
Intent: $INTENT · ACs: $AC_COUNT · Scope: <frontend/backend/DB/integration>
Spec: docs/requirements/<SLUG>.md
▶ Organize into a sprint: /dp-sprint"
```

Keep the issue in **To Do** — planning does not start work.

---

## Step 6 — Refresh the backlog index

```bash
bash scripts/generate-backlog-index.sh
```

---

## Final Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  PLANNED — added to backlog
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧭  Verdict:   <DUPLICATE | FOLD-IN | RELATED | UNRELATED>
📌  Jira:      <KEY>  (Epic: <EPIC_KEY>)   → To Do
📄  Spec:      docs/requirements/<SLUG>.md
✅  ACs:       <AC_COUNT>   ·   Scope: <...>
🗂  Backlog:   docs/backlog/index.md (<N> issues)

▶  Next:
   • Add more:        /dp-plan <next thing>
   • Organize sprint: /dp-sprint
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
