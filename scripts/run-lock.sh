#!/usr/bin/env bash
# Build-run lock stored as branch claude/run-lock.  Usage: run-lock.sh acquire|beat|release
#
# Fast-forward pushes only: this script never uses `git push --delete` or
# `--force` against the lock branch (both are blocked in auto-mode, which
# used to make `release` fail silently). The lock branch's history just
# grows: acquire/beat/release commits stack on top of each other, and a
# plain (non-force) push naturally rejects a lost race because it refuses
# a non-fast-forward update.
set -uo pipefail
LOCK=claude/run-lock
STALE=${RUN_LOCK_STALE_MIN:-20}
git fetch -q origin "+refs/heads/$LOCK:refs/remotes/origin/$LOCK" 2>/dev/null || true
exists()   { git ls-remote --exit-code --heads origin "$LOCK" >/dev/null 2>&1; }
age_min()  { local t; t=$(git log -1 --format=%ct "origin/$LOCK" 2>/dev/null || echo 0); echo $(( ( $(date +%s) - t ) / 60 )); }
subject()  { git log -1 --format=%s "origin/$LOCK" 2>/dev/null || echo ""; }
mkcommit() { git commit-tree "$(git rev-parse "$1^{tree}")" -p "$1" -m "run-lock: $2 $(date -u +%FT%TZ)"; }
case "${1:-}" in
  acquire)
    if exists; then
      a=$(age_min)
      s=$(subject)
      if echo "$s" | grep -qi release; then
        reason="released"
      elif [ "$a" -ge "$STALE" ]; then
        reason="stale (${a}m)"
      else
        echo "LOCKED (heartbeat ${a}m ago)"; exit 1
      fi
      echo "lock $reason - acquiring"
      c=$(mkcommit "origin/$LOCK" acquire)
    else
      git fetch -q origin claude/trunk
      c=$(mkcommit origin/claude/trunk acquire)
    fi
    if git push -q origin "$c:refs/heads/$LOCK"; then echo "ACQUIRED"; else echo "LOST RACE"; exit 1; fi ;;
  beat)
    exists || { echo "NO LOCK"; exit 1; }
    if echo "$(subject)" | grep -qi release; then echo "NO LOCK (released)"; exit 1; fi
    c=$(mkcommit "origin/$LOCK" beat)
    if git push -q origin "$c:refs/heads/$LOCK"; then echo "BEAT"; else echo "LOST LOCK"; exit 1; fi ;;
  release)
    exists || { echo "NO LOCK"; exit 1; }
    c=$(mkcommit "origin/$LOCK" release)
    if git push -q origin "$c:refs/heads/$LOCK"; then echo "RELEASED"; else echo "RELEASE FAILED"; exit 1; fi ;;
  *) echo "usage: $0 acquire|beat|release"; exit 2 ;;
esac
