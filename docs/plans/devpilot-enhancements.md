# devpilot Enhancement Plan — Token-Lean, Tracker-Optional, Any-Project

> Status: **PROPOSAL — awaiting review**. No code changed yet.
> Goal: make devpilot installable into *any* repo and run the full
> `/ceo → BA → dev team → QA → PR → develop` loop fully automatically,
> while reading only the code related to the task (fewer tokens) and
> requiring near-zero external setup for a one-person team.

---

## 0. Guiding principles

1. **Backwards compatible.** Existing `/ceo`, `/ceo-fix`, `/ceo-issue`,
   `/ceo-subdomain` keep working. New behaviour is opt-in via
   `project.config.md`, with sensible defaults.
2. **Retrieve, don't scan.** No agent ever reads the whole tree. It reads an
   index, asks a ranking helper for candidates, and opens only those files.
3. **External services are optional.** Jira, `gh`, opencode — all swappable.
   A fresh clone with only `git` + an AI CLI must complete a task.
4. **One wrapper per concern.** Tracker, PR creation, and scoping each get a
   single script so the command markdown stays identical across backends.

---

## Workstream A — Any-project portability (#1 + #5b)

### Problem
- Backend / DB / integration / security work is all spawned as
  `subagent_type: "team-dotnet"` (`team-task.md:208,214,220`,
  `ceo-fix.md:127,133`, `ceo-issue.md:153,163`, `ceo-subdomain.md:145,155,164`).
  A Python/Node/Go/Java repo gets a ".NET developer".
- `.devpilot/rules.md` only contains **Angular** and **SQL Server** sections.
  Every other detected stack has zero rules.
- PR creation hardcodes `gh pr create` (`team-task.md:341`, `ceo-fix.md:190`,
  `ceo-issue.md:235`, `ceo-subdomain.md:208`) — breaks in CI/web where only
  the GitHub API/MCP is available.

### Changes

**A1 — Generic backend agent.**
- Add `.claude/agents/team-backend.md` and `.claude/commands/team-backend.md`
  that read `stack.backend` from `project.config.md` and adapt
  (build/test commands, conventions) to dotnet | node | python | go | java.
- Keep `team-dotnet.md` as a thin alias that delegates to `team-backend`
  (no breakage for existing installs).
- Update all command markdown to spawn `team-backend` for backend/db/integration.

**A2 — Per-stack rule snippets.**
- Split `.devpilot/rules.md` into:
  - `.devpilot/rules/core.md`        (the universal section — ~15 lines)
  - `.devpilot/rules/angular.md`
  - `.devpilot/rules/dotnet.md`
  - `.devpilot/rules/node.md`        (new)
  - `.devpilot/rules/python.md`      (new)
  - `.devpilot/rules/sqlserver.md`
  - `.devpilot/rules/postgres.md`    (new)
- `install.sh` copies **only** `core.md` + the snippets matching detected
  stack. Agents read `core.md` + their own stack file, never all of them.
- `rules.md` becomes a generated index that `@includes` the active snippets,
  so existing references to `.devpilot/rules.md` still resolve.

**A3 — PR wrapper.**
- Add `scripts/open-pr.sh "<base>" "<title>" "<body-file>"` that:
  - uses `gh pr create` + `gh pr merge` when `gh` is present and authed;
  - otherwise prints the GitHub API/MCP fallback and the manual command.
- Replace the four inline `gh pr create` blocks with one call to this script.

### Acceptance criteria
- [ ] Installing into a Node-only and a Python-only sample repo enables a
      backend agent that builds/tests with the right toolchain.
- [ ] `rules.md` for a React+Postgres project contains no Angular/SQL-Server text.
- [ ] `/ceo` completes a task in a repo with no `gh` installed (prints fallback,
      doesn't crash).

---

## Workstream B — Tracker abstraction (#2)

### Problem
Every phase shells out to `create-jira-ticket.sh / update-jira-status.sh /
add-jira-comment.sh / create-jira-epic.sh`. That's a hard Jira dependency and
dozens of network round-trips per task — friction and tokens for a solo dev.

### Changes

**B1 — `tracker` config key.**
```yaml
# project.config.md → new block
tracker:
  type: local        # local | github | jira
```
- `local`  — write to the existing `docs/tasks/<KEY>.md` log only. KEY is a
  generated local id (e.g. `LOCAL-<yyyymmdd-HHMM>`).
- `github` — open/update a GitHub Issue via MCP (`mcp__github__issue_*`).
- `jira`   — current behaviour (the existing scripts).

**B2 — Single wrapper `scripts/track.sh`.**
Subcommands map 1:1 to today's calls so command markdown barely changes:
```
track.sh new-ticket   "<summary>" "<body>" "<type>"   → echoes KEY
track.sh new-epic     "<name>" "<body>" [parent]       → echoes KEY
track.sh status       "<KEY>" "<status>"
track.sh comment      "<KEY>" "<body>"
track.sh describe     "<KEY>" "<body>"
```
The wrapper reads `tracker.type` and dispatches to Jira scripts, GitHub MCP,
or the local log. Command files call `track.sh` instead of the four
`*-jira-*.sh` scripts.

**B3 — Installer default.**
- Installer asks: "Issue tracker? [local / github / jira]" and defaults to
  `local`. Jira credentials are only requested when `jira` is chosen.

### Acceptance criteria
- [ ] With `tracker.type: local`, a full `/ceo` run completes with no network
      tracker calls; all status lives in `docs/tasks/<KEY>.md`.
- [ ] With `tracker.type: github`, a run opens one Issue and posts phase
      comments to it via MCP.
- [ ] Switching `tracker.type` requires no command-file edits.

---

## Workstream C — Token scoping & size-based routing (#3 + #4)

### Problem
- The project index is shallow: `generate-project-index.sh` emits
  `path — firstClassName` only, so file selection on a large repo is weak and
  the BA over-reads.
- Each spawned agent re-reads 2–4 skill files (`get-shit-done`, `spec-first`,
  `self-heal`, `architecture-guard`) — same tokens paid on every spawn.
- `/ceo` routes by **type** (feature/bug/hotfix) but feature & bug both run the
  full 5-phase + 5-doc flow even for one-line changes.

### Changes

**C1 — Richer, still-cheap index.**
- Group entries by top-level feature/domain folder.
- Per file: exported symbols (classes/functions/components) + a one-line
  purpose inferred from the first doc comment or the symbol name.
- Add a `Route → Controller → Service` map section (frontend routes and API
  endpoints) so the BA can trace a feature without opening files.

**C2 — `scripts/scope.sh "<task description>"`.**
- Tokenises the task, greps the index + filenames + symbol names, and prints a
  **ranked** shortlist (top 8) of candidate files with a relevance reason.
- BA/Lead call this instead of eyeballing the whole index → deterministic,
  minimal reads.

**C3 — Slim the per-agent rule load.**
- Create `.devpilot/skills/core-rules.md` (~15 lines: the non-negotiables —
  no pauses, one concern/commit, tests next to code, end with build+test).
- Agents inline these and reference the long skills only when a situation
  needs them (self-heal on failure, architecture-guard on structural change).
- Net effect: ~3 fewer full-file reads per spawn × every agent × every task.

**C4 — Size-based routing in `/ceo`.**
After type classification, add a size classifier:
| Size | Signal | Route |
|------|--------|-------|
| Trivial | 1 file / copy / config tweak | `ceo-fix` path (no BA, no docs) |
| Single-layer | one of FE/BE/DB | `ceo-subdomain` path (layer-locked) |
| Multi-layer / AC > 5 | spans layers or large | full `team-task` flow |
- Human can still force a track by calling it directly.

**C5 — Enforce compact handoffs.**
- Make `compact-context` mandatory: implementation & QA agents receive the
  compact block + named files only — never raw `docs/requirements` /
  `docs/plans` paths. Encoded directly in the spawn briefs.

**C6 — (stretch) Real scope-lock guard.**
- `scripts/scope-guard.sh <layer>` checks `git diff --name-only` against the
  allowed paths for the layer and fails the agent if it wrote out of scope —
  turning `ceo-subdomain`'s prompt-only lock into an enforced one.

### Acceptance criteria
- [ ] On a medium repo, a typical feature run opens ≤ 8 source files total in
      the BA phase (measured from the index shortlist).
- [ ] `scope.sh "add logout button"` returns the auth/header components ranked
      above unrelated files.
- [ ] A one-line copy change submitted to `/ceo` runs the trivial path (no
      requirements/domain/QA docs generated).
- [ ] Implementation agents no longer receive raw requirement/plan file paths.

---

## Suggested order of implementation

1. **B (tracker)** — unblocks zero-setup solo use immediately; small surface.
2. **A (portability)** — makes "install anywhere" real; medium surface.
3. **C (token scoping + routing)** — biggest token win; touches the most
   command files, so do it once A/B have stabilised the wrappers.

Each workstream is independently shippable and independently testable.

---

## Risks / notes
- Touching every command file (`ceo*.md`, `team-task.md`) for the wrapper
  swaps is mechanical but broad — do it per-workstream, not all at once.
- `team-dotnet` alias must stay until existing installs migrate.
- The richer index must stay fast (pure bash/grep, no network) so the
  120-minute freshness gate still holds.
