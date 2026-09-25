#!/usr/bin/env bash
# deploy/db.sh — apply the release's idempotent migration script (sourced by deploy/deploy.sh).
#   apply_migrations <artifact-dir>
# Uses $ART/db/migrations.sql from scripts/db-package.sh. Settings (per environment):
#   SQL_SERVER, SQL_DATABASE, and SQL_USER + SQL_PASSWORD (SQL auth) — or SQL_AUTH=aad for
#   Entra ID (go-sqlcmd, ActiveDirectoryDefault). No SQL_SERVER → skipped with a notice.

# val <NAME> — a setting, treating Azure Pipelines' literal "$(NAME)" (undefined) as empty
val() { local x="${!1:-}"; case "$x" in '$('*) x="" ;; esac; printf '%s' "$x"; }
need() { local v; for v in "$@"; do [ -n "$(val "$v")" ] || { echo "❌ $v is not set for this environment" >&2; exit 1; }; done; }

apply_migrations() {
  local sql="$1/db/migrations.sql"
  [ -f "$sql" ] || { echo "  ℹ️  no db/migrations.sql in the artifact — database unchanged"; return 0; }
  [ -n "$(val SQL_SERVER)" ] || { echo "  ⚠️  SQL_SERVER not set — migrations NOT applied (set it, or apply db/migrations.sql by hand)"; return 0; }
  need SQL_DATABASE
  command -v sqlcmd >/dev/null 2>&1 || { echo "❌ sqlcmd not found on the agent (install go-sqlcmd or mssql-tools)" >&2; exit 1; }
  if [ "$(val SQL_AUTH)" = "aad" ]; then
    sqlcmd -S "$(val SQL_SERVER)" -d "$(val SQL_DATABASE)" --authentication-method ActiveDirectoryDefault -i "$sql" -b
  else
    need SQL_USER SQL_PASSWORD
    SQLCMDPASSWORD="$(val SQL_PASSWORD)" sqlcmd -S "$(val SQL_SERVER)" -d "$(val SQL_DATABASE)" -U "$(val SQL_USER)" -i "$sql" -b
  fi
  echo "  ✅ migrations applied to $(val SQL_DATABASE)"
}
