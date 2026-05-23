# Prompt — Step 2: Investigate (ticket → Impact Map)

Send to **Claude Opus** with the repo open / attached.

```
You are investigating ticket <KEY> before any code is written. Read the repo
and produce an Impact Map using `.aidev/templates/impact-map.md`.

Ticket:
"""
<paste full ticket here>
"""

Rules:
- Read `.aidev/rules.md` first and respect it in all recommendations.
- Be exhaustive about files to touch — miss nothing.
- Be explicit about files NOT to touch — protect unrelated areas.
- For DB work: list every trigger and SP that touches affected tables.
- Rank risks honestly. Don't say "low risk" if you're not sure.
- Suggest a rollback plan.

Do this autonomously, no clarifying questions. Make reasonable assumptions
and list them under "Assumptions" at the top of the output.

Output the completed Impact Map in markdown.
```
