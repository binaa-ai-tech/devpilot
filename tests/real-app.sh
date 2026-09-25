#!/usr/bin/env bash
# =============================================================================
# tests/real-app.sh — build a REAL Angular + ASP.NET Core + EF Core app with the
# pipelines DevPilot generates. Proves generate-ci.sh / db-package.sh / run-tests.sh
# work on real toolchains, not placeholders. Needs: dotnet 10 SDK, Node 22, network.
#
#   bash tests/real-app.sh            (CI: .github/workflows/real-app.yml, weekly)
#   REAL_APP_DIR=/tmp/x bash tests/real-app.sh     keep the app for inspection
#   NG_VERSION=22 bash tests/real-app.sh          Angular major to scaffold (default 21)
#
# 1. scaffold: solution · webapi · xunit tests · EF Core DbContext + Init migration ·
#    Angular app (ng new) — version 1.0.0 in both
# 2. install DevPilot (--defaults) and generate CI + CD
# 3. run the CD "build once" step exactly as generated → out/api, out/web, out/db
# 4. run the test suites through scripts/run-tests.sh
# =============================================================================
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
W="${REAL_APP_DIR:-$(mktemp -d)}"; mkdir -p "$W"
PASS=0; FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
no() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
step() { echo ""; echo "== $* =="; }

for t in dotnet node npx git python3; do command -v "$t" >/dev/null || { echo "❌ $t is required"; exit 1; }; done
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 NG_CLI_ANALYTICS=false CI=true
export PATH="$PATH:$HOME/.dotnet/tools"

rm -rf "$W/app"; mkdir -p "$W/app"; cd "$W/app"
git init -q -b develop; git config user.email e2e@devpilot.test; git config user.name "DevPilot real-app"

step "1. scaffold .NET (webapi + xunit + EF Core)"
dotnet new sln -n Shop -o . >/dev/null
dotnet new webapi -n Shop.Api -o api >/dev/null
dotnet new xunit -n Shop.Api.Tests -o tests/Shop.Api.Tests >/dev/null
SLN=$(ls Shop.sln* | head -1)
dotnet sln "$SLN" add api/Shop.Api.csproj tests/Shop.Api.Tests/Shop.Api.Tests.csproj >/dev/null
dotnet add tests/Shop.Api.Tests reference api/Shop.Api.csproj >/dev/null
dotnet add api package Microsoft.EntityFrameworkCore.SqlServer >/dev/null
dotnet add api package Microsoft.EntityFrameworkCore.Design >/dev/null
cat > api/ShopDbContext.cs <<'CS'
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Shop.Api;

public class Order
{
    public int Id { get; set; }
    public string Number { get; set; } = "";
}

public class ShopDbContext(DbContextOptions<ShopDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
}

public class ShopDbContextFactory : IDesignTimeDbContextFactory<ShopDbContext>
{
    public ShopDbContext CreateDbContext(string[] args) =>
        new(new DbContextOptionsBuilder<ShopDbContext>()
            .UseSqlServer("Server=localhost;Database=Shop;Trusted_Connection=True;TrustServerCertificate=True")
            .Options);
}
CS
sed -i.bak '0,/<PropertyGroup>/s//<PropertyGroup>\n    <Version>1.0.0<\/Version>/' api/Shop.Api.csproj && rm -f api/Shop.Api.csproj.bak
dotnet tool update --global dotnet-ef >/dev/null
dotnet ef migrations add Init --project api/Shop.Api.csproj >/dev/null
[ -n "$(ls api/Migrations/*_Init.cs 2>/dev/null)" ] && ok "EF Core Init migration" || no "EF Core Init migration"

step "1b. scaffold Angular"
# --skip-install + a separate npm install: npm inside `npx … ng new` can hit an arborist bug.
npx -y "@angular/cli@${NG_VERSION:-21}" new web --defaults --skip-git --skip-install --ssr=false --package-manager npm >/dev/null 2>&1
# npm 10.9 can crash resolving an optional peer (jsdom → canvas); projects hitting it commit
# legacy-peer-deps in .npmrc so `npm ci` in CI resolves the same tree.
(cd web && { npm install --no-audit --no-fund --loglevel=error >/dev/null 2>&1 \
  || { echo "legacy-peer-deps=true" > .npmrc && npm install --no-audit --no-fund --loglevel=error >/dev/null; }; })
sed -i.bak '0,/"version": "[^"]*"/s//"version": "1.0.0"/' web/package.json && rm -f web/package.json.bak
[ -f web/angular.json ] && ok "Angular workspace ($(cd web && npx ng version 2>/dev/null | grep -m1 -oE 'Angular( CLI)?: [0-9.]+' || echo ng))" || no "Angular workspace"

git add -A && git commit -qm "chore: sample app"

step "2. install DevPilot + generate pipelines"
bash "$REPO/install.sh" --defaults > "$W/install.log" 2>&1 && ok "install --defaults" || no "install --defaults (see $W/install.log)"
[ "$(bash scripts/version.sh current)" = "1.0.0" ] && ok "version 1.0.0 read from the real projects" || no "version detection"
bash scripts/generate-ci.sh --force --github >/dev/null
bash scripts/generate-ci.sh --force --azure >/dev/null
git add -A && git commit -qm "chore: devpilot" --no-verify

step "3. CD build-once step, exactly as generated"
python3 - .github/workflows/devpilot-cd.yml > "$W/build.sh" <<'PY'
import sys, yaml
jobs = yaml.safe_load(open(sys.argv[1]))["jobs"]
print(next(s["run"] for s in jobs["build"]["steps"] if s.get("name", "").startswith("build once")))
PY
if bash "$W/build.sh" > "$W/build.log" 2>&1; then ok "build step ran (npm ci · ng build · dotnet publish · db-package)"; else no "build step (tail: $(tail -5 "$W/build.log" | tr '\n' ' '))"; fi
[ -f out/api/Shop.Api.dll ] && ok "out/api — dotnet publish output" || no "out/api/Shop.Api.dll"
[ -n "$(find out/web -name index.html 2>/dev/null | head -1)" ] && ok "out/web — Angular production build" || no "out/web index.html"
grep -qi "CREATE TABLE" out/db/migrations.sql 2>/dev/null && ok "out/db/migrations.sql — idempotent script with the schema" || no "out/db/migrations.sql"
grep -q "_Init" out/db/migrations.txt 2>/dev/null && ok "out/db/migrations.txt lists Init" || no "out/db/migrations.txt"
[ -s out/db/rollback.sql ] && ok "out/db/rollback.sql generated" || no "out/db/rollback.sql"
[ "$(cat out/VERSION 2>/dev/null)" = "1.0.0" ] && ok "artifact stamped v1.0.0" || no "out/VERSION"
grep -q "1.0.0" out/api/Shop.Api.dll 2>/dev/null || strings out/api/Shop.Api.dll 2>/dev/null | grep -q "1\.0\.0" && ok "assembly carries the version" || echo "  ℹ️  assembly version not checked"

step "4. test suites through run-tests.sh"
if bash scripts/run-tests.sh dotnet; then ok "run-tests.sh dotnet"; else no "run-tests.sh dotnet"; fi
if [ "${RUN_ANGULAR_TESTS:-1}" = 1 ]; then
  if bash scripts/run-tests.sh angular; then ok "run-tests.sh angular"; else no "run-tests.sh angular"; fi
fi
if command -v actionlint >/dev/null 2>&1; then
  actionlint .github/workflows/devpilot-ci.yml .github/workflows/devpilot-cd.yml && ok "actionlint" || no "actionlint"
fi

echo ""
echo "── real-app: $PASS passed, $FAIL failed ── (app: $W/app)"
[ "$FAIL" -eq 0 ]
