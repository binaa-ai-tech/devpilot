#!/usr/bin/env bash
db="$FAKE_STORE"; case "$1" in store) acct="$7"; v=$(cat); grep -v "^$acct=" "$db" 2>/dev/null > "$db.t"; echo "$acct=$v" >> "$db.t"; mv "$db.t" "$db";; lookup) grep "^$5=" "$db" 2>/dev/null | cut -d= -f2-;; esac
