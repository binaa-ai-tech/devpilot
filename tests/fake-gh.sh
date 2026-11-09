#!/usr/bin/env bash
# tests/fake-gh.sh — stands in for the gh CLI with REAL merges on the origin remote.
# PRs are recorded in $FAKE_GH_DIR/prs as "<n> <base> <head>". `pr merge` really
# merges (merge commit or squash) in a scratch clone and pushes to origin.
# FAKE_GH_BLOCK=1 makes a direct merge fail (checks still running); --auto then "arms".
set -u
D="${FAKE_GH_DIR:?FAKE_GH_DIR not set}"; mkdir -p "$D"; touch "$D/prs"
case "${1:-} ${2:-}" in
  "auth status") exit 0 ;;
  "pr view") exit 1 ;;
  "pr create")
    shift 2; BASE=""; HEAD=""
    while [ $# -gt 0 ]; do case "$1" in --base) BASE="$2"; shift 2 ;; --head) HEAD="$2"; shift 2 ;; *) shift ;; esac; done
    N=$(awk -v b="$BASE" -v h="$HEAD" '$2 == b && $3 == h { print $1 }' "$D/prs" | tail -1)
    if [ -z "$N" ]; then N=$(( $(wc -l < "$D/prs") + 1 )); echo "$N $BASE $HEAD" >> "$D/prs"; fi
    echo "https://github.com/acme/app/pull/$N" ;;
  "pr merge")
    N="$3"; shift 3; METHOD=squash; DEL=0; AUTO=0
    for a in "$@"; do case "$a" in --merge) METHOD=merge ;; --squash) METHOD=squash ;; --delete-branch) DEL=1 ;; --auto) AUTO=1 ;; esac; done
    if [ -n "${FAKE_GH_BLOCK:-}" ]; then [ "$AUTO" = 1 ] && exit 0; exit 1; fi
    read -r _ BASE HEAD < <(awk -v n="$N" '$1 == n' "$D/prs")
    ORIGIN=$(git remote get-url origin); W=$(mktemp -d)
    git clone -q "$ORIGIN" "$W/c" 2>/dev/null && cd "$W/c" || exit 1
    git -c user.email=gh@fake -c user.name=gh checkout -q "$BASE" || exit 1
    if [ "$METHOD" = merge ]; then
      git -c user.email=gh@fake -c user.name=gh merge -q --no-ff "origin/$HEAD" -m "Merge pull request #$N from $HEAD" || exit 1
    else
      git merge -q --squash "origin/$HEAD" && git -c user.email=gh@fake -c user.name=gh commit -qm "PR #$N ($HEAD)" || exit 1
    fi
    git push -q origin "$BASE" 2>/dev/null || exit 1
    [ "$DEL" = 1 ] && git push -q origin --delete "$HEAD" 2>/dev/null
    rm -rf "$W"; exit 0 ;;
  *) exit 0 ;;
esac
