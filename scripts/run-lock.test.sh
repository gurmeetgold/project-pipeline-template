#!/usr/bin/env bash
# Exercises scripts/run-lock.sh against a throwaway local "origin" so it never
# touches the real claude/run-lock branch. Also statically proves the fix for
# the bug this test was written for: auto-mode rejects `git push --delete`
# and `--force`/`-f`, which used to make `release` on a stale/rejected lock
# fail silently. run-lock.sh must never invoke either.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/run-lock.sh"
fail=0
assert_eq() { [ "$1" = "$2" ] || { echo "FAIL: $3 (expected [$2], got [$1])"; fail=1; }; }

# --- static check: no destructive push flags anywhere in the script ---
if grep -vE '^\s*#' "$SCRIPT" | grep -nE 'push[^\n]*(--delete|--force|[[:space:]]-f([[:space:]]|$))'; then
  echo "FAIL: run-lock.sh uses a destructive push flag (--delete/--force/-f)"
  fail=1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bare="$work/origin.git"
repo="$work/repo"
git init -q --bare "$bare"
git init -q "$repo"
cd "$repo"
git config user.email test@test.local
git config user.name test
git remote add origin "$bare"
git commit -q --allow-empty -m init
# local file:// transport prints a harmless "expected acknowledgments"
# negotiation warning on some git versions; the push itself still succeeds.
git push -q -u origin HEAD:refs/heads/claude/trunk 2>/dev/null

export RUN_LOCK_STALE_MIN=20

# 1. acquire when the lock branch does not exist yet
out=$(bash "$SCRIPT" acquire | tail -1); assert_eq "$out" "ACQUIRED" "acquire on missing branch"
git ls-remote --exit-code --heads origin claude/run-lock >/dev/null || { echo "FAIL: lock branch not created"; fail=1; }

# 2. a second immediate acquire is refused (fresh heartbeat, not released)
out=$(bash "$SCRIPT" acquire || true)
case "$out" in
  LOCKED*) : ;;
  *) echo "FAIL: expected LOCKED, got [$out]"; fail=1 ;;
esac

# 3. beat succeeds while held
out=$(bash "$SCRIPT" beat); assert_eq "$out" "BEAT" "beat while held"

# 4. release succeeds and does NOT delete the branch (fast-forward commit only)
out=$(bash "$SCRIPT" release); assert_eq "$out" "RELEASED" "release"
git ls-remote --exit-code --heads origin claude/run-lock >/dev/null || { echo "FAIL: release deleted the branch (must fast-forward, never delete)"; fail=1; }

# 5. beat after release is refused - nothing to heartbeat
out=$(bash "$SCRIPT" beat || true)
case "$out" in
  "NO LOCK"*) : ;;
  *) echo "FAIL: expected NO LOCK after release, got [$out]"; fail=1 ;;
esac

# 6. acquire after release succeeds because the tip commit says "release"
out=$(bash "$SCRIPT" acquire | tail -1); assert_eq "$out" "ACQUIRED" "acquire after release"

# 7. a stale (but not released) heartbeat is also acquirable
#    Simulate staleness by pushing a backdated "beat" commit directly.
tip=$(git rev-parse origin/claude/run-lock)
old_ts=$(( $(date +%s) - 30*60 ))
old=$(GIT_COMMITTER_DATE="@$old_ts +0000" git commit-tree "$tip^{tree}" -p "$tip" -m "run-lock: beat stale-simulated")
git push -q origin "$old:refs/heads/claude/run-lock"
out=$(bash "$SCRIPT" acquire | tail -1); assert_eq "$out" "ACQUIRED" "acquire on stale (30m) heartbeat"

# 8. a fresh (non-stale, non-released) heartbeat blocks acquire
out=$(bash "$SCRIPT" acquire || true)
case "$out" in
  LOCKED*) : ;;
  *) echo "FAIL: expected LOCKED for a fresh heartbeat, got [$out]"; fail=1 ;;
esac

if [ "$fail" = 0 ]; then echo "PASS run-lock.test.sh"; else exit 1; fi
