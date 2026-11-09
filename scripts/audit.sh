#!/usr/bin/env bash
# =============================================================================
# audit.sh — dependency vulnerability scan (stack-aware).
#
# Runs the right vuln scanner for the project's stack and reports findings.
# Advisory by default; STRICT=1 makes it exit non-zero when high/critical
# vulnerabilities are found (use it as a merge gate in QA / review).
#
#   bash scripts/audit.sh
#   STRICT=1 bash scripts/audit.sh
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" 2>/dev/null || exit 0
FOUND=0
RAN=0

run() { echo "  → $*"; "$@"; }

echo "── dependency audit ──────────────────────────────────"

# Node / JS / TS
if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  RAN=1; echo "[npm]"
  if npm audit --audit-level=high >/tmp/devpilot-audit-$$.log 2>&1; then
    echo "  ✅ npm audit: no high/critical"
  else
    echo "  ⚠️  npm audit reported high/critical vulnerabilities"; tail -20 /tmp/devpilot-audit-$$.log; FOUND=1
  fi
  rm -f /tmp/devpilot-audit-$$.log
fi

# .NET
if find . -maxdepth 4 -name '*.csproj' ! -path '*/obj/*' ! -path '*/bin/*' 2>/dev/null | grep -q . && command -v dotnet >/dev/null 2>&1; then
  RAN=1; echo "[dotnet]"
  OUT=$(dotnet list package --vulnerable --include-transitive 2>/dev/null)
  echo "$OUT" | grep -qi 'has the following vulnerable' && { echo "  ⚠️  vulnerable NuGet packages:"; echo "$OUT" | grep -i '>' | head -20; FOUND=1; } || echo "  ✅ no vulnerable NuGet packages"
fi

# Python
if { [ -f requirements.txt ] || [ -f pyproject.toml ]; }; then
  if command -v pip-audit >/dev/null 2>&1; then
    RAN=1; echo "[pip-audit]"
    pip-audit -q >/tmp/devpilot-audit-$$.log 2>&1 && echo "  ✅ pip-audit: clean" || { echo "  ⚠️  pip-audit found issues"; tail -20 /tmp/devpilot-audit-$$.log; FOUND=1; }
    rm -f /tmp/devpilot-audit-$$.log
  else
    echo "[python] pip-audit not installed — skipping (pip install pip-audit)"
  fi
fi

# Go
if [ -f go.mod ]; then
  if command -v govulncheck >/dev/null 2>&1; then
    RAN=1; echo "[govulncheck]"
    govulncheck ./... >/tmp/devpilot-audit-$$.log 2>&1 && echo "  ✅ govulncheck: clean" || { echo "  ⚠️  govulncheck found issues"; tail -20 /tmp/devpilot-audit-$$.log; FOUND=1; }
    rm -f /tmp/devpilot-audit-$$.log
  else
    echo "[go] govulncheck not installed — skipping (go install golang.org/x/vuln/cmd/govulncheck@latest)"
  fi
fi

echo "──────────────────────────────────────────────────────"
[ "$RAN" = 0 ] && { echo "No supported manifest found — nothing to audit."; exit 0; }
if [ "$FOUND" = 0 ]; then echo "✅ no high/critical vulnerabilities"; exit 0; fi
echo "⚠️  vulnerabilities found."
[ "${STRICT:-0}" = "1" ] && exit 1
exit 0
