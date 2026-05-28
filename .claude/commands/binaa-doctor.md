# /binaa-doctor — Pre-flight Health Check

Verify the project is ready to run a `/ceo` task before starting one.

```bash
bash scripts/doctor.sh
```

Checks: `project.config.md`, git remote, base branch, the configured AI engine,
the issue tracker's credentials, required tooling (`git`/`gh`/`jq`), script
permissions, and the project index. Reports ✅ / ⚠️ / ❌ and exits non-zero on a
hard failure. Run it after install or whenever a task fails for a setup reason.
