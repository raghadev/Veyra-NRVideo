#!/bin/bash
# usage: check-reapply.sh <fully patched chiaki-ng stage>
#
# build-native.ps1 decides "already applied" one patch at a time with `git apply --reverse --check`.
# A patch whose added lines sit within three lines of another patch's added lines fails that check
# on the complete stage, and the second run of the build script on the same stage then stops.
# Every patch must pass here. Run it after regenerating a patch with mkpatch.sh.
set -euo pipefail
stage="$1"
dir="$(cd "$(dirname "$0")/../patches" && pwd)"
bad=0
for p in "$dir"/[0-9][0-9][0-9][0-9]-*.patch; do
  if git -C "$stage" apply --reverse --check "$p" 2>/dev/null; then
    echo "ok   $(basename "$p")"
  else
    echo "FAIL $(basename "$p")"
    bad=1
  fi
done
exit $bad
