#!/usr/bin/env bash
# deploy/deploy.sh — Kubernetes (AKS or any cluster), from scripts/deploy-init.sh.
# Builds container images ONCE per version (later environments reuse the pushed image),
# rolls the deployments, waits for the rollout, and undoes it on failure.
# Called: deploy/deploy.sh <env> <artifact-dir> <version>
#
# need:     REGISTRY (e.g. myacr.azurecr.io/shop), KUBE_NAMESPACE
# optional: KUBE_CONFIG (base64 kubeconfig; else the agent's current context)
#           REGISTRY_USER + REGISTRY_PASSWORD · API_DEPLOYMENT=api · WEB_DEPLOYMENT=web
#           API_CONTAINER=api · WEB_CONTAINER=web
#           SQL_SERVER, SQL_DATABASE, SQL_USER, SQL_PASSWORD | SQL_AUTH=aad (migrations)
set -euo pipefail
ENVN="$1"; ART="$2"; VERSION="$3"
# shellcheck source=/dev/null
. "$(dirname "$0")/db.sh"
need REGISTRY KUBE_NAMESPACE
REG="$(val REGISTRY)"; NS="$(val KUBE_NAMESPACE)"
API_DEP="$(val API_DEPLOYMENT)"; API_DEP="${API_DEP:-api}"; API_C="$(val API_CONTAINER)"; API_C="${API_C:-api}"
WEB_DEP="$(val WEB_DEPLOYMENT)"; WEB_DEP="${WEB_DEP:-web}"; WEB_C="$(val WEB_CONTAINER)"; WEB_C="${WEB_C:-web}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
if [ -n "$(val KUBE_CONFIG)" ]; then printf '%s' "$(val KUBE_CONFIG)" | base64 -d > "$TMP/kubeconfig"; export KUBECONFIG="$TMP/kubeconfig"; fi
if [ -n "$(val REGISTRY_USER)" ]; then
  printf '%s' "$(val REGISTRY_PASSWORD)" | docker login "${REG%%/*}" -u "$(val REGISTRY_USER)" --password-stdin >/dev/null
fi

echo "▶ $ENVN · v$VERSION → Kubernetes namespace $NS"
apply_migrations "$ART"

image() {  # image <name> <context-dir> <dockerfile-text> → pushes $REG/<name>:$VERSION once
  local img="$REG/$1:$VERSION"
  if docker manifest inspect "$img" >/dev/null 2>&1; then echo "  ♻️  $img exists — promoting the same image"; return 0; fi
  printf '%s\n' "$3" > "$2/Dockerfile.devpilot"
  docker build -q -f "$2/Dockerfile.devpilot" -t "$img" "$2" >/dev/null
  docker push -q "$img" >/dev/null
  echo "  ✅ built + pushed $img"
}
roll() {  # roll <deployment> <container> <image>
  kubectl -n "$NS" set image "deployment/$1" "$2=$3"
  if ! kubectl -n "$NS" rollout status "deployment/$1" --timeout=300s; then
    kubectl -n "$NS" rollout undo "deployment/$1"; echo "❌ $1 rollout failed — undone" >&2; exit 1
  fi
}

DLL=$(basename "$(find "$ART/api" -maxdepth 1 -name '*.runtimeconfig.json' | head -1)" .runtimeconfig.json)
[ -n "$DLL" ] || { echo "❌ no *.runtimeconfig.json in $ART/api — not a dotnet publish output" >&2; exit 1; }
image api "$ART/api" "FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY . .
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER app
ENTRYPOINT [\"dotnet\", \"$DLL.dll\"]"
roll "$API_DEP" "$API_C" "$REG/api:$VERSION"

if [ -d "$ART/web" ] && kubectl -n "$NS" get "deployment/$WEB_DEP" >/dev/null 2>&1; then
  WEBROOT=$(dirname "$(find "$ART/web" -name index.html | head -1)")
  printf 'server { listen 8080; root /usr/share/nginx/html; location / { try_files $uri $uri/ /index.html; } }\n' > "$WEBROOT/default.conf"
  image web "$WEBROOT" "FROM nginxinc/nginx-unprivileged:alpine
COPY default.conf /etc/nginx/conf.d/default.conf
COPY . /usr/share/nginx/html"
  roll "$WEB_DEP" "$WEB_C" "$REG/web:$VERSION"
fi
echo "  ✅ v$VERSION rolled out in $NS"
