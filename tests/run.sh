#!/usr/bin/env bash
# =============================================================================
# tests/run.sh — devpilot script test suite (no external deps, plain bash).
#   bash tests/run.sh
# Exit non-zero if any assertion fails.
# =============================================================================
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

ok() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
no() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
assert_eq()       { if [ "$1" = "$2" ]; then ok "$3"; else no "$3 (got '$1', want '$2')"; fi; }
# Pure-bash substring test: `printf big | grep -q` dies of SIGPIPE under pipefail
# when the match is early in a large haystack (grep exits first → printf killed → 141).
assert_contains() { if [[ "$1" == *"$2"* ]]; then ok "$3"; else no "$3 (missing '$2')"; fi; }
assert_code()     { if [ "$1" = "$2" ]; then ok "$3"; else no "$3 (exit $1, want $2)"; fi; }

# A throwaway git repo with the scripts + a minimal config.
sandbox() {
  local d; d=$(mktemp -d)
  git -C "$d" init -q
  git -C "$d" config user.email t@t.t; git -C "$d" config user.name t
  mkdir -p "$d/scripts" "$d/docs/tasks"
  cp "$REPO"/scripts/*.sh "$d/scripts/"
  cat > "$d/project.config.md" <<'EOF'
base_branch: develop
tracker:
  type: local
merge_policy: auto
stack:
  frontend: angular
  backend: dotnet
EOF
  echo "$d"
}

echo "== tracker.sh — local backend + not-configured flow =="
D=$(sandbox)
OUT=$(cd "$D" && bash scripts/tracker.sh check); RC=$?
assert_code "$RC" "3" "local tracker, never chosen → check asks (rc 3)"
assert_contains "$OUT" "tracker.sh setup azure" "check explains how to connect Azure DevOps"
( cd "$D" && bash scripts/tracker.sh skip 2>/dev/null )
assert_code "$(cd "$D" && bash scripts/tracker.sh check >/dev/null; echo $?)" "0" "after skip → check passes (no more asking)"
( cd "$D" && bash scripts/tracker.sh use jira 2>/dev/null; rm -f .devpilot/.tracker-skip )
OUT=$(cd "$D" && bash scripts/tracker.sh check); RC=$?
assert_code "$RC" "2" "jira selected without credentials → rc 2"
assert_contains "$OUT" "jira_api_token" "rc 2 names the missing Jira values"
assert_eq "$(cd "$D" && bash scripts/tracker.sh type)" "local" "unconfigured jira degrades to local, never crashes"
( cd "$D" && bash scripts/tracker.sh skip 2>/dev/null )
OUT=$(cd "$D" && bash scripts/tracker.sh check); RC=$?
assert_code "$RC" "0" "skip on an unconfigured jira → continue locally"
assert_contains "$OUT" "STATE=skipped" "check reports the skipped state"
( cd "$D" && printf 'base_branch: develop\ntracker:\n  type: azure\n  when_unconfigured: skip\n' > project.config.md; rm -f .devpilot/.tracker-skip )
assert_code "$(cd "$D" && bash scripts/tracker.sh check >/dev/null; echo $?)" "0" "when_unconfigured: skip never asks"
( cd "$D" && bash scripts/tracker.sh use local 2>/dev/null )
E=$(cd "$D" && bash scripts/tracker.sh new Epic "CSV export for reports" "goal" 2>/dev/null)
K1=$(cd "$D" && bash scripts/tracker.sh new Story "Export orders report as CSV" "AC1" "$E" 2>/dev/null)
K2=$(cd "$D" && bash scripts/tracker.sh new Story "Download invoice as PDF" "AC" "$E" 2>/dev/null)
assert_eq "$E $K1 $K2" "LOCAL-1 LOCAL-2 LOCAL-3" "local keys are sequential and branch-friendly"
OUT=$(cd "$D" && bash scripts/tracker.sh search "export the orders report to a csv file")
assert_eq "$(printf '%s\n' "$OUT" | head -1 | cut -f2)" "$K1" "search ranks the closest existing item first"
assert_eq "$(printf '%s\n' "$OUT" | grep -c "$K2")" "0" "search leaves unrelated items out"
OUT=$(cd "$D" && bash scripts/tracker.sh show "$E")
assert_contains "$OUT" "Children:" "show lists child items"
assert_contains "$OUT" "$K2" "show includes every existing child task"
SP=$(cd "$D" && bash scripts/tracker.sh sprint create "Deliver CSV" 2>/dev/null)
( cd "$D" && bash scripts/tracker.sh sprint assign "$SP" "$K1" "$K2" 2>/dev/null )
assert_eq "$(cd "$D" && bash scripts/tracker.sh sprint active)" "$SP" "the new sprint is active"
OUT=$(cd "$D" && bash scripts/tracker.sh sprint close "$SP"); RC=$?
assert_code "$RC" "4" "sprint with open items stays open (rc 4)"
( cd "$D" && bash scripts/tracker.sh close "$K1" "$K2" 2>/dev/null && bash scripts/tracker.sh close-parent "$E" 2>/dev/null )
assert_contains "$(cat "$D/docs/tasks/$E.md")" "Status: Done" "Epic closes once all its children are Done"
assert_eq "$(cd "$D" && bash scripts/tracker.sh sprint close "$SP")" "closed" "empty sprint closes"
( cd "$D" && bash scripts/tracker.sh comment "$K1" "started" 2>/dev/null )
assert_contains "$(cat "$D/docs/tasks/$K1.md")" "started" "comment logged to the item file"
( cd "$D" && bash scripts/generate-backlog-index.sh >/dev/null )
assert_contains "$(cat "$D/docs/backlog/index.md")" "| $K1 | Story | Done | $E |" "backlog index built from any tracker"
assert_code "$(cd "$D" && bash scripts/tracker.sh assert-key "" 2>/dev/null; echo $?)" "1" "assert-key fails with no key"
for K in MSK-12 ADO-345 GH-7 LOCAL-3; do
  assert_code "$(cd "$D" && bash scripts/tracker.sh assert-key "$K" 2>/dev/null; echo $?)" "0" "assert-key accepts $K"
done
assert_code "$(cd "$D" && bash scripts/tracker.sh hotfix-gate bug P1 2>/dev/null; echo $?)" "1" "hotfix-gate blocks a P1 bug"
assert_code "$(cd "$D" && bash scripts/tracker.sh hotfix-gate bug P3 2>/dev/null; echo $?)" "0" "hotfix-gate lets a P3 bug through"
rm -rf "$D"

echo "== version.sh =="
D=$(sandbox)
( cd "$D" && printf '{\n  "name": "web",\n  "version": "1.2.3",\n  "dependencies": { "x": "1.0.0" }\n}\n' > package.json \
  && mkdir -p api && printf '<Project><PropertyGroup>\n    <Version>1.2.3</Version>\n</PropertyGroup></Project>\n' > api/Api.csproj \
  && git add -A && git commit -qm base && git branch -M develop )
assert_eq "$(cd "$D" && bash scripts/version.sh current)" "1.2.3" "reads the current version"
assert_eq "$(cd "$D" && bash scripts/version.sh level bug)" "patch" "bug → patch"
assert_eq "$(cd "$D" && bash scripts/version.sh level bug feature)" "minor" "any feature → minor"
assert_eq "$(cd "$D" && bash scripts/version.sh bump minor --ref develop 2>/dev/null)" "1.3.0" "bump computes from the base ref"
assert_eq "$(cd "$D" && bash scripts/version.sh bump minor --ref develop 2>/dev/null)" "1.3.0" "re-bumping against the same base is idempotent"
assert_contains "$(cat "$D/api/Api.csproj")" "<Version>1.3.0</Version>" ".NET project version updated"
assert_contains "$(cat "$D/package.json")" '"version": "1.3.0"' "Angular package.json version updated"
assert_contains "$(cat "$D/package.json")" '"x": "1.0.0"' "dependency versions untouched"
E2=$(mktemp -d); git -C "$E2" init -q
assert_eq "$(cd "$E2" && bash "$REPO/scripts/version.sh" bump patch 2>/dev/null)" "0.0.1" "no version anywhere → 0.0.1 in a new VERSION file"
rm -rf "$D" "$E2"

echo "== backends over REST (mocked curl) =="
MOCKBIN=$(mktemp -d); cp "$REPO/tests/mock-curl.sh" "$MOCKBIN/curl"; chmod +x "$MOCKBIN/curl"
D=$(sandbox); export MOCK_LOG="$D/mock.log"
mkdir -p "$D/.devpilot"
cat > "$D/.devpilot/config.sh" <<'EOF'
JIRA_BASE_URL="https://acme.atlassian.net"
JIRA_EMAIL="dev@acme.io"
JIRA_API_TOKEN='tok'
JIRA_PROJECT_KEY="MSK"
AZDO_ORG_URL="https://dev.azure.com/acme"
AZDO_PROJECT="Shop"
AZDO_PAT='pat'
GITHUB_TOKEN="ghtok"
GITHUB_ORG="acme"
GITHUB_REPO="shop"
EOF
T() { ( cd "$D" && PATH="$MOCKBIN:$PATH" bash scripts/tracker.sh "$@" ); }
# Jira
( cd "$D" && bash scripts/tracker.sh use jira 2>/dev/null )
assert_code "$(T check >/dev/null; echo $?)" "0" "jira with credentials → ready"
assert_eq "$(T new Story "Export CSV" "AC" MSK-1 2>/dev/null)" "MSK-101" "jira: new Story returns its key"
assert_contains "$(grep 'rest/api/3/issue' "$MOCK_LOG" | head -1)" '"parent":{"key":"MSK-1"}' "jira: Story created under its Epic"
assert_contains "$(T search "export orders csv")" "MSK-7" "jira: search goes through /search/jql"
: > "$MOCK_LOG"; T status MSK-7 "Done" 2>/dev/null
assert_contains "$(cat "$MOCK_LOG")" '"id":"31"' "jira: Done picks the transition into the done category"
assert_code "$(T sprint close 42 >/dev/null 2>&1; echo $?)" "4" "jira: sprint with open issues is not closed"
# Azure DevOps
( cd "$D" && bash scripts/tracker.sh use azure 2>/dev/null ); : > "$MOCK_LOG"
assert_eq "$(T new Story "Export CSV" "## AC\n- one" ADO-9 2>/dev/null)" "ADO-345" "azure: new Story returns ADO-<id>"
L=$(cat "$MOCK_LOG")
assert_contains "$L" 'workitems/$User%20Story' "azure: story type auto-detected (User Story)"
assert_contains "$L" 'System.LinkTypes.Hierarchy-Reverse' "azure: Story linked to its parent Epic"
: > "$MOCK_LOG"; T status ADO-345 "Done" 2>/dev/null
assert_contains "$(cat "$MOCK_LOG")" '"value":"Closed"' "azure: Done maps to the process's Completed state"
: > "$MOCK_LOG"; SP=$(T sprint create "S1" 2>/dev/null)
assert_eq "$SP" "S1" "azure: sprint = iteration"
assert_contains "$(cat "$MOCK_LOG")" "teamsettings/iterations" "azure: iteration added to the team"
assert_eq "$(T sprint close S1 2>/dev/null)" "closed" "azure: empty iteration closes"
assert_eq "$(MOCK_WIQL='{"workItems":[{"id":1}]}' T sprint close S1 2>/dev/null)" "open:1" "azure: iteration with open items stays open"
assert_eq "$(T ref ADO-345)" "AB#345" "azure: commit ref links Boards (AB#)"
# GitHub via token (no gh)
( cd "$D" && bash scripts/tracker.sh use github 2>/dev/null ); : > "$MOCK_LOG"
GHK=$( cd "$D" && PATH="$MOCKBIN:/usr/bin:/bin" bash scripts/tracker.sh new Story "Export CSV" "AC" GH-3 2>/dev/null )
assert_eq "$GHK" "GH-12" "github: new issue via REST token when gh is absent"
assert_contains "$(cat "$MOCK_LOG")" "sub_issues" "github: Story attached to its parent as a sub-issue"
assert_eq "$( cd "$D" && PATH="$MOCKBIN:/usr/bin:/bin" bash scripts/tracker.sh sprint create "S1" 2>/dev/null )" "3" "github: sprint = milestone"
# Setup writes secrets + switches tracker + tests live
( cd "$D" && PATH="$MOCKBIN:$PATH" bash scripts/tracker.sh setup azure azdo_pat=newpat >/dev/null 2>&1 ); RC=$?
assert_code "$RC" "0" "setup stores credentials and pings"
assert_contains "$(cat "$D/.devpilot/config.sh")" "AZDO_PAT='newpat'" "setup writes the PAT to the gitignored config"
assert_eq "$(cd "$D" && bash scripts/tracker.sh configured)" "azure" "setup switches tracker.type"
# Env vars win over the file (CI)
: > "$MOCK_LOG"; ( cd "$D" && AZDO_PAT=envpat PATH="$MOCKBIN:$PATH" bash scripts/tracker.sh ping >/dev/null 2>&1 )
assert_contains "$(cat "$MOCK_LOG")" "_apis/projects/Shop" "azure ping hits the project"
rm -rf "$D"

INSTALL=$(cat "$REPO/install.sh")
echo "== secrets: env overrides file, never committed =="
D=$(sandbox); mkdir -p "$D/.devpilot"; printf "AZDO_PAT='filepat'\nJIRA_API_TOKEN='YOUR_JIRA_API_TOKEN'\n" > "$D/.devpilot/config.sh"
assert_eq "$(cd "$D" && bash -c '. scripts/devpilot-lib.sh; dp_load_secrets; echo "$AZDO_PAT"')" "filepat" "secret read from .devpilot/config.sh"
assert_eq "$(cd "$D" && AZDO_PAT=envpat bash -c '. scripts/devpilot-lib.sh; dp_load_secrets; echo "$AZDO_PAT"')" "envpat" "environment variable wins over the file (CI)"
assert_eq "$(cd "$D" && bash -c '. scripts/devpilot-lib.sh; dp_load_secrets; echo "[$JIRA_API_TOKEN]"')" "[]" "installer placeholders count as not configured"
assert_contains "$INSTALL" '# .devpilot/config.sh holds tracker API keys and must never be committed.
touch .gitignore' "installer creates .gitignore so config.sh is never committed"
assert_contains "$(sed -n '/^run_update() {/,/^}/p' "$REPO/install.sh")" '".devpilot/.tracker-skip"' "--update keeps secrets + skip marker ignored"
rm -rf "$D"

echo "== git host + PRs =="
D=$(sandbox); export MOCK_LOG="$D/mock.log"; mkdir -p "$D/.devpilot"
printf 'AZDO_PAT=%s\n' "'pat'" > "$D/.devpilot/config.sh"
for R in "https://dev.azure.com/acme/Shop/_git/web:azure" "git@ssh.dev.azure.com:v3/acme/Shop/web:azure" \
         "https://acme.visualstudio.com/Shop/_git/web:azure" "git@github.com:acme/shop.git:github"; do
  ( cd "$D" && git remote remove origin 2>/dev/null; git remote add origin "${R%:*}" )
  assert_eq "$(cd "$D" && bash scripts/git-host.sh)" "${R##*:}" "git host from ${R%:*}"
done
( cd "$D" && git remote set-url origin "https://dev.azure.com/acme/My%20Shop/_git/web" && git checkout -q -b feature/ado-345-csv )
: > "$MOCK_LOG"
OUT=$( cd "$D" && PATH="$MOCKBIN:$PATH" bash scripts/open-pr.sh develop "[v1.3.0] CSV export (AB#345)" "body" --items "ADO-345" 2>/dev/null ); RC=$?
assert_code "$RC" "0" "azure: PR created and auto-completed → rc 0"
assert_contains "$OUT" "/My%20Shop/_git/web/pullrequest/77" "azure: prints the PR URL"
L=$(cat "$MOCK_LOG")
assert_contains "$L" '"workItemRefs":[{"id":"345"}]' "azure: PR links the work items"
assert_contains "$L" '"mergeStrategy":"squash"' "azure: auto-complete squashes"
assert_contains "$L" '"deleteSourceBranch":true' "azure: source branch deleted on merge"
( cd "$D" && sed -i.bak 's/^merge_policy:.*/merge_policy: pr-only/' project.config.md; rm -f "$MOCK_LOG.merged" )
( cd "$D" && PATH="$MOCKBIN:$PATH" bash scripts/open-pr.sh develop "t" "b" >/dev/null 2>&1 ); RC=$?
assert_code "$RC" "3" "pr-only: PR opened, never merged"
# Safety: no build-validation policy → never auto-complete (CI would be skipped)
( cd "$D" && sed -i.bak 's/^merge_policy:.*/merge_policy: auto/' project.config.md; rm -f "$MOCK_LOG.merged" )
OUT=$( cd "$D" && MOCK_NO_POLICY=1 PATH="$MOCKBIN:$PATH" bash scripts/azdo.sh pr-complete 77 2>/dev/null ); RC=$?
assert_code "$RC" "3" "azure: unprotected target branch → PR not auto-completed"
assert_eq "$OUT" "unprotected" "azure: reports the missing build policy"
OUT=$( cd "$D" && MOCK_NO_POLICY=1 AZDO_ALLOW_UNPROTECTED=1 PATH="$MOCKBIN:$PATH" bash scripts/azdo.sh pr-complete 77 2>/dev/null ); RC=$?
assert_code "$RC" "0" "azure: AZDO_ALLOW_UNPROTECTED=1 is the explicit opt-out"
# Branch policies + environments
: > "$MOCK_LOG"
( cd "$D" && PATH="$MOCKBIN:$PATH" bash scripts/azdo.sh protect develop --reviewers 1 --build 55 >/dev/null 2>&1 ); RC=$?
assert_code "$RC" "0" "azure: branch policies applied"
L=$(cat "$MOCK_LOG")
assert_contains "$L" '"buildDefinitionId":55' "azure policy: devpilot-ci build validation required"
assert_contains "$L" '"allowSquash":true,"allowNoFastForward":true' "azure policy: develop takes squash (features) + merge commits (back-merges)"
assert_contains "$L" 'c6a1889d-b943-4856-b76f-9e46bb6b0df2' "azure policy: review comments must be resolved"
assert_contains "$L" '"minimumApproverCount":1' "azure policy: 1 reviewer under pr-only"
: > "$MOCK_LOG"; ( cd "$D" && PATH="$MOCKBIN:$PATH" bash scripts/azdo.sh protect main >/dev/null 2>&1 )
assert_contains "$(cat "$MOCK_LOG")" '"allowSquash":false,"allowNoFastForward":true' "azure policy: main takes merge commits only (release/hotfix PRs)"
: > "$MOCK_LOG"
OUT=$( cd "$D" && PATH="$MOCKBIN:$PATH" bash scripts/azdo.sh env-setup prd --approval 2>/dev/null )
assert_contains "$OUT" "approval by you (the PAT owner)" "azure: prd environment gets an approval check (default approver: PAT owner)"
assert_contains "$(cat "$MOCK_LOG")" '"approvers":[{"id":"me-1"}]' "azure: approver is the PAT owner"
assert_eq "$( cd "$D" && PATH="$MOCKBIN:$PATH" bash scripts/azdo.sh pipeline-ensure devpilot-cd azure-pipelines-cd.yml 2>/dev/null )" "55" "azure: CD pipeline created once"
: > "$MOCK_LOG"
OUT=$( cd "$D" && DEVPILOT_APPROVERS="ana@corp.com, [Shop]\Release Managers, nobody@x" PATH="$MOCKBIN:$PATH" bash scripts/azdo.sh env-setup uat --approval 2>&1 )
assert_contains "$(cat "$MOCK_LOG")" '"approvers":[{"id":"id-ana40corpcom"},{"id":"id-5hop55elease20anagers"}]' "azure: several approvers (people + a group) on the approval check"
assert_contains "$OUT" "approver 'nobody@x' not found" "azure: unknown approver is reported, not silently dropped"
rm -rf "$D" "$MOCKBIN"; unset MOCK_LOG

echo "== tracker selftest (live check, local backend) =="
D=$(sandbox)
OUT=$(cd "$D" && bash scripts/tracker.sh selftest 2>&1); RC=$?
assert_code "$RC" "0" "selftest passes end to end on a working tracker"
assert_contains "$OUT" "Epic closes with its last Story" "selftest checks Epic auto-close"
assert_contains "$OUT" "close the sprint" "selftest checks sprint close"
assert_eq "$(ls "$D/docs/tasks" 2>/dev/null | wc -l | tr -d ' ')" "0" "selftest cleans up after itself"
rm -rf "$D"

echo "== CD: deploy.sh / smoke.sh / pipelines =="
MOCKBIN=$(mktemp -d); cp "$REPO/tests/mock-curl.sh" "$MOCKBIN/curl"; chmod +x "$MOCKBIN/curl"
D=$(sandbox); mkdir -p "$D/out"; echo 3.1.0 > "$D/out/VERSION"
OUT=$(cd "$D" && bash scripts/deploy.sh sit out 2>&1); RC=$?
assert_code "$RC" "1" "deploy with no target fails loudly (never a fake success)"
assert_contains "$OUT" "DEPLOY_HOOK" "deploy explains how to add a target"
assert_code "$(cd "$D" && CI='' TF_BUILD='' bash scripts/deploy.sh prd out >/dev/null 2>&1; echo $?)" "1" "production from a terminal needs CONFIRM=1"
OUT=$(cd "$D" && DEPLOY_HOOK_SIT=https://hooks.example/sit PATH="$MOCKBIN:$PATH" bash scripts/deploy.sh sit out 2>&1); RC=$?
assert_code "$RC" "0" "deploy via webhook"
assert_contains "$OUT" "v3.1.0 live on SIT" "deploys the version stamped in the artifact"
OUT=$(cd "$D" && DEPLOY_HOOK='$(DEPLOY_HOOK_UAT)' bash scripts/deploy.sh uat out 2>&1); RC=$?
assert_code "$RC" "1" "an undefined Azure \$(VAR) is treated as no hook"
mkdir -p "$D/deploy"; printf 'echo "custom $1 $2 $3"\n' > "$D/deploy/deploy.sh"
OUT=$(cd "$D" && bash scripts/deploy.sh uat out 2>&1)
assert_contains "$OUT" "custom uat out 3.1.0" "project deploy/deploy.sh receives env, artifact, version"
OUT=$(cd "$D" && SIT_API_URL=https://health.example PATH="$MOCKBIN:$PATH" bash scripts/smoke.sh sit); RC=$?
assert_code "$RC" "0" "smoke passes on a healthy API"
OUT=$(cd "$D" && MOCK_CODE=503 SMOKE_RETRIES=1 SIT_API_URL=https://health.example PATH="$MOCKBIN:$PATH" bash scripts/smoke.sh sit); RC=$?
assert_code "$RC" "1" "smoke fails on an unhealthy API"
( cd "$D" && mkdir -p web api/Migrations && printf '{}' > web/angular.json && touch web/package.json \
  && printf '<Project Sdk="Microsoft.NET.Sdk.Web"/>' > api/Api.csproj && bash scripts/generate-ci.sh >/dev/null 2>&1 )
CD="$(cat "$D/.github/workflows/devpilot-cd.yml" 2>/dev/null)"
assert_contains "$CD" "upload-artifact" "GitHub CD builds once and uploads the artifact"
assert_contains "$CD" "bash scripts/deploy.sh prd out" "GitHub CD promotes the same artifact to prd"
assert_contains "$CD" "name: prd" "prd runs in the approval-gated environment"
assert_contains "$CD" "needs.uat.result == 'success'" "prd only after UAT on release branches"
assert_contains "$CD" "bash scripts/db-package.sh out/db" "CD ships the database package (migrations + rollback)"
assert_contains "$CD" "workflow_dispatch" "manual run on a tag = redeploy / rollback"
( cd "$D" && git remote add origin https://dev.azure.com/a/P/_git/r && bash scripts/generate-ci.sh >/dev/null 2>&1 )
AZCD="$(cat "$D/azure-pipelines-cd.yml" 2>/dev/null)"
assert_contains "$AZCD" "stage: PRD" "Azure CD has a PRD stage"
assert_contains "$AZCD" "environment: prd" "Azure PRD uses the approval-gated environment"
assert_contains "$AZCD" "download: current" "Azure stages deploy the one published artifact"
if python3 -c "import yaml" 2>/dev/null; then
  for F in .github/workflows/devpilot-ci.yml .github/workflows/devpilot-cd.yml azure-pipelines.yml azure-pipelines-cd.yml; do
    assert_code "$(python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$D/$F" 2>/dev/null; echo $?)" "0" "$F is valid YAML"
  done
fi
assert_contains "$(cat "$REPO/.claude/commands/dp-release.md")" "devpilot-cd" "dp-release drives the CD pipeline"
assert_contains "$(cat "$REPO/.claude/commands/dp-setup.md")" "## pipelines" "dp-setup sets up pipelines"
for F in deploy-dev deploy-sit deploy-uat deploy-prd; do
  assert_eq "$([ -e "$REPO/scripts/$F.sh" ] && echo present || echo gone)" "gone" "$F.sh placeholder retired"
done
rm -rf "$D" "$MOCKBIN"

echo "== db-package.sh (fake dotnet) =="
D=$(sandbox); FK=$(mktemp -d)
cat > "$FK/dotnet" <<'EOF'
#!/usr/bin/env bash
echo "dotnet $*" >> "$FAKE_LOG"; o=""; while [ $# -gt 0 ]; do [ "$1" = "--output" ] && o="$2"; shift; done
[ -n "$o" ] && echo "-- sql" > "$o"; exit 0
EOF
chmod +x "$FK/dotnet"; export FAKE_LOG="$D/dotnet.log"
( cd "$D" && mkdir -p src/Infra/Migrations && touch src/Infra/Infra.csproj src/Infra/Migrations/20260101000000_Init.cs \
    src/Infra/Migrations/20260101000000_Init.Designer.cs src/Infra/Migrations/AppDbContextModelSnapshot.cs \
  && echo 1.0.0 > VERSION && git add -A && git commit -qm "feat: init" && git tag v1.0.0 \
  && touch src/Infra/Migrations/20260301000000_AddCsv.cs && echo 1.1.0 > VERSION && git add -A && git commit -qm "feat: csv" )
OUT=$(cd "$D" && PATH="$FK:$PATH" bash scripts/db-package.sh out/db --project src/Infra/Infra.csproj 2>&1)
assert_contains "$OUT" "1 new migration(s) since v1.0.0" "db package diffs migrations against the previous release"
assert_contains "$(cat "$D/out/db/migrations.txt")" "20260301000000_AddCsv" "migrations.txt lists this release's migrations"
assert_contains "$(cat "$FAKE_LOG")" "migrations script --idempotent" "idempotent migrations.sql"
assert_contains "$(cat "$FAKE_LOG")" "migrations script 20260301000000_AddCsv 20260101000000_Init" "rollback.sql goes back to the previous release (Designer/snapshot ignored)"
( cd "$D" && git tag v1.1.0 && rm -rf out ); OUT=$(cd "$D" && echo 1.2.0 > VERSION && git commit -qam "fix: x" && PATH="$FK:$PATH" bash scripts/db-package.sh out/db 2>&1)
assert_contains "$OUT" "rollback: none" "no schema change → no rollback script"
unset FAKE_LOG; rm -rf "$D" "$FK"

echo "== usage-hook.sh + metrics (cost per delivery) =="
D=$(sandbox); TR="$D/t.jsonl"; mkdir -p "$D/t/subagents"
for _ in 1 2 3; do echo '{"type":"assistant","message":{"id":"m1","model":"claude-sonnet-5","usage":{"input_tokens":100,"output_tokens":1000000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' >> "$TR"; done
echo '{"type":"user","message":{"content":"hi"}}' >> "$TR"
echo '{"type":"assistant","message":{"id":"s1","model":"claude-haiku-4-5-20251001","usage":{"input_tokens":5,"output_tokens":7}}}' > "$D/t/subagents/agent-1.jsonl"
( cd "$D" && git commit -q --allow-empty -m base && git checkout -q -b feature/ado-345-csv \
  && printf '{"session_id":"s-1","transcript_path":"%s","hook_event_name":"SessionEnd","cwd":"%s"}' "$TR" "$D" | bash scripts/usage-hook.sh )
U="$D/.devpilot/logs/usage/s-1.json"
assert_eq "$(jq -r .key "$U" 2>/dev/null)" "ADO-345" "usage attributed to the branch's work item"
assert_eq "$(jq -r '.models[] | select(.model=="claude-sonnet-5") | .output' "$U" 2>/dev/null)" "1000000" "a message repeated in the transcript is counted once"
assert_eq "$(jq -r '.models[] | select(.model|startswith("claude-haiku")) | .output' "$U" 2>/dev/null)" "7" "subagent usage included"
printf 'pricing:\n  claude-sonnet-5: "3/15"\n' >> "$D/project.config.md"
assert_contains "$(cd "$D" && bash scripts/metrics.sh usage)" '$15.00' "metrics prices output tokens per model"
assert_contains "$(cat "$REPO/.claude/settings.json")" "usage-hook.sh" "usage hook registered (Stop + SessionEnd)"
rm -rf "$D"

echo "== secrets provider (keychain via secret-tool) =="
D=$(sandbox); FK=$(mktemp -d); cp "$REPO/tests/fake-secret-tool.sh" "$FK/secret-tool"; chmod +x "$FK/secret-tool"; export FAKE_STORE="$D/store"
printf 'tracker:\n  type: local\nsecrets:\n  provider: keychain\n' > "$D/project.config.md"
( cd "$D" && PATH="$FK:/usr/bin:/bin" bash scripts/tracker.sh setup azure azdo_org_url=https://dev.azure.com/a azdo_project=P azdo_pat=s3cret >/dev/null 2>&1 )
assert_eq "$(grep -c s3cret "$D/.devpilot/config.sh" 2>/dev/null)" "0" "PAT is not written to config.sh"
assert_contains "$(cat "$D/.devpilot/config.sh")" "AZDO_ORG_URL" "non-secret values still go to config.sh"
assert_eq "$(cd "$D" && PATH="$FK:/usr/bin:/bin" bash -c '. scripts/devpilot-lib.sh; dp_load_secrets; echo "$AZDO_PAT"')" "s3cret" "PAT read back from the keychain"
assert_eq "$(cd "$D" && AZDO_PAT=env PATH="$FK:/usr/bin:/bin" bash -c '. scripts/devpilot-lib.sh; dp_load_secrets; echo "$AZDO_PAT"')" "env" "environment still wins over the keychain"
unset FAKE_STORE; rm -rf "$D" "$FK"

echo "== layer tasks: Jira sub-tasks under a Story (mocked) =="
MOCKBIN=$(mktemp -d); cp "$REPO/tests/mock-curl.sh" "$MOCKBIN/curl"; chmod +x "$MOCKBIN/curl"
D=$(sandbox); export MOCK_LOG="$D/mock.log"; mkdir -p "$D/.devpilot"
printf 'JIRA_BASE_URL="https://acme.atlassian.net"\nJIRA_EMAIL="d@a.io"\nJIRA_API_TOKEN=t\nJIRA_PROJECT_KEY="MSK"\n' > "$D/.devpilot/config.sh"
( cd "$D" && bash scripts/tracker.sh use jira 2>/dev/null && PATH="$MOCKBIN:$PATH" bash scripts/tracker.sh breakdown MSK-7 backend,frontend "CSV" >/dev/null 2>&1 )
assert_contains "$(cat "$MOCK_LOG")" '"issuetype":{"name":"Subtask"}' "Jira layer tasks are sub-tasks of the Story"
assert_contains "$(cat "$MOCK_LOG")" '"summary":"[FE]CSV"' "one [FE] task (summary spaces stripped by the mock log)"
unset MOCK_LOG; rm -rf "$D" "$MOCKBIN"

echo "== release/hotfix finish through PRs (fake gh doing real merges) =="
W=$(mktemp -d); FG=$(mktemp -d); cp "$REPO/tests/fake-gh.sh" "$FG/gh"; chmod +x "$FG/gh"; export FAKE_GH_DIR="$W/gh"
git init -q --bare "$W/origin.git"; git clone -q "$W/origin.git" "$W/app" 2>/dev/null
(
  cd "$W/app" || exit 1
  git config user.email t@t; git config user.name t
  mkdir scripts && cp "$REPO"/scripts/*.sh scripts/
  printf 'base_branch: develop\ngit_host: github\nmerge_policy: auto\n' > project.config.md
  echo 1.4.0 > VERSION && git add -A && git commit -qm "chore: init" && git branch -M main && git push -q origin main 2>/dev/null
  git checkout -q -b develop && echo 1.5.0 > VERSION && git commit -qam "feat: x" && git push -q origin develop 2>/dev/null
  PATH="$FG:$PATH" bash scripts/git-flow.sh release-start >/dev/null 2>&1
  echo polish > r.txt && git add r.txt && git commit -qm "fix: polish"
) >/dev/null 2>&1
RC=$(cd "$W/app" && FAKE_GH_BLOCK=1 PATH="$FG:$PATH" bash scripts/git-flow.sh release-finish 1.5.0 >/dev/null 2>&1; echo $?)
assert_code "$RC" "3" "release-finish stops while the PR into main is not merged (no direct push)"
assert_eq "$(git -C "$W/origin.git" rev-parse -q --verify refs/tags/v1.5.0 >/dev/null && echo tagged || echo none)" "none" "nothing tagged before main has the release"
RC=$(cd "$W/app" && PATH="$FG:$PATH" bash scripts/git-flow.sh release-finish 1.5.0 >/dev/null 2>&1; echo $?)
assert_code "$RC" "0" "re-running release-finish completes once the PR can merge"
assert_eq "$(git -C "$W/origin.git" rev-parse "v1.5.0^{commit}")" "$(git -C "$W/origin.git" rev-parse main)" "tag v1.5.0 is main's merge commit"
assert_eq "$(git -C "$W/origin.git" log -1 --format=%s main)" "Merge pull request #1 from release/1.5.0" "release merged into main with a merge commit"
assert_eq "$(git -C "$W/origin.git" log -1 --format=%s develop)" "Merge pull request #2 from release/1.5.0" "release merged back into develop through a PR"
assert_eq "$(git -C "$W/origin.git" branch --list 'release/*' | wc -l | tr -d ' ')" "0" "release branch deleted"
( cd "$W/app" && git checkout -q main 2>/dev/null && git pull -q origin main 2>/dev/null \
  && PATH="$FG:$PATH" bash scripts/git-flow.sh hotfix-start MSK-9 login-fix >/dev/null 2>&1 \
  && echo hot > h.txt && echo 1.5.1 > VERSION && git add -A && git commit -qm "fix: login" ) >/dev/null 2>&1
RC=$(cd "$W/app" && PATH="$FG:$PATH" bash scripts/git-flow.sh hotfix-finish 1.5.1 >/dev/null 2>&1; echo $?)
assert_code "$RC" "0" "hotfix-finish goes through PRs too"
assert_eq "$(git -C "$W/origin.git" rev-parse "v1.5.1^{commit}")" "$(git -C "$W/origin.git" rev-parse main)" "hotfix tagged on main"
assert_contains "$(git -C "$W/origin.git" log -1 --format=%s develop)" "hotfix/msk-9-login-fix" "hotfix merged back into develop"
unset FAKE_GH_DIR; rm -rf "$W" "$FG"

echo "== deploy templates (fake az / sqlcmd / kubectl / docker / ssh) =="
FK=$(mktemp -d)
for T in az sqlcmd kubectl docker ssh scp zip; do
  cat > "$FK/$T" <<'EOF'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >> "$FAKE_LOG"
case " ${FAKE_FAIL:-} " in *" $(basename "$0") "*) exit 1 ;; esac
case "$(basename "$0") $1 $2" in
  "docker manifest inspect") [ -n "${FAKE_IMAGE_EXISTS:-}" ] && exit 0; exit 1 ;;
  "kubectl -n"*) case "$*" in *"rollout status"*) [ -n "${FAKE_ROLLOUT_FAIL:-}" ] && exit 1 ;; esac ;;
esac
exit 0
EOF
  chmod +x "$FK/$T"
done
D=$(sandbox); mkdir -p "$D/.devpilot"; cp -r "$REPO/.devpilot/templates" "$D/.devpilot/"
mkdir -p "$D/out/api" "$D/out/web/web/browser" "$D/out/db"
echo 2.0.0 > "$D/out/VERSION"; echo '{}' > "$D/out/api/Shop.Api.runtimeconfig.json"
echo '<html>' > "$D/out/web/web/browser/index.html"; echo 'SELECT 1' > "$D/out/db/migrations.sql"
export FAKE_LOG="$D/fake.log"
( cd "$D" && bash scripts/deploy-init.sh appservice >/dev/null )
assert_eq "$([ -x "$D/deploy/deploy.sh" ] && [ -f "$D/deploy/db.sh" ] && echo yes)" "yes" "deploy-init installs deploy/deploy.sh + db.sh"
OUT=$(cd "$D" && bash scripts/deploy-init.sh kubernetes 2>&1)
assert_contains "$OUT" "already exists" "deploy-init never overwrites without --force"
OUT=$(cd "$D" && PATH="$FK:$PATH" bash scripts/deploy.sh sit out 2>&1); RC=$?
assert_code "$RC" "1" "App Service template refuses to run without its settings"
assert_contains "$OUT" "AZURE_RESOURCE_GROUP is not set" "and names the missing setting"
: > "$FAKE_LOG"
OUT=$(cd "$D" && AZURE_RESOURCE_GROUP=rg-shop API_APP=shop-api WEB_APP=shop-web SLOT=staging SQL_SERVER=sql.x SQL_DATABASE=shop SQL_USER=u SQL_PASSWORD=p \
  PATH="$FK:$PATH" bash scripts/deploy.sh sit out 2>&1); RC=$?
L=$(cat "$FAKE_LOG")
assert_code "$RC" "0" "App Service deploy succeeds with its settings"
assert_contains "$L" "sqlcmd -S sql.x -d shop -U u -i" "migrations applied before the app"
assert_contains "$L" "az webapp deploy -g rg-shop -n shop-api" "API zip-deployed"
assert_contains "$L" "--slot staging" "deployed to the staging slot"
assert_contains "$L" "slot swap -g rg-shop -n shop-web --slot staging --target-slot production" "slot swapped → zero downtime"
assert_contains "$OUT" "v2.0.0" "deploys the artifact's version"
( cd "$D" && bash scripts/deploy-init.sh kubernetes --force >/dev/null ); : > "$FAKE_LOG"
OUT=$(cd "$D" && REGISTRY=acr.io/shop KUBE_NAMESPACE=shop-sit PATH="$FK:$PATH" bash scripts/deploy.sh sit out 2>&1); RC=$?
L=$(cat "$FAKE_LOG")
assert_code "$RC" "0" "Kubernetes deploy succeeds"
assert_contains "$L" "docker push -q acr.io/shop/api:2.0.0" "API image built + pushed once per version"
assert_contains "$L" "set image deployment/api api=acr.io/shop/api:2.0.0" "deployment rolled to the new image"
assert_contains "$(cat "$D/out/api/Dockerfile.devpilot")" 'ENTRYPOINT ["dotnet", "Shop.Api.dll"]' "entrypoint from the published runtimeconfig"
: > "$FAKE_LOG"
( cd "$D" && FAKE_IMAGE_EXISTS=1 REGISTRY=acr.io/shop KUBE_NAMESPACE=shop-uat PATH="$FK:$PATH" bash scripts/deploy.sh uat out >/dev/null 2>&1 )
assert_eq "$(grep -c 'docker build' "$FAKE_LOG")" "0" "next environment promotes the same image (no rebuild)"
: > "$FAKE_LOG"
OUT=$(cd "$D" && FAKE_ROLLOUT_FAIL=1 REGISTRY=acr.io/shop KUBE_NAMESPACE=shop-sit PATH="$FK:$PATH" bash scripts/deploy.sh sit out 2>&1); RC=$?
assert_code "$RC" "1" "failed rollout fails the deploy"
assert_contains "$(cat "$FAKE_LOG")" "rollout undo deployment/api" "and undoes the rollout"
( cd "$D" && bash scripts/deploy-init.sh iis --force >/dev/null ); : > "$FAKE_LOG"
OUT=$(cd "$D" && IIS_SERVER=web01 IIS_USER=deploy IIS_SSH_KEY=k IIS_API_PATH='C:/inetpub/api' IIS_API_POOL=ShopApi PATH="$FK:$PATH" bash scripts/deploy.sh sit out 2>&1); RC=$?
assert_code "$RC" "0" "IIS deploy succeeds"
assert_contains "$(cat "$FAKE_LOG")" "Stop-WebAppPool -Name 'ShopApi'" "IIS: app pool stopped, files mirrored, pool started"
assert_contains "$(cat "$FAKE_LOG")" "robocopy 'C:/devpilot-releases/2.0.0/api' 'C:/inetpub/api' /MIR" "IIS: release folder mirrored into the site"
( cd "$D" && bash scripts/deploy-init.sh appservice --force >/dev/null )
RC=$(cd "$D" && FAKE_FAIL=az AZURE_RESOURCE_GROUP=rg API_APP=a PATH="$FK:$PATH" bash scripts/deploy.sh sit out >/dev/null 2>&1; echo $?)
assert_code "$RC" "1" "a failing az command fails the deploy (no silent && chains)"
( cd "$D" && bash scripts/deploy-init.sh kubernetes --force >/dev/null )
RC=$(cd "$D" && FAKE_FAIL=docker REGISTRY=r KUBE_NAMESPACE=n PATH="$FK:$PATH" bash scripts/deploy.sh sit out >/dev/null 2>&1; echo $?)
assert_code "$RC" "1" "a failing image build fails the deploy"
# The generated CD build step must stop on the first failing command
( cd "$D" && mkdir -p web && printf '{}' > web/angular.json && touch web/package.json \
  && printf 'stack:\n  frontend: angular\n  backend: none\n' > project.config.md && bash scripts/generate-ci.sh --force --github >/dev/null 2>&1 )
if python3 -c "import yaml" 2>/dev/null; then
  python3 - "$D/.github/workflows/devpilot-cd.yml" > "$D/build.sh" <<'PYX'
import sys, yaml
jobs = yaml.safe_load(open(sys.argv[1]))["jobs"]
print(next(s["run"] for s in jobs["build"]["steps"] if s.get("name", "").startswith("build once")))
PYX
  printf '#!/usr/bin/env bash\nexit 1\n' > "$FK/npm"; chmod +x "$FK/npm"
  RC=$(cd "$D" && PATH="$FK:$PATH" bash build.sh >/dev/null 2>&1; echo $?)
  assert_code "$RC" "1" "CD build step fails when npm ci fails (never ships without the frontend)"
fi
unset FAKE_LOG; rm -rf "$D" "$FK"

echo "== close-delivery.sh (after merge) =="
D=$(sandbox)
( cd "$D" && git commit -q --allow-empty -m base && git branch -M develop && git checkout -q -b feature/local-2-csv \
  && bash scripts/tracker.sh skip 2>/dev/null )
E=$(cd "$D" && bash scripts/tracker.sh new Epic "Reports" "g" 2>/dev/null)
K=$(cd "$D" && bash scripts/tracker.sh new Story "CSV" "a" "$E" 2>/dev/null)
SP=$(cd "$D" && bash scripts/tracker.sh sprint create "S1" 2>/dev/null); ( cd "$D" && bash scripts/tracker.sh sprint assign "$SP" "$K" 2>/dev/null )
OUT=$(cd "$D" && bash scripts/close-delivery.sh --prepare --version 1.3.0 --sprint "$SP" "$K" 2>/dev/null); RC=$?
assert_code "$RC" "0" "local tracker: close-delivery --prepare closes items inside the PR"
assert_contains "$(cd "$D" && git diff --cached --name-only)" "docs/tasks/$K.md" "closed items are staged for the PR"
( cd "$D" && git commit -qm "chore: deliver" && git checkout -q develop && git merge -q feature/local-2-csv && git checkout -q feature/local-2-csv )
OUT=$(cd "$D" && bash scripts/close-delivery.sh --pr https://x/pr/1 --version 1.3.0 --sprint "$SP" "$K" 2>/dev/null); RC=$?
assert_code "$RC" "0" "close-delivery after merge succeeds"
assert_contains "$OUT" "closed inside the merged PR" "local tracker: nothing changes on develop after merge"
assert_contains "$(cat "$D/docs/tasks/$K.md")" "Status: Done" "Story closed"
assert_contains "$(cat "$D/docs/tasks/$K.md")" "v1.3.0" "merged comment carries the version"
assert_contains "$(cat "$D/docs/tasks/$E.md")" "Status: Done" "Epic closed with its last Story"
assert_contains "$(cat "$D/docs/sprints/$SP.md")" "State: closed" "sprint closed when empty"
assert_eq "$(cd "$D" && git branch --show-current)" "develop" "back on develop after the merge"
rm -rf "$D"

echo "== scope.sh =="
D=$(sandbox)
mkdir -p "$D/docs"
cat > "$D/docs/project-index.md" <<'EOF'
# Project Index
## Components
  src/app/header/logout.component.ts          — LogoutComponent
  src/auth/LoginController.cs                  — LoginController
  src/orders/OrderService.cs                   — OrderService
EOF
OUT=$(cd "$D" && bash scripts/scope.sh "add a logout button to the header" 2>/dev/null)
assert_contains "$OUT" "logout.component.ts" "scope ranks the matching file"
FIRST=$(printf '%s\n' "$OUT" | grep -E '^\s*\[[0-9]+\]' | head -1)
assert_contains "$FIRST" "logout" "best match ranked first"
rm -rf "$D"

echo "== scope-guard.sh =="
D=$(sandbox)
( cd "$D" && echo "x" > a.component.ts && git add a.component.ts )
set +e
( cd "$D" && STRICT=1 bash scripts/scope-guard.sh backend >/dev/null 2>&1 ); GC=$?
set -e 2>/dev/null || true
assert_code "$GC" "1" "STRICT backend flags a .component.ts change"
set +e
( cd "$D" && STRICT=1 bash scripts/scope-guard.sh frontend >/dev/null 2>&1 ); GC2=$?
assert_code "$GC2" "0" "frontend layer allows the .component.ts change"
rm -rf "$D"

echo "== open-pr.sh =="
set +e
bash "$REPO/scripts/open-pr.sh" >/dev/null 2>&1; OC=$?
assert_code "$OC" "1" "open-pr with no args → exit 1"

echo "== scope-hook.sh =="
D=$(sandbox)
( cd "$D" && mkdir -p .devpilot && echo backend > .devpilot/.scope-lock )
set +e
printf '{"tool_input":{"file_path":"src/x.component.ts"}}' | ( cd "$D" && bash scripts/scope-hook.sh >/dev/null 2>&1 ); HC=$?
assert_code "$HC" "2" "lock=backend blocks a .component.ts write"
printf '{"tool_input":{"file_path":"src/Api/Foo.cs"}}' | ( cd "$D" && bash scripts/scope-hook.sh >/dev/null 2>&1 ); HA=$?
assert_code "$HA" "0" "lock=backend allows a .cs write"
( cd "$D" && rm -f .devpilot/.scope-lock )
printf '{"tool_input":{"file_path":"anything.html"}}' | ( cd "$D" && bash scripts/scope-hook.sh >/dev/null 2>&1 ); HN=$?
assert_code "$HN" "0" "no lock → allow"
rm -rf "$D"

echo "== test-guard.sh =="
D=$(sandbox)
( cd "$D" && git checkout -qb develop && echo base > base.txt && git add -A && git -c commit.gpgsign=false commit -qm base )
( cd "$D" && git checkout -qb feature/x && printf 'export class FooService {}\n' > foo.service.ts \
  && git add foo.service.ts && git -c commit.gpgsign=false commit -qm "feat: foo" )
set +e
OUT=$( cd "$D" && bash scripts/test-guard.sh 2>/dev/null ); RC=$?
assert_code "$RC" "0" "report mode always exits 0"
assert_contains "$OUT" "foo.service.ts" "guard flags the untested source file"
( cd "$D" && STRICT=1 bash scripts/test-guard.sh >/dev/null 2>&1 ); RC=$?
assert_code "$RC" "1" "STRICT=1 fails on a coverage gap"
( cd "$D" && printf 'it("works")\n' > foo.service.spec.ts && git add foo.service.spec.ts \
  && git -c commit.gpgsign=false commit -qm "test: foo" )
( cd "$D" && STRICT=1 bash scripts/test-guard.sh >/dev/null 2>&1 ); RC=$?
assert_code "$RC" "0" "STRICT=1 passes once the spec exists"
( cd "$D" && echo 'x' > notes.md && git add notes.md && git -c commit.gpgsign=false commit -qm "docs: notes" )
( cd "$D" && STRICT=1 bash scripts/test-guard.sh >/dev/null 2>&1 ); RC=$?
assert_code "$RC" "0" "docs/config changes are exempt"
rm -rf "$D"

echo "== two-tier index + scope cache (token-lean) =="
D=$(mktemp -d); git -C "$D" init -q; git -C "$D" config user.email t@t.t; git -C "$D" config user.name t; git -C "$D" config commit.gpgsign false
mkdir -p "$D/scripts" "$D/src/app/header" "$D/src/orders"
cp "$REPO"/scripts/generate-project-index.sh "$REPO"/scripts/scope.sh "$D/scripts/"
printf 'stack:\n  frontend: angular\n  backend: dotnet\n  database: sqlserver\n' > "$D/project.config.md"
echo 'export class LogoutComponent {}' > "$D/src/app/header/logout.component.ts"
echo 'public class OrdersController {}' > "$D/src/orders/OrdersController.cs"
( cd "$D" && git add -A && git commit -qm init )
OUT=$( cd "$D" && bash scripts/generate-project-index.sh )
assert_contains "$OUT" "shard(s)" "index builds map + shards"
[ -f "$D/docs/index/frontend.md" ] && ok "frontend shard written" || no "frontend shard written"
MAPLINES=$(wc -l < "$D/docs/project-index.md" | tr -d ' ')
assert_eq "$([ "$MAPLINES" -lt 100 ] && echo ok)" "ok" "map stays small (<100 lines, got $MAPLINES)"
assert_contains "$(cat "$D/docs/project-index.md")" "scope.sh" "map instructs scope.sh, not wholesale reads"
OUT=$( cd "$D" && bash scripts/generate-project-index.sh )
assert_contains "$OUT" "skipped" "unchanged repo → hash-gated skip"
( cd "$D" && echo 'export class NewComponent {}' > src/app/new.component.ts && git add -A && git commit -qm "feat: new" )
OUT=$( cd "$D" && bash scripts/generate-project-index.sh )
assert_contains "$OUT" "written" "content change → regenerates"
# scope finds entries from the shards, saves a reusable per-task scope
OUT=$( cd "$D" && bash scripts/scope.sh --save logout-task "add a logout button to the header" )
assert_contains "$OUT" "logout.component.ts" "scope ranks shard entries"
[ -f "$D/docs/tasks/logout-task-scope.md" ] && ok "scope saved per task" || no "scope saved per task"
OUT=$( cd "$D" && bash scripts/scope.sh --save logout-task "add a logout button to the header" )
assert_contains "$OUT" "cached scope" "second call is a cache hit (no re-derivation)"
rm -rf "$D"

echo "== generate-ci.sh / protect-branches.sh / notify.sh =="
D=$(sandbox)
( cd "$D" && mkdir -p web && printf '{}' > web/angular.json && touch web/package.json && bash scripts/generate-ci.sh >/dev/null 2>&1 )
CI_FILE="$D/.github/workflows/devpilot-ci.yml"
[ -f "$CI_FILE" ] && ok "generate-ci writes the workflow" || no "generate-ci writes the workflow"
assert_contains "$(cat "$CI_FILE" 2>/dev/null)" "working-directory: web" "Angular steps run in the Angular workspace"
assert_contains "$(cat "$CI_FILE" 2>/dev/null)" "dotnet test" ".NET tests in CI"
assert_contains "$(cat "$CI_FILE" 2>/dev/null)" "test-guard.sh" "workflow runs the test guard"
assert_contains "$(cat "$CI_FILE" 2>/dev/null)" "audit.sh" "workflow runs the dependency audit"
assert_contains "$(cat "$CI_FILE" 2>/dev/null)" "name: devpilot-ci" "check is named devpilot-ci (for protection)"
OUT=$( cd "$D" && bash scripts/generate-ci.sh 2>/dev/null ); RC=$?
assert_code "$RC" "0" "second run without --force exits 0"
assert_contains "$OUT" "already exists" "second run refuses to clobber"
( cd "$D" && git remote add origin https://dev.azure.com/acme/Shop/_git/web && bash scripts/generate-ci.sh >/dev/null 2>&1 )
AZ="$D/azure-pipelines.yml"
assert_contains "$(cat "$AZ" 2>/dev/null)" "UseDotNet@2" "Azure Repos → azure-pipelines.yml with .NET"
assert_contains "$(cat "$AZ" 2>/dev/null)" "SYSTEM_PULLREQUEST_TARGETBRANCH" "Azure pipeline runs test-guard on PRs"
OUT=$( cd "$D" && bash scripts/protect-branches.sh 2>/dev/null ); RC=$?
assert_code "$RC" "0" "protect-branches on Azure exits 0"
assert_contains "$OUT" "Build validation" "protect-branches explains Azure branch policies"
# notify: unconfigured → silent success + durable log
( cd "$D" && bash scripts/notify.sh "done" "sprint built" >/dev/null 2>&1 ); RC=$?
assert_code "$RC" "0" "notify exits 0 when unconfigured"
assert_contains "$(cat "$D/docs/tasks/notifications.log" 2>/dev/null)" "sprint built" "notify always logs the event"
# protect-branches: degrades gracefully without gh auth
OUT=$( cd "$D" && PATH=/usr/bin:/bin bash scripts/protect-branches.sh 2>/dev/null ); RC=$?
assert_code "$RC" "0" "protect-branches exits 0 without gh"
rm -rf "$D"

echo "== doctor.sh / status.sh / metrics.sh / audit.sh run cleanly =="
D=$(sandbox)
set +e
( cd "$D" && bash scripts/doctor.sh >/dev/null 2>&1 ); assert_code "$?" "0" "doctor exits 0 on a sane sandbox"
( cd "$D" && bash scripts/status.sh >/dev/null 2>&1 ); assert_code "$?" "0" "status runs"
( cd "$D" && bash scripts/metrics.sh >/dev/null 2>&1 ); assert_code "$?" "0" "metrics runs"
( cd "$D" && bash scripts/audit.sh >/dev/null 2>&1 ); assert_code "$?" "0" "audit runs (no manifest)"
rm -rf "$D"

echo "== changelog.sh =="
set +e
bash "$REPO/scripts/changelog.sh" >/dev/null 2>&1; assert_code "$?" "1" "changelog with no version → exit 1"

echo "== resolve-model.sh (Claude per-task tier) =="
D=$(mktemp -d)
git -C "$D" init -q
mkdir -p "$D/scripts"
cp "$REPO/scripts/resolve-model.sh" "$D/scripts/"
printf 'coding_models:\n  claude:\n    power:    "claude-opus-test"\n    standard: "claude-sonnet-test"\n    lite:     "claude-haiku-test"\n\nmodels:\n  ba:\n    tier1: x\n' > "$D/project.config.md"
SG=$( cd "$D" && bash scripts/resolve-model.sh suggest "refactor the auth schema across services" )
assert_contains "$SG" "COMPLEXITY=high" "architectural task → high complexity"
assert_contains "$SG" "MODEL=claude-opus-test" "high complexity → power tier model"
SG=$( cd "$D" && bash scripts/resolve-model.sh suggest "add a logout button" )
assert_contains "$SG" "TIER=standard" "simple task → standard tier"
assert_contains "$SG" "MODEL=claude-sonnet-test" "standard tier → standard model"
assert_contains "$( cd "$D" && bash scripts/resolve-model.sh tier lite )" "MODEL=claude-haiku-test" "tier lookup reads coding_models.claude"
eval "$( cd "$D" && bash scripts/resolve-model.sh suggest "add a button" )"
assert_eq "$TIER" "standard" "suggest output is eval-safe"
rm -rf "$D"

echo "== process-logging policy (core-rules #11) =="
# The policy: each /dp-deliver flow posts only a start + DONE comment to the ticket
# (plus BLOCKED as the exception). Routine progress comments must not creep back.
assert_contains "$(cat "$REPO/.claude/skills/core-rules/SKILL.md")" "Process logging" "core-rules documents the policy"
ROUTINE_RE='tracker.sh comment "\$KEY" "(✅ QA passed|✅ Layer-Locked QA Passed|✅ Merged into|✅ Layer-Locked PR merged|📋 Plan complete|⚙️ Implementation complete|⚙️ Fix implemented)'
# Glob the actual command set so this never goes stale when commands are renamed.
for CMD in "$REPO"/.claude/commands/*.md; do
  f=$(basename "$CMD")
  n=$(grep -cE "$ROUTINE_RE" "$CMD"); n=${n:-0}
  assert_eq "$n" "0" "$f posts no routine progress comments"
done

echo "== model-profiles.sh =="
MP="$REPO/scripts/model-profiles.sh"
# claude profile → tier mapping
assert_contains "$(bash "$MP" claude-map auto)"     "POWER=claude-opus-5-5"   "claude auto uses Opus for power"
assert_contains "$(bash "$MP" claude-map balanced)" "POWER=claude-sonnet-5" "claude balanced caps power at Sonnet"
assert_contains "$(bash "$MP" claude-map save)"     "STANDARD=claude-haiku-4-5-20251001" "claude save defaults standard to Haiku"
assert_code "$(bash "$MP" claude-map bogus >/dev/null 2>&1; echo $?)" "1" "claude-map rejects an unknown profile"
# non-Claude engines are gone
assert_code "$(bash "$MP" opencode-map recommended >/dev/null 2>&1; echo $?)" "1" "opencode support removed"
# apply writes coding_profile + tiers + syncs agent frontmatter, idempotently
D=$(sandbox); cp "$REPO"/project.config.md "$D/"; mkdir -p "$D/.claude/agents"
cp "$REPO"/.claude/agents/team-ba.md "$REPO"/.claude/agents/team-lead.md "$REPO"/.claude/agents/team-qa.md \
   "$REPO"/.claude/agents/team-frontend.md "$REPO"/.claude/agents/team-dotnet.md "$D/.claude/agents/" 2>/dev/null
( cd "$D" && bash scripts/model-profiles.sh apply save >/dev/null 2>&1 )
( cd "$D" && bash scripts/model-profiles.sh apply claude save >/dev/null 2>&1 )   # legacy form, twice → must stay single line
assert_eq "$(grep -c 'coding_profile:' "$D/project.config.md")" "1" "apply is idempotent (one coding_profile line)"
assert_eq "$(grep -cE '^[[:space:]]+model_mode:' "$D/project.config.md")" "1" "apply keeps one model_mode line"
assert_contains "$(cat "$D/project.config.md")" "coding_profile: save" "apply records the profile"
assert_contains "$(cat "$D/project.config.md")" "model_mode: recommended" "apply records model_mode recommended"
assert_contains "$(grep '^model:' "$D/.claude/agents/team-lead.md")" "claude-haiku-4-5-20251001" "apply syncs agent frontmatter (save → Haiku lead)"
assert_contains "$(grep '^model:' "$D/.claude/agents/team-frontend.md")" "claude-haiku-4-5-20251001" "apply syncs dev agents to the standard tier (save → Haiku FE)"
# single-model mode: one model everywhere (tiers + every agent + model_mode)
( cd "$D" && bash scripts/model-profiles.sh single claude test-model-x >/dev/null 2>&1 )
assert_contains "$(cat "$D/project.config.md")" "model_mode: single" "single records model_mode"
assert_eq "$(grep -cE '^[[:space:]]+model_mode:' "$D/project.config.md")" "1" "single keeps one model_mode line"
assert_contains "$(grep '^model:' "$D/.claude/agents/team-dotnet.md")" "test-model-x" "single syncs dev agent frontmatter"
assert_contains "$(grep '^model:' "$D/.claude/agents/team-ba.md")" "test-model-x" "single syncs orchestrator frontmatter"
assert_eq "$(grep -c '"test-model-x"' "$D/project.config.md")" "3" "single sets all three claude tiers"
( cd "$D" && bash scripts/model-profiles.sh apply claude save >/dev/null 2>&1 )   # back to a profile
# sync-agents re-applies frontmatter from project.config.md (the --update repair path)
( cd "$D" && sed -i 's/^model: .*/model: claude-sonnet-5/' .claude/agents/team-lead.md && bash scripts/model-profiles.sh sync-agents >/dev/null 2>&1 )
assert_contains "$(grep '^model:' "$D/.claude/agents/team-lead.md")" "claude-haiku-4-5-20251001" "sync-agents restores frontmatter from config"
# switching profile keeps a single coding_profile line
( cd "$D" && bash scripts/model-profiles.sh apply balanced >/dev/null 2>&1 )
assert_eq "$(grep -c 'coding_profile:' "$D/project.config.md")" "1" "profile switch keeps one coding_profile line"
assert_contains "$(cat "$D/project.config.md")" "coding_profile: balanced" "profile switch records the profile"
( cd "$D" && bash scripts/model-profiles.sh single test-model-y >/dev/null 2>&1 )
assert_contains "$(grep '^model:' "$D/.claude/agents/team-qa.md")" "test-model-y" "single accepts a bare model id"
rm -rf "$D"

echo "== testing & auto-merge wiring (round 4) =="
# New skills exist, are indexed, and the installer ships them (update + fresh lists).
for SK in test-case-design ui-e2e-playwright performance auto-merge token-lean-testing \
          angular-dev angular-testing dotnet-api dotnet-testing efcore-sqlserver api-contract release-ops; do
  [ -f "$REPO/.claude/skills/$SK/SKILL.md" ] && ok "skill $SK exists" || no "skill $SK exists"
  assert_contains "$(cat "$REPO/.claude/skills/README.md")" "\`$SK\`" "skills index lists $SK"
  assert_contains " $(sed -n 's/^DEVPILOT_SKILLS="\(.*\)"/\1/p' "$REPO/install.sh") " " $SK " "installer ships skill $SK"
done
# New commands exist and the installer ships them.
for C in dp-test dp-pr; do
  [ -f "$REPO/.claude/commands/$C.md" ] && ok "command $C.md exists" || no "command $C.md exists"
  n=$(grep -c "$C.md" "$REPO/install.sh"); n=${n:-0}
  assert_eq "$([ "$n" -ge 2 ] && echo ok)" "ok" "installer ships $C.md in both lists"
done
# The process contract exists, ships, and is referenced from project context.
[ -f "$REPO/.devpilot/process.md" ] && ok "process.md exists" || no "process.md exists"
n=$(grep -c '\.devpilot/process\.md' "$REPO/install.sh"); n=${n:-0}
assert_eq "$([ "$n" -ge 2 ] && echo ok)" "ok" "installer fetches process.md (update + fresh)"
assert_contains "$(cat "$REPO/CLAUDE.md")" ".devpilot/process.md" "CLAUDE.md points at the process contract"
# QA agent derives cases before code; the build merge step honors the gate ladder.
assert_contains "$(cat "$REPO/.devpilot/prompts/team/qa-agent.md")" "test-case-design" "qa-agent loads test-case-design"
assert_contains "$(cat "$REPO/.claude/commands/dp-build.md")" "auto-merge" "dp-build merge step cites the gate ladder"

echo "== setup wizard: model assignment + guide (round 5) =="
[ -f "$REPO/docs/setup-guide.md" ] && ok "setup-guide.md exists" || no "setup-guide.md exists"
n=$(grep -c 'docs/setup-guide.md' "$REPO/install.sh"); n=${n:-0}
assert_eq "$([ "$n" -ge 2 ] && echo ok)" "ok" "installer ships the setup guide (update + fresh)"
INSTALL=$(cat "$REPO/install.sh")
assert_contains "$INSTALL" 'MODEL_MODE="single"' "wizard offers single-model mode"
assert_contains "$INSTALL" 'MODEL_MODE="per-team"' "wizard offers per-team mode"
assert_contains "$INSTALL" "model_policy:" "generated config includes model_policy"
n=$(grep -c "opencode\|antigravity\|layer_overrides" "$REPO/install.sh" | head -1); assert_eq "$([ "${n:-0}" -le 3 ] && echo ok)" "ok" "installer carries no engine config beyond the --update cleanup"
assert_contains "$INSTALL" "frontend_dev:" "generated config includes dev role models"
assert_contains "$INSTALL" 'sync_model ".claude/agents/team-frontend.md"' "installer syncs dev agent frontmatter"
assert_contains "$(cat "$REPO/project.config.md")" "model_mode:" "repo config documents model_mode"
assert_contains "$(cat "$REPO/.claude/commands/dp-setup.md")" "model-profiles.sh single <model-id>" "dp-setup documents single-model switch"

echo "== test-guard + doctor + jira/reconfig wiring (round 6) =="
[ -f "$REPO/.claude/skills/test-guard/SKILL.md" ] && ok "test-guard skill exists" || no "test-guard skill exists"
assert_contains "$(cat "$REPO/.claude/skills/README.md")" "test-guard" "skills index lists test-guard"
assert_contains "$(sed -n '/^DEVPILOT_SKILLS=/p' "$REPO/install.sh")" " test-guard " "installer ships the test-guard skill"
n=$(grep -c 'test-guard\.sh' "$REPO/install.sh"); n=${n:-0}
assert_eq "$([ "$n" -ge 2 ] && echo ok)" "ok" "installer ships test-guard.sh in both lists"
assert_contains "$(cat "$REPO/.claude/skills/auto-merge/SKILL.md")" "test-guard" "auto-merge ladder runs the test guard"
assert_contains "$(cat "$REPO/.claude/commands/dp-build.md")" "test-guard.sh" "dp-build review gate runs the test guard"
assert_contains "$(cat "$REPO/.claude/commands/dp-pr.md")" "test-guard.sh" "dp-pr ladder runs the test guard"
assert_contains "$(cat "$REPO/scripts/doctor.sh")" "model_mode" "doctor validates model_mode"
assert_contains "$(cat "$REPO/scripts/doctor.sh")" "sync-agents" "doctor detects agent frontmatter drift"
assert_contains "$(cat "$REPO/scripts/doctor.sh")" "/dp-setup fix" "doctor points at the reconfig path"
assert_contains "$(cat "$REPO/.claude/commands/dp-setup.md")" "## fix" "dp-setup has a fix mode"
INSTALL=$(cat "$REPO/install.sh")
assert_contains "$INSTALL" "Review — your configuration" "wizard shows a confirm summary before writing"
assert_contains "$INSTALL" "id.atlassian.com/manage-profile/security/api-tokens" "wizard walks Jira token creation"
assert_contains "$INSTALL" 'tracker.sh setup "$TRACKER_TYPE"' "wizard validates the tracker live"
assert_contains "$INSTALL" "Azure DevOps" "wizard offers Azure DevOps"
assert_contains "$(cat "$REPO/docs/setup-guide.md")" "Jira" "setup guide covers Jira"
assert_contains "$(cat "$REPO/docs/setup-guide.md")" "Azure DevOps" "setup guide covers Azure DevOps"

echo "== ops round: CI gen, protection, notify, --defaults (round 7) =="
for SC in generate-ci protect-branches notify; do
  n=$(grep -c "$SC\.sh" "$REPO/install.sh"); n=${n:-0}
  assert_eq "$([ "$n" -ge 2 ] && echo ok)" "ok" "installer ships $SC.sh in both lists"
done
assert_contains "$INSTALL" "DEVPILOT_DEFAULTS" "installer supports --defaults"
assert_contains "$INSTALL" "NOTIFY_WEBHOOK" "config template includes NOTIFY_WEBHOOK"
assert_contains "$INSTALL" "generate-ci.sh" "wizard offers CI generation"
assert_contains "$INSTALL" "protect-branches.sh" "wizard offers branch protection"
assert_contains "$(cat "$REPO/.claude/commands/dp-build.md")" "notify.sh" "dp-build notifies on DONE/BLOCKED"
assert_contains "$(cat "$REPO/.claude/commands/dp-pr.md")" "notify.sh" "dp-pr notifies on merge/escalation"
assert_contains "$(cat "$REPO/README.md")" "--defaults" "README documents non-interactive install"
assert_contains "$(cat "$REPO/README.md")" "devpilot-ci" "README documents the generated CI"

echo "== update-org.sh guards =="
set +e
OUT=$(PATH=/usr/bin:/bin bash "$REPO/scripts/update-org.sh" some-org 2>&1); RC=$?
assert_code "$RC" "1" "update-org without gh exits 1"
assert_contains "$OUT" "gh CLI" "update-org explains the gh requirement"
OUT=$(bash "$REPO/scripts/update-org.sh" 2>&1); RC=$?
assert_code "$RC" "1" "update-org without an org exits 1 with usage"
assert_contains "$(cat "$REPO/scripts/update-org.sh")" "--update" "update-org uses --update, never delete+reinstall"

echo "== update-org.sh on Azure DevOps (dry run, mocked APIs, local repo) =="
MOCKBIN=$(mktemp -d); cp "$REPO/tests/mock-curl.sh" "$MOCKBIN/curl"; chmod +x "$MOCKBIN/curl"
W=$(mktemp -d); git init -q --bare "$W/web.git"
( cd "$W" && git clone -q web.git c 2>/dev/null && cd c && git config user.email t@t && git config user.name t \
  && mkdir .devpilot && touch .devpilot/rules.md project.config.md && git add -A && git commit -qm init && git branch -M main \
  && git push -q origin main 2>/dev/null && git push -q origin main:develop 2>/dev/null )
OUT=$(MOCK_REPO_URL="$W/web.git" AZDO_PAT=x PATH="$MOCKBIN:$PATH" bash "$REPO/scripts/update-org.sh" https://dev.azure.com/acme --dry-run 2>&1)
assert_contains "$OUT" "Shop/web (base: develop)" "Azure: lists project repos and targets develop over the default branch"
assert_contains "$OUT" "would update (dry run)" "Azure: dry run changes nothing"
rm -rf "$W" "$MOCKBIN"

echo "== token-lean wiring (round 8) =="
assert_contains "$(cat "$REPO/.claude/commands/dp-plan.md")" "scope.sh --save" "dp-plan saves the scope once"
assert_contains "$(cat "$REPO/.claude/commands/dp-build.md")" "-scope.md" "dp-build reuses the saved scope"
assert_contains "$(cat "$REPO/.devpilot/prompts/team/ba-agent.md")" "scope.sh --save" "ba-agent saves the scope"
assert_contains "$(cat "$REPO/CLAUDE.md")" "Two-tier index" "CLAUDE.md documents the two-tier index"
assert_contains "$(cat "$REPO/scripts/install-git-hooks.sh")" "post-merge" "git hooks refresh the index after merges"
assert_contains "$INSTALL" "docs/index/.state" "installer gitignores the index state file"
n=$(grep -c -- '-mmin' "$REPO/.claude/commands/dp-plan.md" || true); n=${n:-0}
assert_eq "$n" "0" "time-based freshness check removed from dp-plan"

echo "== run-tests.sh (token-lean runner) =="
D=$(sandbox)
OUT=$(cd "$D" && bash scripts/run-tests.sh cmd "echo 'Tests  3 passed'"); RC=$?
assert_code "$RC" "0" "passing command exits 0"
assert_contains "$OUT" "✅ PASS" "passing command reports PASS"
assert_eq "$([ -f "$D/.devpilot/logs/cmd.log" ] && echo yes)" "yes" "full log written to .devpilot/logs"
OUT=$(cd "$D" && TEST_MAX_LINES=5 bash scripts/run-tests.sh cmd 'for i in $(seq 1 200); do echo "Error: boom $i"; done; exit 3'); RC=$?
assert_code "$RC" "1" "failing command exits 1"
assert_contains "$OUT" "❌ FAIL" "failing command reports FAIL"
assert_eq "$([ "$(printf '%s\n' "$OUT" | wc -l)" -le 8 ] && echo capped)" "capped" "failure output capped by TEST_MAX_LINES"
OUT=$(cd "$D" && bash scripts/run-tests.sh all); RC=$?
assert_code "$RC" "0" "no suites detected exits 0"
assert_contains "$OUT" "no test suites detected" "reports when nothing to run"
assert_code "$(cd "$D" && bash scripts/run-tests.sh bogus >/dev/null 2>&1; echo $?)" "2" "unknown mode exits 2"
rm -rf "$D"

echo "== Angular + .NET skill set =="
SK="$REPO/.claude/skills"
# Every skill a command/agent/persona/doc names by path must exist (no dangling references).
MISSING=""
for ref in $(grep -rhoE '\.claude/skills/[a-z0-9-]+/SKILL\.md' "$REPO/.claude" "$REPO/.devpilot" "$REPO/scripts" "$REPO/CLAUDE.md" "$REPO/README.md" "$REPO/docs" | sort -u); do
  [ -f "$REPO/$ref" ] || MISSING="$MISSING $ref"
done
assert_eq "${MISSING:-none}" "none" "no dangling skill references"
OLDREF=$(grep -rlE '\.devpilot/skills|[a-z-]+-(dev|testing|guard|rules|ops|heal|scan|merge|contract|sqlserver|api|design|strategy|playwright|slicing|ready|done)\.md' "$REPO/.claude" "$REPO/.devpilot" "$REPO/scripts" "$REPO/CLAUDE.md" "$REPO/docs" 2>/dev/null | tr '\n' ' ')
# (README.md is exempt: its upgrade notes name the old layout on purpose.)
assert_eq "${OLDREF:-none}" "none" "no references to the old .devpilot/skills/*.md layout"
# Installer list == skills on disk; every skill is a valid native Claude Code skill.
ONDISK=$(find "$SK" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ')
LISTED=$(sed -n 's/^DEVPILOT_SKILLS="\(.*\)"/\1/p' "$REPO/install.sh" | tr ' ' '\n' | sort | tr '\n' ' ')
assert_eq "$LISTED" "$ONDISK" "installer skill list matches .claude/skills on disk"
BUNDLED="code-review security-review simplify run verify loop init debug batch doctor claude-api review run-skill-generator"
for d in "$SK"/*/; do
  n=$(basename "$d"); F="$d/SKILL.md"
  assert_eq "$(sed -n 1p "$F")" "---" "skill $n: frontmatter starts on line 1"
  FM=$(awk 'NR==1{next} /^---$/{exit} {print}' "$F")
  assert_eq "$(sed -n 's/^name: //p' <<<"$FM")" "$n" "skill $n: name matches its directory"
  assert_contains "$FM" "description: " "skill $n: has a description"
  assert_contains "$FM" "user-invocable: false" "skill $n: hidden from the / menu (commands are the entry points)"
  case " $BUNDLED " in *" $n "*) no "skill $n shadows a bundled Claude Code skill" ;; *) ok "skill $n: no clash with bundled skills" ;; esac
done
for A in "$REPO"/.claude/agents/*.md; do
  assert_contains "$(awk 'NR==1{next} /^---$/{exit} {print}' "$A")" "  - core-rules" "$(basename "$A"): preloads core-rules"
done
assert_eq "$([ -f "$REPO/.claude/agents/team-backend.md" ] && echo present || echo gone)" "gone" "generic backend agent retired"
assert_contains "$(cat "$REPO/.claude/commands/dp-build.md")" '"team-dotnet"' "dp-build routes backend work to team-dotnet"
assert_contains "$(cat "$REPO/.claude/commands/dp-test.md")" "ui-e2e-playwright" "dp-test drives Playwright UI testing"

echo "== Claude-only + role-based commands (v5) =="
CMDS_EXPECTED="dp-build dp-deliver dp-hotfix dp-plan dp-pr dp-release dp-setup dp-sprint dp-status dp-test"
CMDS_ACTUAL=$(ls "$REPO/.claude/commands" | sed 's/\.md$//' | sort | tr '\n' ' ' | sed 's/ $//')
assert_eq "$CMDS_ACTUAL" "$CMDS_EXPECTED" "exactly the 10 role commands ship"
for C in $CMDS_EXPECTED; do
  assert_contains "$(sed -n '/^  CMDS="/p' "$REPO/install.sh")" "$C.md" "installer --update ships $C"
done
for f in .opencode AGENTS.md scripts/resolve-engine.sh scripts/run-mode.sh scripts/run-command.sh scripts/ceo.sh; do
  assert_eq "$([ -e "$REPO/$f" ] && echo present || echo gone)" "gone" "$f removed"
done
LEAK=$(grep -rliE 'opencode|antigravity|github-copilot' "$REPO/.claude" "$REPO/.devpilot" "$REPO/CLAUDE.md" "$REPO/project.config.md" 2>/dev/null | tr '\n' ' ')
assert_eq "${LEAK:-none}" "none" "no non-Claude engine references in commands, skills, or config"
OLD=$(grep -rlE '/ceo\b|/dp-config\b|/dp-autofix|/dp-review-fix|/dp-rollback' "$REPO/.claude" "$REPO/.devpilot" "$REPO/scripts" "$REPO/CLAUDE.md" "$REPO/docs/setup-guide.md" 2>/dev/null | tr '\n' ' ')
assert_eq "${OLD:-none}" "none" "no retired command names outside the README upgrade table"
assert_contains "$(cat "$REPO/.claude/commands/dp-deliver.md")" "tracker.sh assert-key" "dp-deliver keeps the tracker-first gate"
assert_contains "$(cat "$REPO/.claude/commands/dp-deliver.md")" "tracker.sh check" "dp-deliver checks the tracker first"
assert_contains "$(cat "$REPO/.claude/commands/dp-deliver.md")" "Continue without a tracker" "dp-deliver offers to skip an unconfigured tracker"
assert_contains "$(cat "$REPO/.claude/commands/dp-plan.md")" "tracker.sh show" "dp-plan opens candidates' child items"
assert_contains "$(cat "$REPO/.claude/commands/dp-build.md")" 'version.sh bump "$LEVEL" --ref' "dp-build bumps from develop's version"
assert_contains "$(cat "$REPO/.claude/commands/dp-build.md")" "close-delivery.sh" "dp-build closes items + sprint after merge"
assert_contains "$(cat "$REPO/.claude/commands/dp-pr.md")" "azdo.sh pr-complete" "dp-pr merges on Azure Repos"
assert_contains "$(cat "$REPO/.claude/commands/dp-setup.md")" "## tracker" "dp-setup can connect a tracker"
RETIRED_REF=$(grep -rlE 'track\.sh|jira-guard|jira-sprint|create-jira|update-jira|add-jira-comment|link-jira|jira-describe|jira-brief' "$REPO/.claude" "$REPO/.devpilot" "$REPO/scripts" "$REPO/CLAUDE.md" "$REPO/README.md" "$REPO/docs/setup-guide.md" 2>/dev/null | tr '\n' ' ')
assert_eq "${RETIRED_REF:-none}" "none" "no references to retired tracker scripts"
MISSING=""
for f in "$REPO"/scripts/*.sh; do
  n=$(basename "$f"); [ "$n" = "update-org.sh" ] && continue
  c=$(grep -c "$n" "$REPO/install.sh"); [ "${c:-0}" -ge 2 ] || MISSING="$MISSING $n"
done
assert_eq "${MISSING:-none}" "none" "installer ships every script in both lists"
assert_contains "$(cat "$REPO/.claude/commands/dp-deliver.md")" "--to sit" "dp-deliver can promote to SIT"
assert_contains "$(cat "$REPO/.claude/commands/dp-release.md")" "STAGE = rollback" "dp-release absorbs rollback"
assert_contains "$(cat "$REPO/.claude/commands/dp-pr.md")" "Review comments" "dp-pr handles review comments"
assert_contains "$(cat "$REPO/.claude/commands/dp-pr.md")" "max 3 cycles" "dp-pr keeps the bounded CI loop"

echo "== shipped templates match the current flow =="
STALE=$(grep -rlE 'impact-maps|apps/api|npm run lint` passes|Tested with Arabic' "$REPO/.github/pull_request_template.md" "$REPO/.github/ISSUE_TEMPLATE" 2>/dev/null | tr '\n' ' ')
assert_eq "${STALE:-none}" "none" "no stale steps (impact maps, apps/api, generic npm checks)"
assert_contains "$(cat "$REPO/.github/pull_request_template.md")" "run-tests.sh all" "PR template uses the token-lean test runner"

echo "== audit fixes: agents, checkpoints, permissions, toolchain detection =="
for A in "$REPO"/.claude/agents/*.md; do
  n=$(basename "$A" .md)
  assert_eq "$(sed -n '2,6p' "$A" | sed -n 's/^name: //p')" "$n" "agent $n has the required name: field"
done
STALE_AG=$(grep -l 'team-task\|/team-ba\|/team-lead' "$REPO"/.claude/agents/*.md 2>/dev/null | tr '\n' ' ')
assert_eq "${STALE_AG:-none}" "none" "agent descriptions name real commands only"
for C in "$REPO"/.claude/commands/*.md "$REPO"/.claude/skills/*/SKILL.md; do
  for SUB in $(grep -oE 'checkpoint\.sh [a-z-]+' "$C" | awk '{print $2}' | sort -u); do
    case "$SUB" in write|read|update|add-commit|show|latest) ok "$(basename "$C"): checkpoint.sh $SUB exists" ;;
      *) no "$(basename "$C"): checkpoint.sh $SUB does not exist" ;; esac
  done
done
SET="$(cat "$REPO/.claude/settings.json")"
assert_contains "$SET" '"Bash(bash scripts/tracker.sh *)"' "routine DevPilot scripts run without prompts"
assert_contains "$SET" '"Bash(bash scripts/deploy.sh *)"' "deploy is listed"
assert_eq "$(jq -r '.permissions.allow | map(select(test("deploy\\.sh|rollback\\.sh|update-org\\.sh|--force"))) | length' "$REPO/.claude/settings.json")" "0" "deploy / rollback / org update / force-push are never auto-allowed"
assert_eq "$(jq -r '.permissions.ask | map(select(test("deploy\\.sh"))) | length' "$REPO/.claude/settings.json")" "2" "deploy always asks (incl. CONFIRM=1)"
MISSING=""
for f in "$REPO"/scripts/*.sh; do
  n=$(basename "$f")
  jq -e --arg r "Bash(bash scripts/$n *)" '(.permissions.allow + .permissions.ask) | index($r)' "$REPO/.claude/settings.json" >/dev/null || MISSING="$MISSING $n"
done
assert_eq "${MISSING:-none}" "none" "every script has an allow or ask rule"
D=$(sandbox); ( cd "$D" && mkdir -p web api && printf '{}' > web/angular.json && printf '{\n  "engines": { "node": ">=20.11" }\n}\n' > web/package.json \
  && printf '<Project Sdk="Microsoft.NET.Sdk.Web"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="8.0.11" /></ItemGroup></Project>' > api/Api.csproj \
  && mkdir -p api/Migrations && bash scripts/generate-ci.sh >/dev/null 2>&1 )
CI="$(cat "$D/.github/workflows/devpilot-ci.yml" "$D/.github/workflows/devpilot-cd.yml" 2>/dev/null)"
assert_contains "$CI" "dotnet-version: 8.0.x" ".NET SDK taken from the project's TargetFramework"
assert_contains "$CI" "node-version: 20" "Node taken from package.json engines"
assert_contains "$CI" "dotnet-ef --version 8.0.11" "dotnet-ef matches the project's EF Core version"
( cd "$D" && printf '{ "sdk": { "version": "9.0.300" } }' > global.json && bash scripts/generate-ci.sh --force >/dev/null 2>&1 )
assert_contains "$(cat "$D/.github/workflows/devpilot-ci.yml")" "dotnet-version: 9.0.x" "global.json wins for the .NET SDK"
rm -rf "$D"
OUT=$(printf '{"tool_input":{"file_path":"api/Migrations/20260101_Init.cs"}}' | ( D=$(mktemp -d); cd "$D" && git init -q && mkdir .devpilot && echo backend > .devpilot/.scope-lock && bash "$REPO/scripts/scope-hook.sh"; echo "rc=$?" ))
assert_contains "$OUT" "rc=0" "backend layer lock lets the .NET agent write EF migrations"

echo "== lean repo: nothing shipped that nothing uses =="
ARCHIVES=$(git -C "$REPO" ls-files | grep -E '\.(tar\.gz|tgz|zip|whl|exe|dll)$' | tr '\n' ' ')
assert_eq "${ARCHIVES:-none}" "none" "no archives or binaries committed"
UNUSED=""
for f in "$REPO"/scripts/*.sh "$REPO"/.claude/skills/*/ "$REPO"/.devpilot/prompts/*.md "$REPO"/.devpilot/templates/*.md; do
  n=$(basename "$f"); SELF="/$n\$"
  case "$f" in */skills/*/) n="\`$(basename "$f")\`"; SELF="/skills/$(basename "$f")/SKILL.md\$" ;; esac
  c=$(grep -rlF "$n" "$REPO/.claude/commands" "$REPO/.claude/agents" "$REPO/.claude/skills" "$REPO/.devpilot" "$REPO/scripts" "$REPO/CLAUDE.md" "$REPO/README.md" "$REPO/docs" 2>/dev/null \
      | grep -v -e "$SELF" -e '/skills/README.md$' | head -1)
  # A hook command in settings.json or a run from install.sh also counts (permission rules don't).
  [ -n "$c" ] || c=$( { jq -r '.. | .command? // empty' "$REPO/.claude/settings.json"; grep -v '^ *#' "$REPO/install.sh"; } | grep -F "bash scripts/$n" | head -1)
  [ -n "$c" ] || UNUSED="$UNUSED $n"
done
assert_eq "${UNUSED:-none}" "none" "every script, skill, prompt and template is used by a command, agent, skill or script"

echo "== installer prints no shell errors (macOS bash 3.2 regressions) =="
D=$(mktemp -d)
( cd "$D" && git init -q -b develop && git remote add origin https://dev.azure.com/acme/Shop/_git/web \
  && git commit -q --allow-empty -m init && echo '{"dependencies":{"@angular/core":"^21.0.0"}}' > package.json \
  && DEVPILOT_LOCAL="$REPO" bash "$REPO/install.sh" --defaults >"$D/out.log" 2>"$D/err.log" < /dev/null )
ERRS=$(grep -E 'syntax error|No such file or directory|command not found|unexpected token' "$D/out.log" "$D/err.log" | head -3)
assert_eq "${ERRS:-none}" "none" "installer runs without shell errors"
assert_contains "$(cat "$D/project.config.md")" '`/dp-deliver resume`' "config comment keeps its backticked command"
assert_contains "$(cat "$D/out.log")" "Azure Repos" "summary shows the git host"
NOCASE=$(grep -nE '\$\(case ' "$REPO/install.sh" "$REPO"/scripts/*.sh | head -3)
assert_eq "${NOCASE:-none}" "none" "no case inside \$(…) (bash 3.2 can't parse it)"
rm -rf "$D"

echo "== DevPilot release metadata =="
V=$(cat "$REPO/VERSION")
assert_contains "$(cat "$REPO/CHANGELOG.md")" "## [$V]" "CHANGELOG.md has a section for VERSION $V (release notes)"
assert_contains "$(cat "$REPO/README.md")" "version-$V-blue" "README badge shows VERSION $V"
[ -f "$REPO/LICENSE" ] && ok "LICENSE file present" || no "LICENSE file present"

echo ""
echo "── Results: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
