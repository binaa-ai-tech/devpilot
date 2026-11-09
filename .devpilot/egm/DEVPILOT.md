# Elephant-Goldfish Model inside DevPilot

DevPilot ships Google's [Elephant-Goldfish Model](https://github.com/google/elephant-goldfish-model)
(EGM, Apache-2.0, Copyright Google LLC) as a vendored copy, so every DevPilot project gets
spec-driven design review without installing a plugin. `UPSTREAM` records the exact version;
`bash scripts/sync-egm.sh` refreshes it. This file is DevPilot's and is never overwritten by
the sync.

**The idea.** The *Elephant* (the main session, with full project context) drafts the spec. The
*Goldfish* (fresh reviewer subagents with **no** conversation history and no `CLAUDE.md`) must
understand and approve it from the page alone. If a zero-context reader can't, the spec is
not ready — whatever the author "meant" never reaches the implementing agent either.

## Where DevPilot differs from EGM's plugin docs

This overrides `docs/claude.md` (which describes the `claude plugin install egm@egm` route):

| Plugin install (`docs/claude.md`) | DevPilot vendored copy |
|---|---|
| Root is `${CLAUDE_PLUGIN_ROOT}` in the plugin cache | Root is **`.devpilot/egm`** in the project. Resolve `agents/`, `resources/`, `docs/` against it; resolve a skill's `references/` against that skill's folder. Pass reviewers **absolute** paths: `$(git rev-parse --show-toplevel)/.devpilot/egm/...`. |
| Commands `/egm:egm-<skill>` | **`/dp-spec <skill>`** (`brainstorm`, `draft`, `review`, `resolve`, `bootstrap`, `drift-report`). To run a skill from inside another, read `.devpilot/egm/skills/egm-<skill>/SKILL.md` and follow it in the same thread — never the `Skill` tool. |
| Reviewer agents `egm:egm-<name>` | Project agents **`egm-<name>`** in `.claude/agents/` (read-only tools, `omitClaudeMd: true`). |
| Read-permission rules for the plugin cache | Not needed: personas and standards are project files. |
| Artifacts go to the working directory | Artifacts go to **`docs/specs/<SLUG>/`** (the `EGM artifact directory:` line `/dp-spec` passes in its prompt; `CLAUDE.md` sets `docs/specs` as the default). |

Everything else in EGM applies unchanged: sequential review stages 5 → 6 → 7 → 8 → 9, reviewers
parallel only within a stage, 🔴 Blocker / 🟡 Major / 🟢 Nit findings, and a reviewer that cannot
read its persona or standard reports an incomplete review instead of a verdict.

## Requirements

- Claude Code **2.1.271 or later** — older versions ignore `omitClaudeMd`, so reviewers would see
  `CLAUDE.md` and stop being Goldfish. `bash scripts/doctor.sh` checks this.
- A session that can spawn subagents. Without one, EGM stops: a review in the same context is
  not a Goldfish review.

## How DevPilot uses it

- **`/dp-plan`** writes `docs/requirements/<SLUG>.md`, then (per `spec_review` in
  `project.config.md`) runs the Goldfish review on it before the Story can be **ready**.
- **`/dp-spec <KEY|SLUG>`** runs that review on demand; **`/dp-spec <skill>`** runs any EGM skill
  interactively (design a new feature, bootstrap docs for an existing codebase, report drift
  between docs and code).
- The autonomous rules (presets, remediation rounds, the readiness gate) live in
  `.claude/skills/spec-review/SKILL.md`.
