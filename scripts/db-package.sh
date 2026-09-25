#!/usr/bin/env bash
# =============================================================================
# db-package.sh — the database part of a release, for DBAs and change boards.
#
#   bash scripts/db-package.sh <out-dir> [--project <migrations.csproj>] [--startup <api.csproj>]
#
# Writes (EF Core, needs the dotnet-ef tool):
#   migrations.sql   idempotent — safe to run on any environment, any number of times
#   rollback.sql     this release's schema → the previous release's (only when the release adds
#                    migrations; review it: a down-migration can drop data)
#   migrations.txt   the migrations this release adds, vs the previous v* tag
#   README.md        how to apply and roll back
# The previous release = the newest v* tag reachable from HEAD that isn't HEAD itself,
# so CI needs full history + tags (the generated pipelines fetch them).
# =============================================================================
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

OUTD="${1:?Usage: db-package.sh <out-dir> [--project <csproj>] [--startup <csproj>]}"; shift
PROJ=""; STARTUP=""
while [ $# -gt 0 ]; do case "$1" in --project) PROJ="${2:-}"; shift 2 ;; --startup) STARTUP="${2:-}"; shift 2 ;; *) shift ;; esac; done

if [ -n "$PROJ" ]; then MIG_DIR="$(dirname "$PROJ")/Migrations"
else MIG_DIR=$(find . -maxdepth 6 -type d -name Migrations -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | head -1 | sed 's#^\./##'); fi
[ -n "$MIG_DIR" ] && [ -d "$MIG_DIR" ] || { echo "ℹ️  no EF Core Migrations folder — no database package"; exit 0; }
command -v dotnet >/dev/null 2>&1 || { echo "❌ dotnet not found" >&2; exit 1; }

EF=(dotnet ef)
ARGS=(); [ -n "$PROJ" ] && ARGS+=(--project "$PROJ"); [ -n "$STARTUP" ] && ARGS+=(--startup-project "$STARTUP")

names_at() {  # migration names (timestamp_Name) at a ref — Designer/snapshot files excluded
  git ls-tree -r --name-only "$1" -- "$MIG_DIR" 2>/dev/null \
    | sed -nE 's#.*/([0-9]{14}_[^./]+)\.cs$#\1#p' | sort
}
HEAD_SHA=$(git rev-parse HEAD)
PREV_TAG=""
for T in $(git tag --merged HEAD -l 'v[0-9]*' --sort=-version:refname 2>/dev/null); do
  [ "$(git rev-list -n1 "$T")" != "$HEAD_SHA" ] && { PREV_TAG="$T"; break; }
done
CUR=$(names_at HEAD); PREV=""; [ -n "$PREV_TAG" ] && PREV=$(names_at "$PREV_TAG")
NEW=$(comm -13 <(printf '%s\n' "$PREV" | sed '/^$/d') <(printf '%s\n' "$CUR" | sed '/^$/d'))
CUR_LAST=$(printf '%s\n' "$CUR" | sed '/^$/d' | tail -1)
PREV_LAST=$(printf '%s\n' "$PREV" | sed '/^$/d' | tail -1)

mkdir -p "$OUTD"
"${EF[@]}" migrations script --idempotent ${ARGS[@]+"${ARGS[@]}"} --output "$OUTD/migrations.sql" \
  || { echo "❌ could not generate migrations.sql" >&2; exit 1; }

{
  echo "# Migrations in this release (since ${PREV_TAG:-the first release})"
  if [ -n "$NEW" ]; then printf '%s\n' "$NEW" | sed 's/^/- /'; else echo "- none — no schema change"; fi
} > "$OUTD/migrations.txt"

ROLLBACK="none"
if [ -n "$NEW" ] && [ -n "$CUR_LAST" ]; then
  "${EF[@]}" migrations script "$CUR_LAST" "${PREV_LAST:-0}" ${ARGS[@]+"${ARGS[@]}"} --output "$OUTD/rollback.sql" \
    || { echo "❌ could not generate rollback.sql" >&2; exit 1; }
  ROLLBACK="rollback.sql → ${PREV_LAST:-empty database}"
fi

cat > "$OUTD/README.md" <<EOF
# Database package — $(bash "$ROOT/scripts/version.sh" current 2>/dev/null || echo "this release")

| File | Use |
|------|-----|
| migrations.sql | Apply before (or with) the app deploy. Idempotent: already-applied migrations are skipped. |
| rollback.sql | ${ROLLBACK} — only with the app rollback; review first, a down-migration can drop data. |
| migrations.txt | What this release changes (vs ${PREV_TAG:-no previous release}). |

Apply: \`sqlcmd -S <server> -d <database> -i migrations.sql -b\` (or your deploy/deploy.sh does it).
EOF
echo "✅ database package → $OUTD ($(printf '%s\n' "$NEW" | sed '/^$/d' | wc -l | tr -d ' ') new migration(s) since ${PREV_TAG:-start}; rollback: $ROLLBACK)"
