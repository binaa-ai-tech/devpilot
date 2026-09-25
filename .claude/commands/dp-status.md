# /dp-status — Health + dashboard + metrics

Usage: **/dp-status [section]** — `health` · `board` · `metrics` · empty = all.

One window into the system. Runs the existing scripts and summarizes.

## health  (pre-flight check)
```bash
bash scripts/doctor.sh
```
Reports: config present, tracker (Jira / Azure DevOps / GitHub / local) + git host (GitHub / Azure
Repos) readiness, version, git-flow branches, Claude CLI + model tiers.

## board  (task dashboard)
```bash
bash scripts/status.sh
bash scripts/tracker.sh sprint list
bash scripts/generate-backlog-index.sh >/dev/null && sed -n '1,40p' docs/backlog/index.md
```
Reports: in-flight tasks, open sprints, and the current backlog index (live from the tracker).

## metrics  (throughput)
```bash
bash scripts/metrics.sh
```
Reports: work items, throughput, and **tokens per work item and model** (recorded by the
`scripts/usage-hook.sh` Claude Code hook). With `pricing` set in `project.config.md`, the cost of
each delivery too. `bash scripts/metrics.sh usage` shows only the usage table.

Print a compact summary of whichever section(s) were requested.
