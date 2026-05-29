# /binaa-rollback — Roll Back a Production Release

Prepare a safe rollback to a previous release tag. Conservative by design: it
shows the plan and only creates the rollback branch when you confirm — it never
force-pushes or rewrites production history.

Version: **$ARGUMENTS** _(optional — defaults to the tag before the latest)_

```bash
# 1. See the plan (dry run)
bash scripts/rollback.sh $ARGUMENTS

# 2. Execute: create + push the rollback branch
CONFIRM=1 bash scripts/rollback.sh $ARGUMENTS
```

Then open a PR from `rollback/<version>` into `main`, get review, and redeploy
that tag via `/binaa-prd <version>`.
