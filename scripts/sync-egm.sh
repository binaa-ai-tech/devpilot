#!/usr/bin/env bash
# =============================================================================
# sync-egm.sh — vendor Google's Elephant-Goldfish Model (EGM) into DevPilot
#
# Usage:
#   bash scripts/sync-egm.sh                 # latest main of google/elephant-goldfish-model
#   bash scripts/sync-egm.sh --ref <tag|sha> # a pinned upstream version
#   bash scripts/sync-egm.sh --from <dir>    # an existing local checkout (offline)
#
# What it does (idempotent — re-run it to pick up upstream fixes):
#   distributions/claude/{skills,agents,resources,LICENSE,README.md} + the docs the skills link → .devpilot/egm/
#   distributions/claude/.claude-plugin/agents/*.md (Claude adapters)    → .claude/agents/egm-*.md
# and rewrites plugin paths for a project install:
#   ${CLAUDE_PLUGIN_ROOT}  → .devpilot/egm        /egm:egm-<skill> → /dp-spec <skill>
#   egm:egm-<agent>        → egm-<agent>          ../../docs/      → ../../docs/ (unchanged layout)
# Then writes .devpilot/egm/UPSTREAM (source + commit) and .devpilot/egm/MANIFEST (every
# vendored file, read by install.sh). DevPilot's own glue is NOT touched:
# .devpilot/egm/DEVPILOT.md, .claude/skills/spec-review, .claude/commands/dp-spec.md.
#
# EGM is Apache-2.0 (Copyright Google LLC); its LICENSE ships in .devpilot/egm/LICENSE.
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/google/elephant-goldfish-model"
REF="main"; FROM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref)  REF="${2:?--ref needs a value}"; shift 2 ;;
    --from) FROM="${2:?--from needs a directory}"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"
DEST=".devpilot/egm"
AGENTS_DIR=".claude/agents"

TMP=""
cleanup() { if [ -n "$TMP" ]; then rm -rf "$TMP"; fi; }
trap cleanup EXIT

if [ -n "$FROM" ]; then
  SRC_REPO="$(cd "$FROM" && pwd)"
else
  TMP="$(mktemp -d)"
  echo "⬇️  Fetching $REPO_URL ($REF)..."
  if ! GIT_LFS_SKIP_SMUDGE=1 git clone -q --depth 1 --branch "$REF" "$REPO_URL" "$TMP/egm" 2>/dev/null; then
    # --branch takes tags/branches only; fall back to a full clone for a commit sha
    GIT_LFS_SKIP_SMUDGE=1 git clone -q "$REPO_URL" "$TMP/egm"
    git -C "$TMP/egm" checkout -q "$REF"
  fi
  SRC_REPO="$TMP/egm"
fi
SRC="$SRC_REPO/distributions/claude"
[ -d "$SRC/skills" ] && [ -d "$SRC/.claude-plugin/agents" ] || {
  echo "❌ $SRC does not look like EGM's Claude distribution (skills/ and .claude-plugin/agents/ expected)" >&2; exit 1; }

SHA="$(git -C "$SRC_REPO" rev-parse HEAD 2>/dev/null || echo unknown)"
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$SRC/.claude-plugin/plugin.json" | head -1)"

# ── 1. Replace DevPilot's previous vendored copy (keep DevPilot's own DEVPILOT.md) ──
if [ -f "$DEST/MANIFEST" ]; then
  while IFS= read -r f; do
    case "$f" in "$DEST/DEVPILOT.md") ;; "$DEST"/*|"$AGENTS_DIR"/egm-*.md) rm -f "$f" ;; esac
  done < "$DEST/MANIFEST"
fi
rm -rf "$DEST/skills" "$DEST/agents" "$DEST/resources" "$DEST/docs"
mkdir -p "$DEST" "$AGENTS_DIR"

# ── 2. Copy the distribution (text only — no icons, no OpenAI adapters) ────────────
cp "$SRC/LICENSE" "$DEST/LICENSE"
cp "$SRC/README.md" "$DEST/README.md"
cp -R "$SRC/agents" "$SRC/resources" "$DEST/"
mkdir -p "$DEST/docs"
# Only the docs the skills link to; FAQ, getting-started, privacy and release notes are for
# plugin users and nothing here references them. index.md keeps upstream links to those pages.
for doc in claude codex harnesses index; do
  if [ -f "$SRC/docs/$doc.md" ]; then cp "$SRC/docs/$doc.md" "$DEST/docs/"; fi
done
# Links to pages not vendored point upstream instead of to missing files.
for f in "$DEST"/docs/*.md; do
  sed -i.bak -E 's#\]\((faq|getting_started|privacy|releases)\.md\)#](https://github.com/google/elephant-goldfish-model/blob/main/docs/\1.md)#g' "$f" && rm -f "$f.bak"
done
for d in "$SRC"/skills/egm-*/; do
  n="$(basename "$d")"
  mkdir -p "$DEST/skills/$n"
  cp "$d/SKILL.md" "$DEST/skills/$n/SKILL.md"
  [ -d "$d/references" ] && cp -R "$d/references" "$DEST/skills/$n/"
done
# Claude adapters → project agents, named after their frontmatter name (egm-design, ...)
for a in "$SRC"/.claude-plugin/agents/*.md; do
  name="$(sed -n '2,8p' "$a" | sed -n 's/^name: *//p' | head -1)"
  [ -n "$name" ] || { echo "❌ $a has no name: field" >&2; exit 1; }
  cp "$a" "$AGENTS_DIR/$name.md"
done

# ── 3. Rewrite plugin paths for a project install ──────────────────────────────────
rewrite() {
  sed -i.bak \
    -e 's#\${CLAUDE_PLUGIN_ROOT}#.devpilot/egm#g' \
    -e 's#/egm:egm-drift-report#/dp-spec drift-report#g' \
    -e 's#/egm:egm-\([a-z-]*[a-z]\)#/dp-spec \1#g' \
    -e 's#egm:egm-#egm-#g' \
    "$1" && rm -f "$1.bak"
}
# The upstream README and docs/claude.md describe the plugin install and stay verbatim;
# DEVPILOT.md overrides them.
find "$DEST" -type f \( -name '*.md' -o -name '*.json' \) ! -path "$DEST/docs/claude.md" ! -path "$DEST/README.md" ! -name DEVPILOT.md -print | while IFS= read -r f; do rewrite "$f"; done
for a in "$AGENTS_DIR"/egm-*.md; do rewrite "$a"; done

# Each vendored SKILL.md gets a pointer to DevPilot's integration notes, right after
# its frontmatter (they override docs/claude.md, which describes the plugin install).
NOTE="> **DevPilot:** vendored from google/elephant-goldfish-model@${SHA:0:7} (Apache-2.0). Read \`.devpilot/egm/DEVPILOT.md\` first — it overrides \`docs/claude.md\` where they differ. EGM root: \`.devpilot/egm\`."
for s in "$DEST"/skills/egm-*/SKILL.md; do
  awk -v note="$NOTE" 'NR==1 && /^---$/ {fm=1; print; next}
       fm && /^---$/ {print; print ""; print note; fm=0; next} {print}' "$s" > "$s.tmp" && mv "$s.tmp" "$s"
done

# ── 4. Provenance + manifest ───────────────────────────────────────────────────────
cat > "$DEST/UPSTREAM" <<EOF
repository: $REPO_URL
ref: $REF
commit: $SHA
plugin_version: ${VERSION:-unknown}
synced: $(date -u '+%Y-%m-%d')
license: Apache-2.0 (see LICENSE) — Copyright Google LLC
EOF
{
  find "$DEST" -type f ! -name MANIFEST | sort
  ls "$AGENTS_DIR"/egm-*.md | sort
} > "$DEST/MANIFEST"

LEFT=$(grep -rl 'CLAUDE_PLUGIN_ROOT\|/egm:egm-' "$DEST" "$AGENTS_DIR"/egm-*.md 2>/dev/null | grep -v '/docs/claude\.md$\|egm/README\.md$\|egm/DEVPILOT\.md$' || true)
[ -z "$LEFT" ] || { echo "❌ unrewritten plugin paths in: $LEFT" >&2; exit 1; }
[ -f "$DEST/DEVPILOT.md" ] || echo "⚠️  $DEST/DEVPILOT.md is missing — restore it from DevPilot (git checkout -- $DEST/DEVPILOT.md)"

echo "✅ EGM ${VERSION:-?} (${SHA:0:7}) vendored: $(grep -c '' "$DEST/MANIFEST") files → $DEST + $AGENTS_DIR/egm-*.md"
echo "   Review: git diff --stat -- $DEST $AGENTS_DIR"
