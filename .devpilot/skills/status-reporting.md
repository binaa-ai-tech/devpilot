# Skill: Status Reporting (Team Communication)

A one-person-plus-AI team still communicates like a team: clear, timely, honest
status at every phase boundary, logged where the work lives.

## Cadence — post a short update via `scripts/track.sh` at each boundary
- **Start** — task, branch, engine, who's working.
- **Plan done** — scope (FE/BE/DB), AC count, link to plan.
- **Implementation done** — commits, what each agent built.
- **QA** — PASS or BLOCKED + report link.
- **Merged / DONE** — PR, duration, what shipped, promote command.

(The `/ceo` flow already logs these via `track.sh comment`; keep them crisp.)

## Make updates scannable
- Lead with the outcome (✅ done / 🚫 blocked / ⚙️ in progress), then detail.
- Facts over prose: commit hashes, file counts, AC numbers, links.
- Past tense, what changed — not what you're "going to" do.

## Escalate blockers immediately, in this shape
```
🚫 BLOCKED — <one-line what's blocked>
Why: <root cause / what was tried>
Need: <the specific decision or input required>
Impact: <what's waiting on this>
```
Don't go silent and don't bury a blocker inside a long update.

## Honesty rules
- Report failures plainly with the evidence (paste the failing output).
- If a step was skipped or fell back to another engine, say so.
- Never report "done" for work that was cut short or unverified.
