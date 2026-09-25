# /dp-plan — Plan a requirement into tracker items (no code)

Input: **$ARGUMENTS** — a feature, issue, task, requirement, or enhancement, as text
(`/dp-plan add CSV export to reports`) or an existing tracker key (`/dp-plan MSK-50`,
`/dp-plan ADO-345`, `/dp-plan GH-7` → expand that item into a full plan).

You are the **Product Owner / BA**. Triage the input against what already exists in the tracker,
**deduplicate and merge** related work — including the child Stories/Tasks already under a
matching item — then write it as **Epic → Story** (or one **Bug**). **No branch. No code.**
Next: `/dp-sprint`, or `/dp-deliver` for the full run.

All tracker calls go through `scripts/tracker.sh` — Jira, Azure DevOps, GitHub Issues, or local.

---

## Step 0 — Load config + tracker preflight

```bash
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | awk '{print $2}' | tr -d '"')
bash scripts/tracker.sh check; TRK_RC=$?
```
`TRK_RC` 2 or 3 → run the **tracker question from `/dp-deliver` Step 0** (connect now or continue
without; skip automatically when no human is present). Then:

If `$ARGUMENTS` is a key (`^[A-Z][A-Z0-9_]*-[0-9]+$`): `bash scripts/tracker.sh show <KEY>` and use
its title + description as the input (`SOURCE_KEY=<KEY>`). Otherwise use `$ARGUMENTS` verbatim.

---

## Step 1 — Classify + slug

Intent: `feature` / `enhancement` / `bug` / `issue` / `task` / `requirement`.
`SLUG` = lowercase, hyphens, ≤6 words. Carry `INTENT` forward.

**Bugs (`bug` / `issue`):** assign a severity `P0`–`P3` (`$SEVERITY`). A bug is one typed
**Bug** item (no Epic), gets the lighter spec in Step 4, and follows the bug DoD
(reproduce before fixing). **P0/P1 belong on `/dp-hotfix`:**
```bash
bash scripts/tracker.sh hotfix-gate "$INTENT" "$SEVERITY" || exit 1
```

---

## Step 2 — Scope reading via indexes (token-lean — never broad-scan)

```bash
bash scripts/generate-project-index.sh               # hash-gated: free when nothing changed
bash scripts/generate-backlog-index.sh               # compact map of every tracker item
bash scripts/scope.sh --save "$SLUG" "<task description>"   # reused by every later phase
```
Read only `docs/project-index.md`, `docs/backlog/index.md`, the scope output, then the top 3–8
scoped files. Never read `docs/index/*.md` shards wholesale.

---

## Step 3 — Dedup ladder (the PO decision)

1. **Live search** — the tracker, including Done items:
   ```bash
   bash scripts/tracker.sh search "<summary + 3–6 domain keywords>"
   ```
   Rows: `SCORE KEY TYPE STATE CATEGORY PARENT TITLE`, best first. Add strong matches from
   `docs/backlog/index.md` (items the search wording missed).
2. **Open the top 1–3 candidates** — never more:
   ```bash
   bash scripts/tracker.sh show <KEY>      # description + its child Stories/Tasks
   ```
   Read the **children** too: an Epic may already have a Story or Task covering this request,
   and a Story may already have the Task. Compare against *those*, not just the parent's title.
3. **In flight?** — `git ls-remote --heads origin | grep -i -e "<candidate key>" -e "<slug>"`.
   An open branch/PR for a matching item means someone is building it now.
4. **Verdict** against the best match (item or child):

| Verdict | Condition | Action |
|---------|-----------|--------|
| **ALREADY DONE** | Match is Done and covers the request | No new item. Report key + link. A regression → new **Bug** linked `relates`. |
| **IN FLIGHT** | Match is open with a branch/PR | No new item. Comment the extra context on it, report, stop. |
| **DUPLICATE** | Open match (item or child) with the same scope | No new item. Comment + link `duplicate`; reuse its key. |
| **FOLD-IN** | Same Story scope, new ACs | Append ACs to the existing Story; reuse its key. |
| **RELATED** | Same Epic, a slice no child covers yet | New Story under that Epic. |
| **UNRELATED** | No strong match | New Epic + its first Story. |

**Confidence gate:** act on a high-confidence verdict. In the gray band, STOP and ask the user
with the 1–2 candidates (`key — title — state`, plus the child that nearly matches) and your
recommendation.

---

## Step 4 — BA: write the durable spec to git

**Adopt the BA persona** (`.devpilot/prompts/team/ba-agent.md`); apply
`.devpilot/skills/definition-of-ready.md`.

1. Read the 3–8 scoped source files.
2. Write `docs/requirements/<SLUG>.md` (`.devpilot/templates/team/requirements.md`): user story,
   acceptance criteria, scope, data/API changes, edge cases. Record assumptions; don't ask
   (except the Step 3 gray band). **Bug:** `docs/bugs/<SLUG>.md`
   (`.devpilot/templates/team/bug-report.md`) — reproduction, expected vs actual, blast radius,
   the single bug AC (*fails before the fix, passes after, a regression test guards it*).
3. Features: `docs/domain-models/<SLUG>.md` (`.devpilot/templates/team/domain-model.md`).
4. `AC_COUNT`, layers (frontend / backend / DB).
5. **DoR gate** → `ready`, or `needs grooming` with what's missing (never sprinted unclear).

Then the **self-contained brief** any teammate or Claude session can build from the tracker
alone — `docs/tasks/<SLUG>-brief.md` from `.devpilot/templates/team/item-brief.md`, filled from
the FULL requirements (all ACs, scope, technical notes, repo + branch convention, spec paths, DoD).

---

## Step 5 — Write to the tracker (per the Step 3 verdict)

```bash
BRIEF="docs/tasks/${SLUG}-brief.md"; SUMMARY="<one-line summary>"
```
- **Bug** → `KEY=$(bash scripts/tracker.sh new Bug "$SUMMARY" "$BRIEF" "" "bug,sev-$(echo $SEVERITY | tr P p)")`
- **UNRELATED** →
  ```bash
  EPIC_KEY=$(bash scripts/tracker.sh new Epic "<epic summary>" "<epic goal>")
  KEY=$(bash scripts/tracker.sh new Story "$SUMMARY" "$BRIEF" "$EPIC_KEY")
  ```
- **RELATED** → `KEY=$(bash scripts/tracker.sh new Story "$SUMMARY" "$BRIEF" "<EPIC_KEY>")`
- **FOLD-IN** →
  ```bash
  KEY="<TARGET_KEY>"
  bash scripts/tracker.sh describe "$KEY" "$BRIEF"     # brief now carries the merged ACs
  bash scripts/tracker.sh comment "$KEY" "➕ Folded in: $SUMMARY — ACs appended (docs/requirements/$SLUG.md)"
  [ -n "${SOURCE_KEY:-}" ] && bash scripts/tracker.sh link "$SOURCE_KEY" duplicate "$KEY" && bash scripts/tracker.sh close "$SOURCE_KEY"
  ```
- **DUPLICATE** →
  ```bash
  KEY="<EXISTING_KEY>"
  [ -n "${SOURCE_KEY:-}" ] && bash scripts/tracker.sh link "$SOURCE_KEY" duplicate "$KEY"
  bash scripts/tracker.sh comment "$KEY" "🔁 Duplicate request noted [$START_TIME]: $SUMMARY"
  ```
- **ALREADY DONE / IN FLIGHT** → comment on the existing key, `KEY=<EXISTING_KEY>`, and end the
  plan (report it).

New items: refresh the brief with the real key, set it as the description, and log the plan:
```bash
bash scripts/tracker.sh describe "$KEY" "$BRIEF"
bash scripts/tracker.sh comment "$KEY" "📋 Planned [$START_TIME] · Verdict: <VERDICT> · Intent: $INTENT
ACs: $AC_COUNT · Scope: <layers> · DoR: <ready|needs grooming> · Spec: <docs/requirements|docs/bugs>/$SLUG.md"
```
Items stay in **To Do** — planning does not start work.

**Gate — planning is not done until a key exists:**
```bash
bash scripts/tracker.sh assert-key "$KEY" || exit 1
```

---

## Step 6 — Refresh the backlog index

```bash
bash scripts/generate-backlog-index.sh
```

---

## Final Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋  PLANNED — <tracker: jira | azure | github | local>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧭  Verdict:   <ALREADY DONE | IN FLIGHT | DUPLICATE | FOLD-IN | RELATED | UNRELATED>
    Checked:   <n> candidates · <m> child items (e.g. ADO-40 › ADO-41, ADO-42)
📌  Item:      <KEY>  (Epic: <EPIC_KEY>) → To Do   <url>
📄  Spec:      docs/requirements/<SLUG>.md
✅  ACs:       <AC_COUNT>   ·   Scope: <...>

▶  Next:  /dp-sprint   ·   or everything at once: /dp-deliver <KEY>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
