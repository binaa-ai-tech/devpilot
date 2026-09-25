# /dp-pr — Tech Lead: take a PR to merged (review comments + CI green + merge + close)

Input: **$ARGUMENTS** — a PR number/URL, or empty = the most recent open DevPilot PR into
`base_branch`.

One command that owns a PR until its end state, with no human hand-offs:
1. **Review comments** — apply every actionable one, reply on each thread.
2. **Red CI** — diagnose, fix, re-run the gates (bounded: max 3 push-fix cycles).
3. **Merge** — squash when every gate is green on the head commit (`merge_policy: auto`), or
   leave it green and ready for a human (`pr-only`).
4. **Close** — items Done, Epic and sprint closed, back on `develop` (`close-delivery.sh`).

The contract is `.devpilot/skills/auto-merge.md` — read it first.

> ## 🔌 Transport — pick once by git host
> ```bash
> HOST=$(bash scripts/git-host.sh)     # github | azure
> if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then GH=1; else GH=0; fi
> ```
> | Need | GitHub + `gh` | GitHub, no `gh` (web) | Azure Repos |
> |------|---------------|-----------------------|-------------|
> | PR details / checks | `gh pr view --json …` | `mcp__github__pull_request_read` | `azdo.sh pr-show <id>` |
> | Review threads | `gh pr view --comments` | `pull_request_read` (review threads) | `azdo.sh pr-threads <id>` |
> | Reply / resolve | `gh api …/comments` | `add_reply_to_pull_request_comment`, `resolve_review_thread` | `azdo.sh pr-reply <id> <thread> "<text>" --resolve` |
> | Failed CI logs | `gh run view <id> --log-failed` | `mcp__github__get_job_logs` | `azdo.sh ci <id> --log` |
> | Merge | `gh pr merge <n> --squash --delete-branch` | `mcp__github__merge_pull_request` (squash) | `azdo.sh pr-complete <id>` |
>
> Load MCP schemas with ToolSearch first. Never report a merge unless the call confirmed it
> (`gh` exit 0, MCP `merged: true`, `azdo.sh pr-complete` → `merged`).

---

## Step 0 — Load policy + the PR

```bash
BASE_BRANCH=$(grep '^base_branch:' project.config.md | head -1 | awk '{print $2}' | tr -d '"')
MERGE_POLICY=$(grep '^merge_policy:' project.config.md | head -1 | awk '{print $2}')
```
Fetch the PR (table above), check out its head branch, and read the machine line in its body:
`<!-- devpilot: keys="…" sprint="…" version="…" -->` → `KEYS`, `SPRINT`, `VERSION` (Step 4).

If any **never-auto-merge** condition in `auto-merge.md` holds (release/`main` target, unvetted
migrations, secrets/auth config in the diff), still fix CI and comments but stop before merging
and say why.

## Step 1 — Review comments

For each unresolved thread:
1. **Triage** — actionable change, question, or disagreement.
2. **Fix** actionable ones on the PR branch, one commit per concern (`fix(review): <what>`), per
   `.devpilot/skills/code-review.md`. Answer questions from the diff. Disagree with a reason,
   not a silent skip.
3. **Reply** on every thread (what changed + commit, or why not); resolve the fixed ones.
   Re-request review from humans who asked for changes.

## Step 2 — CI fix loop (max 3 cycles)

1. **Base moved?** Update the branch: `git pull --rebase origin $BASE_BRANCH` on a branch DevPilot
   created (merge instead on someone else's). **Keep the version exactly one step above base** —
   if develop's version changed since the bump, redo it from the new base:
   ```bash
   LEVEL=<minor|patch from the PR's items>
   WANT=$(bash scripts/version.sh next "$LEVEL" --ref "origin/$BASE_BRANCH")
   [ "$(bash scripts/version.sh current)" != "$WANT" ] && bash scripts/version.sh bump "$WANT" \
     && bash scripts/version.sh files | xargs git add && git commit -m "chore(release): bump version to $WANT"
   ```
   Update the PR title `[vX.Y.Z]` and the body's machine line to match.
2. **Fetch the failures** (transport table).
3. **Root-cause and fix** per `.devpilot/skills/self-heal.md` — no skipped tests, no weakened
   assertions, no suppressed errors. "Flaky" is not a root cause.
4. **Local ladder before pushing** — `bash scripts/run-tests.sh all`,
   `STRICT=1 bash scripts/test-guard.sh`, `bash scripts/audit.sh`. Push only a locally green
   commit: `fix(ci): <what>`.
5. Wait for CI on the new head; green → Step 3, red → next cycle.

After 3 red cycles → stop, post the self-heal escalation (failing command, error, attempts) as a
PR comment, and `bash scripts/notify.sh blocked "PR <n> still red after 3 fix cycles: <diagnosis>"`.

## Step 3 — Merge per policy

All ladder gates green on the **head commit** (build/tests, audit, no open 🔴 review, QA PASS, CI):
- `pr-only` → stop: "green and ready for a human merge".
- `auto` → squash-merge + delete branch (transport table). Azure: auto-complete merges the
  moment branch policies pass — `pr-complete` exit 3 means *armed, waiting on policies*: re-check
  with `azdo.sh pr-show <id>` until `STATUS=completed`. A "not mergeable" / conflicts answer is a
  red gate, not a merge.

## Step 4 — Close (after a confirmed merge)

```bash
bash scripts/close-delivery.sh --pr "<PR_URL>" --version "$VERSION" --sprint "$SPRINT" $KEYS
bash scripts/notify.sh done "PR <n> merged into $BASE_BRANCH as v$VERSION (<cycles> fix cycles)"
```
No machine line (a PR DevPilot didn't open)? Take keys from the title/branch; skip the sprint.

## Report

```
🔀 /dp-pr — PR <n> → <BASE_BRANCH>  (<github | azure>)
Review:       <n> threads — <fixed> fixed · <answered> answered
CI cycles:    <0–3>  ·  Fixes: <commit list or "none needed">
Gate ladder:  build ✅ · tests ✅ · audit ✅ · review ✅ · QA ✅ · CI ✅
Outcome:      MERGED v<VERSION> · items Done · sprint <closed|open> | READY (pr-only) | ESCALATED (<why>)
```
