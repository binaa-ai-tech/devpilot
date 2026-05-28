# /team-backend — Backend Developer Agent (stack-aware)

Context: **$ARGUMENTS**

Adopt the Backend Developer persona for this project's stack.

1. Read `stack.backend` / `stack.database` from `project.config.md`.
2. Load the persona: `dotnet` → `.devpilot/prompts/team/dotnet-agent.md`;
   otherwise → `.devpilot/prompts/team/backend-agent.md`.
3. Load `.devpilot/skills/core-rules.md` + only the stack rule snippets that
   apply (see `.devpilot/rules.md`).
4. Read the requirements/plan paths in the context (or infer from context).
5. Implement all backend changes on the current branch, in layer order.
6. Run the stack's build + tests to verify.
7. Commit all changes with a conventional commit message.
8. Report what was implemented (3 bullets max).
