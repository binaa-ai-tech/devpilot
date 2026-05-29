#!/usr/bin/env bash
# =============================================================================
# install-git-hooks.sh — install a commit-msg hook that enforces Conventional
# Commits (the convention every devpilot agent already follows).
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
# devpilot commit-msg hook — enforce Conventional Commits.
set -uo pipefail
MSG_FILE="$1"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Prefer commitlint if available in the project.
if [ -f "$ROOT/.commitlintrc.json" ] && command -v npx >/dev/null 2>&1 && [ -d "$ROOT/node_modules/@commitlint" ]; then
  npx --no-install commitlint --edit "$MSG_FILE" && exit 0 || exit 1
fi

# Fallback: regex check on the first line.
HEADER=$(head -1 "$MSG_FILE")
# allow merge/revert commits through
case "$HEADER" in Merge*|Revert*|"fixup!"*) exit 0 ;; esac
if echo "$HEADER" | grep -Eq '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|sec|revert)(\([a-z0-9._-]+\))?!?: .+'; then
  exit 0
fi
echo "✗ Commit message must follow Conventional Commits:" >&2
echo "    <type>(<scope>): <description>" >&2
echo "  types: feat fix docs style refactor perf test build ci chore sec revert" >&2
echo "  got: $HEADER" >&2
exit 1
EOF

chmod +x "$HOOK"
echo "✅ Installed commit-msg hook → .git/hooks/commit-msg (Conventional Commits enforced)"
