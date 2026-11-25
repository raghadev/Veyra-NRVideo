#!/bin/bash
# Regenerate one chiaki patch of the fork with exact line numbers.
#
# usage (inside a chiaki-ng stage whose working tree holds the state AFTER this patch):
#   mkpatch.sh <patches-dir>/<NNNN-name.patch> <file>...
#
# Rebuilds, in a temporary index, the tree after every patch of <patches-dir> whose name sorts before
# the one being written, then diffs the working tree against it for the given files. New files must be
# known to the stage index (git add -N).
set -euo pipefail
out="$1"; shift
dir="$(cd "$(dirname "$out")" && pwd)"; name="$(basename "$out")"
pin="$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['chiaki_commit'])" "$dir/../dependency-lock.json" 2>/dev/null || true)"
pin="${CHIAKI_PIN:-${pin:-0e16950165f06e5c3291537c2eeba6e852be7120}}"
tmp="$(mktemp -d)"; export GIT_INDEX_FILE="$tmp/index"
git read-tree "$pin"
for p in "$dir"/[0-9][0-9][0-9][0-9]-*.patch; do
  [ "$(basename "$p")" \< "$name" ] || continue
  git apply --cached "$p"
done
tree="$(git write-tree)"
unset GIT_INDEX_FILE
git diff "$tree" -- "$@" > "$dir/$name"
rm -rf "$tmp"
echo "$name: $(wc -l < "$dir/$name" | tr -d ' ') lines (base tree $tree)"
