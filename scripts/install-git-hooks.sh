#!/usr/bin/env bash
# =============================================================================
# install-git-hooks.sh — install a commit-msg hook that enforces Conventional
# Commits (the convention every devpilot agent already follows) and the verification
# stamp: a `Verified: verify | tests | code-review | none` trailer, checked by
# scripts/commit-gate.sh in the mode set by COMMIT_GATE (off | observe | enforce;
# default observe — log, never block).
#
# Uses commitlint if the project has it; otherwise a lightweight regex check.
# Idempotent — safe to re-run.
#
#   bash scripts/install-git-hooks.sh
# =============================================================================
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS="$ROOT/.git/hooks"
[ -d "$HOOKS" ] || { echo "Not a git repo (no .git/hooks) — skipping." >&2; exit 0; }

HOOK="$HOOKS/commit-msg"
cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
# devpilot commit-msg hook — Conventional Commits + the verification stamp.
set -uo pipefail
MSG_FILE="$1"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

conventional() {
  # Prefer commitlint if available in the project.
  if [ -f "$ROOT/.commitlintrc.json" ] && command -v npx >/dev/null 2>&1 && [ -d "$ROOT/node_modules/@commitlint" ]; then
    npx --no-install commitlint --edit "$MSG_FILE"; return $?
  fi
  # Fallback: regex check on the first line.
  local HEADER; HEADER=$(head -1 "$MSG_FILE")
  # allow merge/revert commits through
  case "$HEADER" in Merge*|Revert*|"fixup!"*) return 0 ;; esac
  if echo "$HEADER" | grep -Eq '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|sec|revert)(\([a-z0-9._-]+\))?!?: .+'; then
    return 0
  fi
  echo "✗ Commit message must follow Conventional Commits:" >&2
  echo "    <type>(<scope>): <description>" >&2
  echo "  types: feat fix docs style refactor perf test build ci chore sec revert" >&2
  echo "  got: $HEADER" >&2
  return 1
}

conventional || exit 1

# Verification stamp — `Verified: verify | tests | code-review | none` (scripts/commit-gate.sh).
if [ -f "$ROOT/scripts/commit-gate.sh" ]; then
  bash "$ROOT/scripts/commit-gate.sh" check "$MSG_FILE" || exit 1
fi
exit 0
EOF

chmod +x "$HOOK"
echo "✅ Installed commit-msg hook → .git/hooks/commit-msg (Conventional Commits enforced; Verified: trailer — gate $(bash "$ROOT/scripts/commit-gate.sh" mode 2>/dev/null || echo observe))"

# post-merge / post-checkout: refresh the project index in the background so it
# is always content-fresh and agents never broad-scan due to a stale index.
# The generator is hash-gated, so these are near-free when nothing changed.
for H in post-merge post-checkout; do
  cat > "$HOOKS/$H" <<'EOF'
#!/usr/bin/env bash
# devpilot hook — keep docs/project-index.md fresh (hash-gated, background).
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$ROOT/scripts/generate-project-index.sh" ] || exit 0
( cd "$ROOT" && bash scripts/generate-project-index.sh >/dev/null 2>&1 & ) || true
exit 0
EOF
  chmod +x "$HOOKS/$H"
done
echo "✅ Installed post-merge + post-checkout hooks → project index auto-refresh (hash-gated)"
