#!/usr/bin/env bash
# tests/fake-security.sh — stands in for macOS `security` (generic passwords only) so the
# keychain tests never read or write the real login keychain. Store: $FAKE_STORE, ACCOUNT=value.
db="$FAKE_STORE"; cmd="$1"; shift; acct=""; val=""
while [ $# -gt 0 ]; do
  case "$1" in -a) acct="$2"; shift 2 ;; -w) if [ $# -gt 1 ] && [ "${2#-}" = "$2" ]; then val="$2"; shift 2; else shift; fi ;; -s) shift 2 ;; *) shift ;; esac
done
case "$cmd" in
  add-generic-password) grep -v "^$acct=" "$db" 2>/dev/null > "$db.t"; echo "$acct=$val" >> "$db.t"; mv "$db.t" "$db" ;;
  find-generic-password) v=$(grep "^$acct=" "$db" 2>/dev/null | cut -d= -f2-); [ -n "$v" ] || exit 44; echo "$v" ;;
  *) exit 1 ;;
esac
