# /dp-sprint — Organize the backlog into sprints

Input: **$ARGUMENTS** — optional. Empty = organize all unplanned Stories. You may pass
a focus hint (e.g. `/dp-sprint payments` to prioritize that area).

You are the **Project Manager**. Group the backlog's Stories into sprints, write the
sprints into Jira, and **recommend which sprint to run first** with rationale.
**No code.** When the user is ready, they run `/dp-build <sprint>`.

---

## Step 0 — Load config + sprint model

```bash
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
SPRINT_MODE=$(bash scripts/jira-sprint.sh mode)   # "scrum" (real Sprints) or "version" (Fix Versions)
echo "Sprint model: $SPRINT_MODE"
```

---

## Step 1 — Read the backlog

```bash
bash scripts/generate-backlog-index.sh
```

Read `docs/backlog/index.md`. Take the Stories/Tasks in **To Do** that are **not yet in
a sprint**. A sprint may mix types — e.g. 10 requirements + 4 issues + 6 enhancements is
one valid sprint.

**Readiness gate.** Apply `.devpilot/skills/definition-of-ready.md`: only Stories that are
**ready** may enter a sprint. List any `needs grooming` Stories separately with what's missing —
they stay in the backlog until groomed (via `/dp-plan`), never sprinted unclear.

---

## Step 2 — Slice into sprints

**Read `.devpilot/skills/estimation-and-slicing.md`.** Group Stories into sprints by:
- **Dependency order** — foundational/shared work before things that build on it.
- **Cohesion** — same area/components travel together (cheaper to build + test).
- **Size** — keep each sprint to a shippable batch, not everything at once.

For each sprint produce: a name, the Story keys, rough size, and the dependencies it unblocks.

---

## Step 3 — Write sprints into Jira

```bash
SPRINT_ID=$(bash scripts/jira-sprint.sh create "<sprint name>")
bash scripts/jira-sprint.sh assign "$SPRINT_ID" <KEY1> <KEY2> <KEY3> ...
```

Repeat per sprint. (`create`/`assign` auto-use real Sprints or Fix Versions per `$SPRINT_MODE`.)

---

## Step 4 — Recommend run order

Pick the sprint to run **first** and justify it in 2–3 bullets (unblocks the most, lowest
risk, highest value). List the rest in suggested order. Save the plan:

```bash
mkdir -p docs/sprints
cat > "docs/sprints/plan.md" << 'EOF'
# Sprint Plan
Generated: <timestamp> · Model: <SPRINT_MODE>

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
🗂  SPRINTS ORGANIZED  (model: <scrum | version>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶  Run first:  <sprint name> (<id>)
   <one-line why>
   Stories: <N>  (<x req · y issue · z enhancement>)

   Then: <sprint 2>, <sprint 3>, ...

📄  Plan: docs/sprints/plan.md

▶  Build it:  /dp-build <sprint id or name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
