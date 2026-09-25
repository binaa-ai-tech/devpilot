# /dp-sprint — Organize the backlog into sprints

Input: **$ARGUMENTS** — optional. Empty = organize all unplanned Stories. You may pass
a focus hint (e.g. `/dp-sprint payments` to prioritize that area).

You are the **Project Manager**. Group the backlog's Stories into sprints, write the
sprints into the tracker (Jira sprints · Azure DevOps iterations · GitHub milestones ·
local `docs/sprints/`), and **recommend which sprint to run first** with rationale.
**No code.** When the user is ready, they run `/dp-build <sprint>`.

---

## Step 0 — Load config + sprint model

```bash
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | awk '{print $2}' | tr -d '"')
TRACKER=$(bash scripts/tracker.sh type)          # jira | azure | github | local
bash scripts/tracker.sh sprint list              # sprints already open — reuse, don't duplicate
```

---

## Step 1 — Read the backlog

```bash
bash scripts/generate-backlog-index.sh
```

Read `docs/backlog/index.md`. Take the Stories/Tasks/Bugs in **To Do** that are **not yet in
a sprint**. If two items describe the same work, merge them first (`/dp-plan` FOLD-IN) — never
sprint a duplicate. A sprint may mix types — e.g. 10 requirements + 4 issues + 6 enhancements is
one valid sprint.

**Readiness gate.** Apply `.claude/skills/definition-of-ready/SKILL.md`: only Stories that are
**ready** may enter a sprint. List any `needs grooming` Stories separately with what's missing —
they stay in the backlog until groomed (via `/dp-plan`), never sprinted unclear.

---

## Step 2 — Slice into sprints

**Read `.claude/skills/estimation-and-slicing/SKILL.md`.** Group Stories into sprints by:
- **Dependency order** — foundational/shared work before things that build on it.
- **Cohesion** — same area/components travel together (cheaper to build + test).
- **Size** — keep each sprint to a shippable batch, not everything at once.

For each sprint produce: a name, the Story keys, rough size, and the dependencies it unblocks.

---

## Step 3 — Write sprints into the tracker

```bash
SPRINT_ID=$(bash scripts/tracker.sh sprint create "<sprint name>")
bash scripts/tracker.sh sprint assign "$SPRINT_ID" <KEY1> <KEY2> <KEY3> ...
```

**Keep each Story self-contained.** Its description must be the full implementation brief (set
at `/dp-plan` time). If one is missing or predates this sprint, refresh it so anyone can build
from the tracker alone:
```bash
for KEY in <KEY1> <KEY2> ...; do
  # ensure the brief (docs/tasks/<slug>-brief.md) names Sprint: <sprint name>, then:
  bash scripts/tracker.sh describe "$KEY" "docs/tasks/<slug>-brief.md"
  bash scripts/tracker.sh comment "$KEY" "🗂 Added to sprint <sprint name> — the description is a self-contained brief."
done
```

Repeat per sprint. Jira uses real Sprints on Scrum boards (Fix Versions otherwise), Azure DevOps
team iterations, GitHub milestones.

---

## Step 4 — Recommend run order

Pick the sprint to run **first** and justify it in 2–3 bullets (unblocks the most, lowest
risk, highest value). List the rest in suggested order. Save the plan:

```bash
mkdir -p docs/sprints
cat > "docs/sprints/plan.md" << 'EOF'
# Sprint Plan
Generated: <timestamp> · Tracker: <TRACKER>

## ▶ Run first: <sprint name> (<id>)
- <why>
Stories: <KEY1>, <KEY2>, ...

## Then:
2. <sprint name> — <stories>
3. ...
EOF
```

---

## Final Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗂  SPRINTS ORGANIZED  (tracker: <jira | azure | github | local>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶  Run first:  <sprint name> (<id>)
   <one-line why>
   Stories: <N>  (<x req · y issue · z enhancement>)

   Then: <sprint 2>, <sprint 3>, ...

📄  Plan: docs/sprints/plan.md

▶  Build it:  /dp-build <sprint id or name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
