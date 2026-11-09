#!/usr/bin/env bash
# =============================================================================
# tests/e2e.sh — DevPilot end to end on a sample Angular + .NET repo, no AI needed.
#
# Installs DevPilot into a fresh sample project (bare "origin" remote), then walks the
# deterministic path of /dp-deliver and /dp-release exactly as the commands script it:
#   tracker check → skip → plan (Epic → Story → layer tasks) → sprint → feature branch
#   → version bump from develop → changelog entry → PR on (mocked) Azure Repos with
#   auto-complete → merge → close items/Epic/sprint → back on develop → a second,
#   parallel delivery caught by `version.sh verify` → release branch → CHANGELOG.
# Also generates CI + CD and lints them (YAML; actionlint when installed).
#
#   bash tests/e2e.sh            exit non-zero on the first broken step
# =============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
no() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (got '$2', want '$3')"; fi; }
has() { if [[ "$2" == *"$3"* ]]; then ok "$1"; else no "$1 (missing '$3')"; fi; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
MOCK="$W/bin"; mkdir -p "$MOCK"; cp "$REPO/tests/mock-curl.sh" "$MOCK/curl"; chmod +x "$MOCK/curl"
export MOCK_LOG="$W/mock.log"
git init -q --bare "$W/origin.git"
git clone -q "$W/origin.git" "$W/app" 2>/dev/null
cd "$W/app" || exit 1
git config user.email e2e@devpilot.test; git config user.name "DevPilot e2e"

echo "== 1. sample Angular + .NET project =="
git checkout -q -b develop
mkdir -p web/src/app api/Controllers api/Migrations tests/Api.Tests
printf '{\n  "projects": { "web": {} }\n}\n' > web/angular.json
printf '{\n  "name": "web",\n  "version": "1.4.0",\n  "scripts": { "build": "ng build" }\n}\n' > web/package.json
printf '<Project Sdk="Microsoft.NET.Sdk.Web">\n  <PropertyGroup>\n    <Version>1.4.0</Version>\n  </PropertyGroup>\n</Project>\n' > api/Api.csproj
printf '<Project Sdk="Microsoft.NET.Sdk"/>\n' > tests/Api.Tests/Api.Tests.csproj
printf 'namespace Api.Controllers;\npublic class OrdersController {}\n' > api/Controllers/OrdersController.cs
touch Shop.sln
git add -A && git commit -qm "chore: sample app" && git push -q origin develop 2>/dev/null
ok "sample repo on develop, version 1.4.0"

echo "== 2. install (--defaults) =="
bash "$REPO/install.sh" --defaults > "$W/install.log" 2>&1
check "installer exits 0" "$?" "0"
sed -i.bak 's/^git_host: auto/git_host: azure/' project.config.md && rm -f project.config.md.bak
printf "AZDO_ORG_URL=https://dev.azure.com/acme\nAZDO_PROJECT=Shop\nAZDO_REPO=app\nAZDO_PAT='e2e'\n" >> .devpilot/config.sh
has "config.sh with secrets is gitignored" "$(git check-ignore .devpilot/config.sh)" ".devpilot/config.sh"
git add -A && git commit -qm "chore: install devpilot" && git push -q origin develop 2>/dev/null
ok "install committed"
export PATH="$MOCK:$PATH"

echo "== 3. /dp-deliver: tracker preflight =="
bash scripts/tracker.sh check >/dev/null; check "no tracker yet → asks once (rc 3)" "$?" "3"
bash scripts/tracker.sh skip 2>/dev/null
bash scripts/tracker.sh check >/dev/null; check "continue without a tracker → ready" "$?" "0"

echo "== 4. PLAN: dedup → Epic → Story → layer tasks =="
check "nothing similar in the backlog yet" "$(bash scripts/tracker.sh search 'export orders csv' | wc -l | tr -d ' ')" "0"
EPIC=$(bash scripts/tracker.sh new Epic "Order exports" "Customers take their data out" 2>/dev/null)
KEY=$(bash scripts/tracker.sh new Story "Export orders as CSV" "## AC\n- a CSV download" "$EPIC" 2>/dev/null)
TASKS=$(bash scripts/tracker.sh breakdown "$KEY" backend,frontend,qa "Export orders as CSV" 2>/dev/null | tr '\n' ' ')
check "Epic → Story keys" "$EPIC $KEY" "LOCAL-1 LOCAL-2"
check "one task per layer" "$(echo "$TASKS" | wc -w | tr -d ' ')" "3"
bash scripts/tracker.sh assert-key "$KEY" 2>/dev/null; check "tracker-first gate passes" "$?" "0"
has "a second request finds the existing Story" "$(bash scripts/tracker.sh search 'CSV export of orders')" "$KEY"

echo "== 5. SPRINT + BUILD branch =="
SPRINT=$(bash scripts/tracker.sh sprint create "deliver-csv-export" 2>/dev/null)
bash scripts/tracker.sh sprint assign "$SPRINT" "$KEY" 2>/dev/null
bash scripts/git-flow.sh feature-start "$KEY" csv-export >/dev/null 2>&1
BR=$(git branch --show-current); check "branch named from the key" "$BR" "feature/local-2-csv-export"
bash scripts/tracker.sh status "$KEY" "In Progress" 2>/dev/null
printf 'public class OrdersCsv {}\n' > api/Controllers/OrdersCsv.cs
git add -A && git commit -qm "feat(orders): CSV export ($KEY)"

echo "== 6. VERSION + CHANGELOG + PR =="
git fetch -q origin develop
V=$(bash scripts/version.sh bump "$(bash scripts/version.sh level feature)" --ref origin/develop 2>/dev/null)
check "feature bumps minor from develop" "$V" "1.5.0"
has ".NET version bumped" "$(cat api/Api.csproj)" "<Version>1.5.0</Version>"
has "Angular version bumped" "$(cat web/package.json)" '"version": "1.5.0"'
bash scripts/changelog.sh add "$KEY" feat "Export orders as CSV" >/dev/null
OUT=$(bash scripts/close-delivery.sh --prepare --version "$V" --sprint "$SPRINT" "$KEY" 2>/dev/null)
has "local tracker: items closed inside the PR" "$OUT" "Prepared"
bash scripts/version.sh files | xargs git add; git add docs/
git commit -qm "chore(release): bump version to $V"
bash scripts/version.sh verify --ref origin/develop >/dev/null; check "version is ahead of develop" "$?" "0"
TITLE="[v$V] Export orders as CSV ($(bash scripts/tracker.sh ref "$KEY"))"
PR=$(bash scripts/open-pr.sh develop "$TITLE" "QA: PASS" --items "$KEY" 2>/dev/null); RC=$?
check "PR opened + auto-completed on Azure Repos" "$RC" "0"
has "PR URL" "$PR" "/_git/app/pullrequest/77"
has "PR squashes and deletes the branch" "$(cat "$MOCK_LOG")" '"mergeStrategy":"squash"'

echo "== 7. merge → CLOSE =="
git checkout -q develop && git merge -q --squash "$BR" && git commit -qm "feat: $TITLE" && git push -q origin develop 2>/dev/null
git checkout -q "$BR"
OUT=$(bash scripts/close-delivery.sh --pr "$PR" --version "$V" --sprint "$SPRINT" "$KEY" 2>/dev/null)
has "local items were closed by the merged PR" "$OUT" "closed inside the merged PR"
has "sprint closed on develop" "$(cat "docs/sprints/$SPRINT.md")" "State: closed"
check "back on develop" "$(git branch --show-current)" "develop"
check "develop working tree is clean (next delivery can start)" "$(git status --porcelain | grep -v '^??' | wc -l | tr -d ' ')" "0"
check "develop carries the new version" "$(bash scripts/version.sh current)" "1.5.0"
DONE=$(bash scripts/tracker.sh list | awk -F'\t' '$4 == "done"' | wc -l | tr -d ' ')
check "Epic, Story and its 3 tasks are Done" "$DONE" "5"

echo "== 8. parallel delivery guard =="
git checkout -q -b feature/local-9-stale "HEAD~1"          # cut from develop before the merge
bash scripts/version.sh bump minor --ref HEAD >/dev/null 2>&1
bash scripts/version.sh verify --ref develop >/dev/null 2>&1
check "a second PR claiming 1.5.0 is rejected" "$?" "1"
git checkout -q -- . && git checkout -q develop
check "back on develop" "$(git branch --show-current)" "develop"

echo "== 9. RELEASE branch + CHANGELOG =="
bash scripts/git-flow.sh release-start >/dev/null 2>&1
check "release branch from develop's version" "$(git branch --show-current)" "release/1.5.0"
bash scripts/changelog.sh 1.5.0 >/dev/null
has "CHANGELOG section from the entries" "$(cat CHANGELOG.md)" "Export orders as CSV (LOCAL-2)"
check "release keys for the notes" "$(bash scripts/changelog.sh keys 1.5.0)" "LOCAL-2"

echo "== 10. pipelines =="
bash scripts/generate-ci.sh --force --github >/dev/null 2>&1
bash scripts/generate-ci.sh --force --azure >/dev/null 2>&1
for F in .github/workflows/devpilot-ci.yml .github/workflows/devpilot-cd.yml azure-pipelines.yml azure-pipelines-cd.yml; do
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$F" 2>/dev/null; then ok "$F is valid YAML"
  elif ! python3 -c "import yaml" 2>/dev/null; then ok "$F written (PyYAML not installed — not parsed)"
  else no "$F is valid YAML"; fi
done
if command -v actionlint >/dev/null 2>&1; then
  actionlint .github/workflows/devpilot-ci.yml .github/workflows/devpilot-cd.yml && ok "actionlint: GitHub workflows clean" || no "actionlint"
fi
OUT=$(bash scripts/doctor.sh 2>&1); has "doctor sees the CD pipeline" "$OUT" "CD pipeline present"

echo ""
echo "── e2e: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
