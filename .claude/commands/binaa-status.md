# /binaa-status — Task Dashboard

Show devpilot tasks (from `docs/tasks/`) with status, command, and branch.

```bash
bash scripts/status.sh          # all tasks, newest first
bash scripts/status.sh open     # only in-progress tasks
```

Use it to see what's in flight and find an interrupted task to `/ceo resume`.
For aggregate counts and throughput, use `/binaa-metrics`.
