#!/usr/bin/env bash
# Generates the two-tier project index:
#   docs/project-index.md — a SMALL bounded map (read this; ~always < 100 lines)
#   docs/index/<shard>.md — per-area file listings (grepped by scope.sh,
#                           never loaded into agent context wholesale)
# Token contract: agents read the map + scope.sh results — O(1) context per
# task regardless of repo size.
#
# Regeneration is HASH-GATED: keyed on git HEAD + tracked-file-list checksum,
# so calling this is a free no-op when nothing changed.
#   bash scripts/generate-project-index.sh            # regenerate if stale
#   bash scripts/generate-project-index.sh --force    # always regenerate

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="$ROOT/docs/project-index.md"
SHARD_DIR="$ROOT/docs/index"
STATE="$SHARD_DIR/.state"
mkdir -p "$ROOT/docs" "$SHARD_DIR"
DATE="$(date '+%Y-%m-%d %H:%M')"

# ---------------------------------------------------------------------------
# Freshness gate — skip the rebuild when the repo content signature matches.
# Signature: HEAD commit + checksum of the tracked-file list + count of
# untracked source files (new files mid-task still trigger a refresh).
# ---------------------------------------------------------------------------
sig() {
  printf '%s|%s|%s' \
    "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo no-head)" \
    "$(git -C "$ROOT" ls-files 2>/dev/null | cksum | awk '{print $1}')" \
    "$(git -C "$ROOT" ls-files -o --exclude-standard 2>/dev/null | grep -cE '\.(ts|tsx|js|jsx|cs|py|go|java|vue)$' || true)"
}
CUR_SIG=$(sig)
if [ "${1:-}" != "--force" ] && [ -f "$OUT" ] && [ -f "$STATE" ] && [ "$(cat "$STATE" 2>/dev/null)" = "$CUR_SIG" ]; then
  echo "✅ Project index fresh (content signature unchanged) — skipped. Force: --force"
  exit 0
fi

# ---------------------------------------------------------------------------
# Read stack from project.config.md
# ---------------------------------------------------------------------------
CONFIG="$ROOT/project.config.md"
HAS_FRONTEND=false
HAS_BACKEND=false
HAS_DB=false

read_stack_value() {
  local key="$1"
  awk -v wanted_key="$key" '
    BEGIN { in_stack = 0 }
    /^stack:[[:space:]]*$/ { in_stack = 1; next }
    in_stack && /^[^[:space:]]/ { in_stack = 0 }
    in_stack {
      if (match($0, "^[[:space:]]*" wanted_key ":[[:space:]]*")) {
        line = $0
        sub("^[[:space:]]*" wanted_key ":[[:space:]]*", "", line)
        sub(/[[:space:]]+#.*/, "", line)
        gsub(/"/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
        exit
      }
    }
  ' "$CONFIG"
}

if [ -f "$CONFIG" ]; then
  FRONTEND_STACK=$(read_stack_value "frontend" || true)
  BACKEND_STACK=$(read_stack_value "backend" || true)
  DB_STACK=$(read_stack_value "database" || true)

  case "${FRONTEND_STACK:-none}" in
    none|false|"") ;;
    *) HAS_FRONTEND=true ;;
  esac

  case "${BACKEND_STACK:-none}" in
    none|false|"") ;;
    *) HAS_BACKEND=true ;;
  esac

  case "${DB_STACK:-none}" in
    none|false|"") ;;
    *) HAS_DB=true ;;
  esac
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
# All detailed listings go to the CURRENT SHARD ($CUR), not the map.
CUR="$OUT"
shard() {   # shard <name> — start/append a shard file in docs/index/
  CUR="$SHARD_DIR/$1.md"
  if [ ! -f "$CUR.tmp-started" ]; then
    printf '# Index shard: %s\n> Grepped by scope.sh — do NOT load wholesale into context.\n' "$1" > "$CUR"
    : > "$CUR.tmp-started"
  fi
}
map_out() { CUR="$OUT"; }   # switch writes back to the small map

# Write a section header (into the current target)
section() {
  printf '\n## %s\n' "$1" >> "$CUR"
}

# Scan for files matching a pattern under $ROOT/<dir>
# Writes: "  relative/path — label" per file found
scan() {
  local dir="$1"
  local pattern="$2"
  local full_dir="$ROOT/$dir"

  [ -d "$full_dir" ] || return 0

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local rel="${f#$ROOT/}"
    # Extract up to 3 declared symbols (multi-language) for a richer scan signal.
    local decl
    decl=$(grep -m3 -oE '(export class|export function|export const|public class|class|interface|enum|function|const|def|func|type) [A-Za-z][A-Za-z0-9_]+' "$f" 2>/dev/null \
      | awk '{print $NF}' | sort -u | head -3 | paste -sd, - || true)
    if [ -z "$decl" ]; then
      decl=$(basename "$f" | sed 's/\.[^.]*$//')
    fi
    printf '  %-65s — %s\n' "$rel" "$decl" >> "$CUR"
  done < <(
    find "$full_dir" \
      -name "$pattern" \
      ! -path "*/node_modules/*" \
      ! -path "*/.git/*" \
      ! -path "*/dist/*" \
      ! -path "*/.angular/*" \
      ! -path "*/obj/*" \
      ! -path "*/bin/*" \
      -type f 2>/dev/null \
    | sort
  )
  return 0
}

# ---------------------------------------------------------------------------
# Write index header
# ---------------------------------------------------------------------------
rm -f "$SHARD_DIR"/*.md "$SHARD_DIR"/*.tmp-started 2>/dev/null || true
cat > "$OUT" << HEADER
# Project Index (map)
> Auto-generated by devpilot — do not edit. Refresh: \`bash scripts/generate-project-index.sh\`
> Last updated: $DATE
>
> **Agent instructions (token contract):**
> 1. Run \`bash scripts/scope.sh --save <slug> "<task>"\` — it greps the detail
>    shards (docs/index/*.md) and returns the top candidate files. Read ONLY those.
> 2. This map is the most you load by default. NEVER read a shard wholesale;
>    if scope.sh finds nothing, grep the relevant shard for your keywords.
> 3. A task's saved scope lives at docs/tasks/<slug>-scope.md — later phases
>    reuse it instead of re-deriving.

HEADER

# ── Frontend (shard) ────────────────────────────────────────────────────────
if $HAS_FRONTEND; then
  shard "frontend"
  section "Routing / Navigation"
  scan "apps" "*.routes.ts"
  scan "apps" "app-routing.module.ts"
  scan "src"  "*.routes.ts"
  scan "src"  "app-routing.module.ts"

  section "Pages"
  scan "apps" "*.page.ts"
  scan "src"  "*.page.ts"
  scan "src/pages" "*.tsx"
  scan "app"  "page.tsx"

  section "Components"
  scan "apps" "*.component.ts"
  scan "src"  "*.component.ts"
  scan "src/components" "*.tsx"
  scan "components" "*.tsx"

  section "Services / Stores (Frontend)"
  scan "apps" "*.service.ts"
  scan "apps" "*.store.ts"
  scan "src"  "*.service.ts"
  scan "src"  "*.store.ts"
  scan "src/hooks" "*.ts"

  section "Shared Libraries"
  scan "libs" "*.ts"
  scan "libs" "*.tsx"
fi

# ── Backend (shard) ─────────────────────────────────────────────────────────
if $HAS_BACKEND; then
  shard "backend"
  section "API Controllers / Endpoints (.NET)"
  scan "apps" "*Controller.cs"
  scan "src"  "*Controller.cs"
  scan "apps" "*Endpoint.cs"

  section "Commands / Queries / Handlers (CQRS)"
  scan "apps" "*Command.cs"
  scan "apps" "*Query.cs"
  scan "apps" "*Handler.cs"

  section "Domain Services"
  scan "apps" "*Service.cs"
  scan "src"  "*Service.cs"

  section "Node / Python Routes"
  scan "src"  "*.routes.ts"
  scan "src"  "*.controller.ts"
  scan "api"  "routes.py"
  scan "api"  "views.py"
fi

# ── Database (shard) ─────────────────────────────────────────────────────────
if $HAS_DB; then
  shard "database"
  section "Entities / Models"
  scan "apps" "*Entity.cs"
  scan "apps" "*.Model.cs"
  scan "src"  "*Entity.cs"

  section "DB Context / Repositories"
  scan "apps" "*DbContext.cs"
  scan "apps" "*Repository.cs"
  scan "src"  "*DbContext.cs"

  section "EF Core Migrations"
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    rel="${f#$ROOT/}"
    printf '  %s\n' "$rel" >> "$CUR"
  done < <(find "$ROOT" -path "*/Migrations/*.cs" ! -path "*/obj/*" ! -path "*/bin/*" -type f 2>/dev/null | sort)
fi

# ── Shared DTOs (shard) ──────────────────────────────────────────────────────
shard "shared"
section "Shared Models / DTOs"
scan "libs/shared-models" "*.ts"
scan "apps" "*Dto.cs"
scan "apps" "*.Request.cs"
scan "apps" "*.Response.cs"
scan "src"  "*Dto.cs"

# ── Entry Points / Config (map — small by nature) ────────────────────────────
map_out
section "Entry Points / Key Config"
# Detect entry points dynamically — no hardcoded project paths
for pattern in "Program.cs" "main.ts" "main.py" "main.go" "index.ts" "app.py"; do
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    rel="${f#$ROOT/}"
    printf '  %s\n' "$rel" >> "$OUT"
  done < <(find "$ROOT" -name "$pattern" \
    ! -path "*/.git/*" ! -path "*/node_modules/*" \
    ! -path "*/obj/*" ! -path "*/bin/*" ! -path "*/__pycache__/*" \
    -type f 2>/dev/null | sort | head -5)
done
# Common config files
for f in "package.json" "nx.json" "angular.json" "go.mod" "pyproject.toml" \
         "requirements.txt" ".env.example"; do
  [ -f "$ROOT/$f" ] && printf '  %s\n' "$f" >> "$OUT"
done
# appsettings.json anywhere in the tree
while IFS= read -r f; do
  [ -f "$f" ] || continue
  rel="${f#$ROOT/}"
  printf '  %s\n' "$rel" >> "$OUT"
done < <(find "$ROOT" -name "appsettings*.json" \
  ! -path "*/obj/*" ! -path "*/bin/*" -type f 2>/dev/null | sort)

# ── Workspace packages (monorepo awareness) ───────────────────────────────────
section "Workspace Packages (package roots — scope work to one)"
{
  find "$ROOT" \( -name "package.json" -o -name "go.mod" -o -name "pyproject.toml" -o -name "*.csproj" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" \
    ! -path "*/obj/*" ! -path "*/bin/*" ! -path "*/.angular/*" -type f 2>/dev/null
} | sort | while IFS= read -r f; do
  rel="${f#$ROOT/}"
  dir=$(dirname "$rel"); [ "$dir" = "." ] && dir="(root)"
  printf '  %-50s — %s\n' "$dir" "$(basename "$f")" >> "$OUT"
done

# ── Existing docs ─────────────────────────────────────────────────────────────
section "Project Docs (read for domain context)"
for f in "CLAUDE.md" "AGENTS.md" "README.md"; do
  [ -f "$ROOT/$f" ] && printf '  %s\n' "$f" >> "$OUT"
done
# Any markdown files in docs/ root
find "$ROOT/docs" -maxdepth 1 -name "*.md" 2>/dev/null | sort | while IFS= read -r f; do
  rel="${f#$ROOT/}"
  printf '  %s\n' "$rel" >> "$OUT"
done

# ── Top-level layout (map) — one line per tracked top-level area ─────────────
map_out
section "Top-Level Layout (tracked files per area)"
git -C "$ROOT" ls-files 2>/dev/null | awk -F/ '{print (NF>1 ? $1 : "(root)")}' \
  | sort | uniq -c | sort -rn | head -20 \
  | awk '{printf "  %-40s %s files\n", $2, $1}' >> "$OUT" || true

# ── Detail shards summary (map) — counts only; scope.sh greps the contents ───
section "Detail Shards (grep via scope.sh — never load wholesale)"
TOTAL=0
for sh in "$SHARD_DIR"/*.md; do
  [ -f "$sh" ] || continue
  # grep -c prints "0" itself on no-match (exit 1) — `|| echo 0` would double it.
  N=$(grep -c '^[[:space:]][[:space:]]*[A-Za-z]' "$sh" 2>/dev/null || true)
  N=${N:-0}
  TOTAL=$((TOTAL + N))
  printf '  docs/index/%-25s — %s entries\n' "$(basename "$sh")" "$N" >> "$OUT"
done

echo "" >> "$OUT"
echo "---" >> "$OUT"
echo "_${TOTAL} files indexed across shards · map stays small by design_" >> "$OUT"

# Persist the content signature + clean shard markers.
printf '%s' "$CUR_SIG" > "$STATE"
rm -f "$SHARD_DIR"/*.tmp-started 2>/dev/null || true

MAPLINES=$(wc -l < "$OUT" | tr -d ' ')
echo "✅ Project index written → docs/project-index.md (map: $MAPLINES lines) + $(ls "$SHARD_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ') shard(s), $TOTAL entries"
