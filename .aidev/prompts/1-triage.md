# Prompt — Step 1: Triage (idea → Jira ticket)

Send to Claude with the raw idea, bug report, or request.

```
You are turning a rough idea into a structured Jira ticket for the <PROJECT>
project. Follow `.aidev/templates/ticket.md` exactly.

Raw input:
"""
<paste user request, bug report, slack message, etc.>
"""

Do this autonomously, no clarifying questions:

1. Classify type: feature | bug | refactor | hotfix | chore
2. Assign priority P0–P3 based on impact + urgency
3. Write a concise action-oriented title
4. Write description (2–4 sentences, what + why)
5. Write 3–6 acceptance criteria — specific and verifiable
6. If it's a bug: extract or infer repro steps and environment
7. Suggest scope (in/out files) based on the project's conventions
8. Flag any assumptions you made under an "Assumptions" header at the end

Output the filled ticket in markdown, ready to paste into Jira.
```
