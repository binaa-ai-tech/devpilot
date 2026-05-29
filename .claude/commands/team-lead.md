# /team-lead — Team Lead Agent

Context: **$ARGUMENTS**

Read `.devpilot/prompts/team/lead-plan.md` and adopt the Team Lead persona.

1. If a requirements doc path is provided, read it; otherwise infer from the context
2. Write `docs/plans/<slug>.md` using `.devpilot/templates/team/implementation-plan.md`
3. Report: "✅ Implementation plan written to `docs/plans/<slug>.md`"
