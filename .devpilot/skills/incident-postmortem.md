# Incident Postmortem — blameless, after every production incident

Used by `/dp-hotfix` once the fix is verified in production. A professional team treats an
incident as a gift: the system told you where it's weak. Write the postmortem while it's fresh.
**Blameless** — focus on the system and the process, never on a person.

## When to write one
Any P0/P1, any customer-impacting outage, any data issue, any rollback. Skip only for trivial
internal-only blips. Save to `docs/postmortems/<KEY>-<slug>.md`.

## Structure (keep it tight, facts first)
1. **Summary** — what broke, who was impacted, how long, severity.
2. **Timeline** — UTC timestamps: detected → diagnosed → mitigated → resolved. Note the detection
   source (alert vs. customer) — slow detection is itself a finding.
3. **Root cause** — the real cause, found by `debug-method` (reproduce → localize → root cause),
   not the symptom. Use "5 whys" until it stops at something actionable.
4. **Resolution** — what actually fixed it; why it was safe.
5. **What went well / what hurt** — honest, blameless.
6. **Action items** — each has an **owner + a Jira Story** (run them through `/dp-plan`):
   prevention (stop the cause), detection (catch it faster), mitigation (smaller blast radius).

## Rules
- Every action item becomes a backlog Story — a postmortem with no follow-up is theatre.
- Link the postmortem from the hotfix PR and the Jira ticket.
- Recurrence of a known root cause is a process failure, not bad luck.
