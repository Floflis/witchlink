#!/usr/bin/env bash
# End-to-end smoke tests for Witchlink r1. Run: tests/smoke.sh [path/to/wl]
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
WL=${1:-$ROOT/wl}
[[ -x $WL ]] || { printf 'Not executable: %s\n' "$WL" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || { printf 'Missing dependency: %s\n' "$1" >&2; exit 1; }; }
need jq; need git; need cmp; need mkfifo; need base64
TMP=$(mktemp -d "${TMPDIR:-/tmp}/witchlink smoke.XXXXXX")
SERVER_PID=''
cleanup(){
  if [[ -n $SERVER_PID ]]; then kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; fi
  rm -rf -- "$TMP"
}
trap cleanup EXIT

# Binary data, spaces in paths, multiple source files and add.
printf 'first\0chunk\n' > "$TMP/part one.bin"
printf '\xffsecond chunk\n' > "$TMP/part-two.bin"
"$WL" create "$TMP/combined.bin" "$TMP/part one.bin" "$TMP/part-two.bin"
cat -- "$TMP/part one.bin" "$TMP/part-two.bin" > "$TMP/expected.bin"
"$WL" render "$TMP/.combined.bin.wlref" > "$TMP/rendered.bin"
cmp "$TMP/expected.bin" "$TMP/rendered.bin"
"$WL" add "$TMP/combined.bin" "$TMP/part one.bin"
cat -- "$TMP/expected.bin" "$TMP/part one.bin" > "$TMP/expected-added.bin"
"$WL" render "$TMP/.combined.bin.wlref" > "$TMP/rendered-added.bin"
cmp "$TMP/expected-added.bin" "$TMP/rendered-added.bin"

# Git blob segment is streamed byte-for-byte too.
mkdir "$TMP/git-repo"
git -C "$TMP/git-repo" init -q
git -C "$TMP/git-repo" config user.email smoke@example.invalid
git -C "$TMP/git-repo" config user.name 'Witchlink Smoke Test'
printf 'git blob\0payload\n' > "$TMP/git-repo/blob.bin"
git -C "$TMP/git-repo" add blob.bin
git -C "$TMP/git-repo" commit -qm 'add test blob'
OID=$(git -C "$TMP/git-repo" rev-parse HEAD:blob.bin)
jq --arg repo "$TMP/git-repo" --arg oid "$OID" '.segments += [{type:"git-blob",repo:$repo,oid:$oid}]' "$TMP/.combined.bin.wlref" > "$TMP/manifest.tmp"
mv -- "$TMP/manifest.tmp" "$TMP/.combined.bin.wlref"
cat -- "$TMP/expected-added.bin" "$TMP/git-repo/blob.bin" > "$TMP/expected-git.bin"
"$WL" render "$TMP/.combined.bin.wlref" > "$TMP/rendered-git.bin"
cmp "$TMP/expected-git.bin" "$TMP/rendered-git.bin"

# Persistent FIFO node and two sequential readers.
"$WL" serve "$TMP/.combined.bin.wlref" > "$TMP/server.log" 2>&1 &
SERVER_PID=$!
for _ in {1..100}; do [[ -p "$TMP/combined.bin.wl" ]] && break; sleep 0.05; done
[[ -p "$TMP/combined.bin.wl" ]] || { cat "$TMP/server.log" >&2; exit 1; }
cat "$TMP/combined.bin.wl" > "$TMP/fifo-one.bin"
cat "$TMP/combined.bin.wl" > "$TMP/fifo-two.bin"
cmp "$TMP/expected-git.bin" "$TMP/fifo-one.bin"
cmp "$TMP/expected-git.bin" "$TMP/fifo-two.bin"
kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=''
[[ -p "$TMP/combined.bin.wl" ]]
printf 'PASS: binary bytes, multi-source create/add, Git blobs, repeated FIFO reads, retained FIFO node\n'
