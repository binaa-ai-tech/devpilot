#!/usr/bin/env bash
# deploy/deploy.sh — Azure App Service (ASP.NET Core API + Angular), from scripts/deploy-init.sh.
# Called by scripts/deploy.sh:  deploy/deploy.sh <env> <artifact-dir> <version>
#
# need:     AZURE_RESOURCE_GROUP, API_APP
# optional: WEB_APP (Angular site) · SLOT (deploy to a slot, then swap → zero downtime)
#           AZURE_CLIENT_ID + AZURE_CLIENT_SECRET + AZURE_TENANT_ID [+ AZURE_SUBSCRIPTION_ID]
#             (service principal; omit when the agent is already `az login`-ed)
#           SQL_SERVER, SQL_DATABASE, SQL_USER, SQL_PASSWORD | SQL_AUTH=aad (migrations)
# Linux Web Apps serving Angular need a startup command once:
#   pm2 serve /home/site/wwwroot --no-daemon --spa
set -euo pipefail
ENVN="$1"; ART="$2"; VERSION="$3"
# shellcheck source=/dev/null
. "$(dirname "$0")/db.sh"
need AZURE_RESOURCE_GROUP API_APP
command -v az >/dev/null 2>&1 || { echo "❌ Azure CLI (az) not found on the agent" >&2; exit 1; }
RG="$(val AZURE_RESOURCE_GROUP)"; SLOT="$(val SLOT)"
SLOT_ARGS=(); [ -n "$SLOT" ] && SLOT_ARGS=(--slot "$SLOT")

if [ -n "$(val AZURE_CLIENT_ID)" ]; then
  need AZURE_CLIENT_SECRET AZURE_TENANT_ID
  az login --service-principal -u "$(val AZURE_CLIENT_ID)" -p "$(val AZURE_CLIENT_SECRET)" --tenant "$(val AZURE_TENANT_ID)" -o none
fi
if [ -n "$(val AZURE_SUBSCRIPTION_ID)" ]; then az account set --subscription "$(val AZURE_SUBSCRIPTION_ID)"; fi

echo "▶ $ENVN · v$VERSION → App Service ($RG)${SLOT:+ slot $SLOT}"
apply_migrations "$ART"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
( cd "$ART/api" && zip -qr "$TMP/api.zip" . )
az webapp deploy -g "$RG" -n "$(val API_APP)" --src-path "$TMP/api.zip" --type zip ${SLOT_ARGS[@]+"${SLOT_ARGS[@]}"} -o none
echo "  ✅ API → $(val API_APP)"

if [ -n "$(val WEB_APP)" ] && [ -d "$ART/web" ]; then
  WEBROOT=$(dirname "$(find "$ART/web" -name index.html | head -1)")
  ( cd "$WEBROOT" && zip -qr "$TMP/web.zip" . )
  az webapp deploy -g "$RG" -n "$(val WEB_APP)" --src-path "$TMP/web.zip" --type zip ${SLOT_ARGS[@]+"${SLOT_ARGS[@]}"} -o none
  echo "  ✅ web → $(val WEB_APP)"
fi

if [ -n "$SLOT" ]; then
  for APP in "$(val API_APP)" "$(val WEB_APP)"; do
    [ -z "$APP" ] && continue
    az webapp deployment slot swap -g "$RG" -n "$APP" --slot "$SLOT" --target-slot production -o none
    echo "  🔁 $APP: $SLOT → production"
  done
fi
