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
Reports: task durations, throughput, model usage.

Print a compact summary of whichever section(s) were requested.
