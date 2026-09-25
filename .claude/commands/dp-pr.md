# /dp-pr — Tech Lead: take a PR to merged (CI green + review comments + merge)

Input: **$ARGUMENTS** — a PR number/URL, or empty = the most recent open devpilot PR into
`base_branch`.

One command that owns a PR until it reaches its end state, with no human hand-offs in between:
1. **Review comments** — apply every actionable one, reply on each thread.
2. **Red CI** — diagnose, fix, re-run the gates (bounded: max 3 push-fix cycles).
3. **Merge** — squash-merge when every gate is green on the head commit (`merge_policy: auto`),
   or leave it green and ready for a human (`pr-only`).

The contract is `.devpilot/skills/auto-merge.md` — read it first; it governs this command.

> ## 🔌 Transport — `gh` CLI **or** GitHub MCP (pick what's present)
> `gh` is missing in some environments (notably Claude Code on the web), where its commands
> fail silently — the usual reason "auto-merge didn't work". Detect once and use the matching
> transport for **all** steps:
> ```bash
> if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then GH=1; else GH=0; fi
> ```
> - `GH=1` → the `gh` commands as written.
> - `GH=0` → the **GitHub MCP tools** (load schemas via ToolSearch first):
>   `mcp__github__pull_request_read` (details, mergeable, checks, review threads),
>   `mcp__github__get_job_logs`, `mcp__github__add_reply_to_pull_request_comment`,
>   `mcp__github__resolve_review_thread`, `mcp__github__merge_pull_request`.
>   Never report a merge unless the tool returned `merged: true`.

---

## Step 0 — Load policy + the PR

```bash
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | sed 's/base_branch:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
MERGE_POLICY=$(grep '^merge_policy:' project.config.md | head -1 | awk '{print $2}')
```
- `GH=1`: `gh pr view $ARGUMENTS --json number,headRefName,baseRefName,mergeable,statusCheckRollup,reviewThreads` then `gh pr checkout $ARGUMENTS`.
- `GH=0`: `mcp__github__pull_request_read` for the same data; `git fetch origin <headRef> && git checkout <headRef>`.

If any **never-auto-merge** condition in `auto-merge.md` holds (release/`main` target,
unvetted migrations, secrets/auth config in the diff), still fix CI and comments but stop
before the merge and say why.

## Step 1 — Review comments

For each unresolved review thread:
1. **Triage** — actionable change, question, or disagreement.
2. **Fix** actionable ones on the PR branch, one scoped commit per concern
   (`fix(review): <what>`), per `.devpilot/skills/code-review.md`. Answer questions from the
   diff. For a disagreement, reply with the reason instead of changing code.
3. **Reply** on every thread (what changed + commit, or why not) and resolve the ones fixed.
   Re-request review from humans who asked for changes.

## Step 2 — CI fix loop (max 3 cycles)

For each cycle:
1. **Update the branch** if base moved: `git pull --rebase origin $BASE_BRANCH` (on a branch
   devpilot created; merge instead on someone else's).
2. **Fetch the failures** — `GH=1`: `gh pr checks`, then `gh run view <id> --log-failed`.
   `GH=0`: check rollup via `mcp__github__pull_request_read`, logs via `mcp__github__get_job_logs`.
3. **Root-cause and fix** per `.devpilot/skills/self-heal.md` (hard rules: no skipped tests,
   no weakened assertions, no suppressed errors). "Flaky" is not a root cause.
4. **Local ladder before pushing** — `bash scripts/run-tests.sh all`,
   `STRICT=1 bash scripts/test-guard.sh`, `bash scripts/audit.sh`. Push only a locally-green
   commit: `fix(ci): <what>`.
5. Wait for CI on the new head; green → Step 3, red → next cycle.

After 3 cycles still red → stop, post the self-heal escalation (exact failing command, error,
attempts) as a PR comment, and notify:
`bash scripts/notify.sh blocked "PR #<n> still red after 3 fix cycles: <diagnosis>"`.

## Step 3 — Merge per policy

All ladder gates green on the **head commit** (build/tests, audit, no open 🔴 review, QA PASS, CI):
- `MERGE_POLICY = pr-only` → stop: "green and ready for human merge".
- `MERGE_POLICY = auto` → squash-merge: `GH=1` `gh pr merge <n> --squash --delete-branch`;
  `GH=0` `mcp__github__merge_pull_request` with `merge_method: "squash"`, then delete the head
  branch. A "not mergeable" answer is a red gate, not a merge.

On merge: move the PR's Stories to Done, post the single DONE comment (`core-rules.md` #11), and
`bash scripts/notify.sh done "PR #<n> merged into $BASE_BRANCH (<cycles> fix cycles)"`.

## Report

```
🔀 /dp-pr — PR #<n> → <BASE_BRANCH>
Review:       <n> threads — <fixed> fixed · <answered> answered
CI cycles:    <0–3>  ·  Fixes: <commit list or "none needed">
Gate ladder:  build ✅ · tests ✅ · audit ✅ · review ✅ · QA ✅ · CI ✅
Outcome:      MERGED | READY (pr-only) | ESCALATED (<why>)
```
