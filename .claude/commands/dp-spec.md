# /dp-spec — Design and review specs with Elephant-Goldfish (no code)

Input: **$ARGUMENTS** — one of:
- a Story key or slug (`/dp-spec PROJ-12`, `/dp-spec csv-export`) → **Goldfish review** of its
  requirements doc, with remediation, ending in a PASS / BLOCKED verdict.
- an EGM skill + its arguments, run interactively:

| `/dp-spec …` | EGM skill | Use it to |
|--------------|-----------|-----------|
| `brainstorm "<idea>"` | `egm-brainstorm` | explore a fuzzy idea into a design direction (`docs/designs/<name>.md`) |
| `draft [docs/designs/<name>.md]` | `egm-draft` | write the design doc section by section, with approval gates |
| `review <path>` | `egm-review` | Goldfish-review any design doc (you pick the preset) |
| `resolve <path>` | `egm-resolve` | walk a review's findings: FIX or CONTEST each one |
| `bootstrap` | `egm-bootstrap` | create or refresh design docs for an **existing** codebase |
| `drift-report` | `egm-drift-report` | compare checked-in docs with the current source code |

You are the **Elephant**: full context, you write. Reviewers are the **Goldfish**: the `egm-*`
agents, zero context. Read `.devpilot/egm/DEVPILOT.md` once before starting. **No branch. No
production code.** Only `docs/` changes.

---

## Step 0 — Load config + resolve the input

```bash
SPEC_REVIEW=$(grep '^spec_review:' project.config.md | head -1 | awk '{print $2}' | tr -d '"'); SPEC_REVIEW=${SPEC_REVIEW:-auto}
ROUNDS=$(grep '^spec_review_rounds:' project.config.md | head -1 | awk '{print $2}' | tr -d '"'); ROUNDS=${ROUNDS:-2}
EGM_ROOT="$(git rev-parse --show-toplevel)/.devpilot/egm"
cat "$EGM_ROOT/UPSTREAM"
```

- First word is an EGM skill name (`brainstorm`, `draft`, `review`, `resolve`, `bootstrap`,
  `drift-report`) → **Step 2**.
- A key (`^[A-Z][A-Z0-9_]*-[0-9]+$`) → `bash scripts/tracker.sh show <KEY>`; find its slug from
  the `Spec:` line of the planned comment or `docs/tasks/<KEY>.md` → **Step 1**.
- A slug with `docs/requirements/<slug>.md` (or `docs/bugs/<slug>.md`) → **Step 1**.
- Nothing matches → say what was searched and stop. Suggest `/dp-plan "<requirement>"` first.

`SPEC_REVIEW=off` does not block an explicit `/dp-spec` — the user asked for it.

---

## Step 1 — Goldfish review of a Story's spec

**Load `.claude/skills/spec-review/SKILL.md` and follow it.** Target, context and artifact
directory:

```
TargetFile:      docs/requirements/<SLUG>.md
GoldfishContext: docs/domain-models/<SLUG>.md (if present), docs/project-index.md,
                 the source files named in the spec's scope section
EGM artifact directory: docs/specs/<SLUG>
```

- **A human is present** (they typed `/dp-spec`) → read
  `.devpilot/egm/skills/egm-review/SKILL.md` and let them choose the preset; when the review
  ends, read `.devpilot/egm/skills/egm-resolve/SKILL.md` and walk the findings with them.
- **Called from `/dp-plan` or `/dp-deliver`** (autonomous) → `Step: uninterrupted`, stages
  5–8 (9 only with an implementation plan), then the bounded FIX / CONTEST loop — at most
  `$ROUNDS` rounds — exactly as the skill describes.

Write `docs/specs/<SLUG>/review.md` with the verdict, then commit the spec and its review on
the current branch:
```bash
git add docs/requirements/<SLUG>.md docs/specs/<SLUG>/ && git commit -m "docs(spec): goldfish review <SLUG> — <PASS|BLOCKED>"
```
Tracker: **PASS** → no comment (the planned comment already links the spec). **BLOCKED** →
```bash
bash scripts/tracker.sh comment "<KEY>" "🐟 Spec review BLOCKED — <n> open Blocker(s): docs/specs/<SLUG>/review.md"
```

---

## Step 2 — Run an EGM skill interactively

Read `.devpilot/egm/skills/egm-<skill>/SKILL.md` and follow it in this thread (never the
`Skill` tool). Paths in it resolve against `.devpilot/egm`; spawn reviewers as the `egm-*`
project agents. Put artifacts under `docs/specs/` unless the skill names its own home
(`docs/designs/` for brainstorm / draft output).

When a `draft` finishes for a feature that should be built, hand off to planning:
`/dp-plan "<feature> — design: docs/designs/<name>.md"` (the BA links the design as context).

---

## Final Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🐘🐟  SPEC REVIEW — <SLUG>  (EGM <version from UPSTREAM>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧭  Verdict:   <PASS | BLOCKED>   ·   Rounds: <n>/<ROUNDS>
🔴  Blockers:  <fixed> fixed · <contested> contested · <open> open
🟡  Majors:    <fixed> fixed · <contested> contested · <open> open
📄  Report:    docs/specs/<SLUG>/review.md

▶  Next:  /dp-sprint   ·   or /dp-deliver <KEY>      (BLOCKED → fix the spec, /dp-spec <KEY>)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
For Step 2 runs, report the files the skill wrote and the next command instead.
