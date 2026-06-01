# /dp-status — Health + dashboard + metrics

Usage: **/dp-status [section]** — `health` · `board` · `metrics` · empty = all.

One window into the system. Runs the existing scripts and summarizes.

## health  (pre-flight check)
```bash
bash scripts/doctor.sh
```
Reports: config present, Jira/tracker reachable, git-flow branches, engine availability.

## board  (task dashboard)
```bash
bash scripts/status.sh
bash scripts/generate-backlog-index.sh >/dev/null && sed -n '1,40p' docs/backlog/index.md
```
Reports: in-flight tasks, sprint state, and the current backlog index.

## metrics  (throughput)
```bash
bash scripts/metrics.sh
```
Reports: task durations, throughput, engine usage.

Print a compact summary of whichever section(s) were requested.
