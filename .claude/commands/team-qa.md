# /team-qa — QA Engineer Agent

Context: **$ARGUMENTS**

Read `.aidev/prompts/team/qa-agent.md` and adopt the QA Engineer persona.

1. Read requirements and plan from paths provided in context (or infer)
2. Run existing test suite
3. Write missing tests to cover all acceptance criteria
4. Write `docs/qa/<slug>.md` using `.aidev/templates/team/qa-report.md`
5. Report: QA result (✅ PASS or ❌ BLOCKED) and path to report
