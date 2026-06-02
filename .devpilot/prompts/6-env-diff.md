# Prompt — Step 6: Cross-Environment Failure Diagnosis

> Use when something works in dev but fails in UAT/prod. Based on real
> incidents (e.g. `asp_migration_participants_anto` failing in UAT due to a
> faulty trigger).

Send to Claude:

```
A SQL Server stored procedure or feature works in environment A but fails in
environment B. Help isolate the cause. Do NOT propose SP code changes until
the root cause is confirmed at a layer below (schema, trigger, config).

Provide these inputs (I will paste them next):

1. SP or feature name
2. Exact error message in B (full text, line number if available)
3. `SELECT @@VERSION` from A and B
4. Server config diff:
   - SET XACT_ABORT default
   - SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL,
     QUOTED_IDENTIFIER, NUMERIC_ROUNDABORT, ARITHABORT
   - Default schema for the executing principal
   - Database compatibility level
5. Trigger list on every table the SP touches in B
   (`SELECT name, is_disabled FROM sys.triggers WHERE parent_id IN (...)`)
6. Permission diff for the executing principal in A vs B
   (roles, explicit grants, schema ownership)
7. Any recent changes in B (deployments, restored DB, rotated logins)

Once provided, output:

A. Most likely root cause (one paragraph)
B. Ranked alternatives (top 3)
C. The minimal fix at the lowest possible layer:
   - Schema-level fix preferred
   - Trigger fix if a trigger is at fault
   - Config / permission fix if that's the cause
   - SP code change only as last resort, with justification
D. How to validate the fix in B without redeploying the SP
E. How to prevent this class of bug across environments going forward

No clarifying questions beyond the inputs above. Make assumptions where data
is missing and state them.
```
