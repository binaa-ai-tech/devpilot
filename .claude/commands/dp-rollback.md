# /dp-rollback — Roll back a production release

Version: **$ARGUMENTS** _(optional — defaults to the tag before the latest)_

Conservative by design: shows the plan first, creates the rollback branch only on confirm.
Never force-pushes or rewrites production history.

```bash
# 1. Dry run — see the plan
bash scripts/rollback.sh $ARGUMENTS

# 2. Execute — create + push rollback/<version>
CONFIRM=1 bash scripts/rollback.sh $ARGUMENTS
```

Then open a PR from `rollback/<version>` → `main`, get review, and redeploy that tag via
`/dp-release prd <version>`.
