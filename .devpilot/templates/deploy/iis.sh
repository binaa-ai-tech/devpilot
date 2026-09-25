#!/usr/bin/env bash
# deploy/deploy.sh — IIS on Windows Server over SSH (OpenSSH), from scripts/deploy-init.sh.
# Runs from the Linux pipeline agent: copy the artifact, stop the app pool, mirror the
# files (robocopy /MIR), start the pool. Called: deploy/deploy.sh <env> <artifact-dir> <version>
#
# need:     IIS_SERVER, IIS_USER, IIS_SSH_KEY (private key text), IIS_API_PATH, IIS_API_POOL
# optional: IIS_WEB_PATH (Angular site folder) · IIS_WEB_POOL
#           SQL_SERVER, SQL_DATABASE, SQL_USER, SQL_PASSWORD | SQL_AUTH=aad (migrations)
# Server prerequisites: OpenSSH Server with PowerShell as the default shell, WebAdministration.
set -euo pipefail
ENVN="$1"; ART="$2"; VERSION="$3"
# shellcheck source=/dev/null
. "$(dirname "$0")/db.sh"
need IIS_SERVER IIS_USER IIS_SSH_KEY IIS_API_PATH IIS_API_POOL
KEY=$(mktemp); trap 'rm -f "$KEY"' EXIT
printf '%s\n' "$(val IIS_SSH_KEY)" > "$KEY"; chmod 600 "$KEY"
T="$(val IIS_USER)@$(val IIS_SERVER)"
SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes)
STAGE="C:/devpilot-releases/$VERSION"

echo "▶ $ENVN · v$VERSION → IIS $(val IIS_SERVER)"
apply_migrations "$ART"

"${SSH[@]}" "$T" "New-Item -ItemType Directory -Force -Path '$STAGE' | Out-Null"
scp -i "$KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes -rq "$ART/api" "$T:$STAGE/api"

mirror() {  # mirror <source> <site path> <app pool> — robocopy exit < 8 is success
  "${SSH[@]}" "$T" "Import-Module WebAdministration; Stop-WebAppPool -Name '$3' -ErrorAction SilentlyContinue; Start-Sleep 3;
    robocopy '$1' '$2' /MIR /NFL /NDL /NJH /NJS /XD logs /XF appsettings.*.local.json; \$rc = \$LASTEXITCODE;
    Start-WebAppPool -Name '$3'; if (\$rc -ge 8) { exit \$rc } else { exit 0 }"
}
mirror "$STAGE/api" "$(val IIS_API_PATH)" "$(val IIS_API_POOL)"
echo "  ✅ API → $(val IIS_API_PATH)"

if [ -n "$(val IIS_WEB_PATH)" ] && [ -d "$ART/web" ]; then
  WEBROOT=$(dirname "$(find "$ART/web" -name index.html | head -1)")
  scp -i "$KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes -rq "$WEBROOT" "$T:$STAGE/web"
  mirror "$STAGE/web" "$(val IIS_WEB_PATH)" "$(val IIS_WEB_POOL)"
  echo "  ✅ web → $(val IIS_WEB_PATH)"
fi
