#!/usr/bin/env bash
# Kills any process bound to this repo's e2e dev-server ports (apps/web on
# 3000, apps/api on 4000, apps/worker's metrics server on 9091, per
# playwright.config.ts's `webServer` entries).
# Used as a pre-flight step before `playwright test` starts its own
# webServer processes, and again from e2e/global-teardown.ts after the run
# finishes, so a leaked/orphaned `next dev`/`apps/api`/`apps/worker` process
# from a prior interrupted run never blocks (or gets silently "reused" by)
# the next run. See docs/PROGRESS.md "Needs founder" (GATE_E2E) for the bug
# this closes.
#
# Ports are read from playwright.config.ts itself (not hardcoded twice) so
# this stays correct if the config ever changes them.
#
# Usage: scripts/kill-e2e-ports.sh [--ports-only]
#   --ports-only: skip the secondary command-line-substring match below.
#   Used by e2e/global-teardown.ts, which runs *while Playwright's own
#   process is still alive* finishing its own webServer teardown/reporting;
#   killing a process there by matching on the dev-server command line
#   (rather than by the port it holds) risks hitting a PID Playwright's own
#   in-process bookkeeping still expects to reap itself, which has been
#   observed (empirically, in this sandbox) to leave the Playwright test
#   process itself hung afterward. The port-based kill doesn't have this
#   problem in practice. Pre-flight/post-`wait` callers (gate.sh) run only
#   when Playwright is confirmed not running, so they use both mechanisms.
set -uo pipefail
ports_only=0
[ "${1:-}" = "--ports-only" ] && ports_only=1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/playwright.config.ts"

ports=$(grep -oE "url: 'http://localhost:[0-9]+" "$CONFIG" | grep -oE '[0-9]+$' | sort -u)
if [ -z "$ports" ]; then
  # Fallback if the config's shape ever changes in a way the grep above
  # can't parse; keep these in sync with playwright.config.ts webServer.
  ports="3000 4000"
fi

# Command-line pattern a pid must match before the port-based lookup below
# will kill it — never kill just because something is bound to 3000/4000,
# since those are common defaults an unrelated dev server on the same
# sandbox could legitimately be using. Matches this repo's own dev-server
# shapes: `next dev`/`next-server` (apps/web), `tsx watch`/`serve.ts`
# (apps/api), or literally this repo's path (covers a built/`next start`
# process too).
REPO_PROC_PATTERN='next(-server| dev)|tsx watch|serve\.ts|'"$ROOT"

for port in $ports; do
  pids=""

  # Try every lookup mechanism available and union the results rather than
  # stopping at the first one that's installed: in this sandbox, `lsof` has
  # been observed to silently miss processes it should see (a netlink/procfs
  # visibility quirk between separate shell invocations), while `fuser`
  # (which walks /proc directly) still finds them. Belt and suspenders.
  if command -v lsof >/dev/null 2>&1; then
    pids="$pids $(lsof -ti tcp:"$port" 2>/dev/null)"
  fi
  if command -v fuser >/dev/null 2>&1; then
    pids="$pids $(fuser -n tcp "$port" 2>/dev/null | tr -d ':')"
  fi
  if command -v ss >/dev/null 2>&1; then
    pids="$pids $(ss -ltnp "sport = :$port" 2>/dev/null | grep -oE 'pid=[0-9]+' | grep -oE '[0-9]+')"
  fi

  pids=$(echo "$pids" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -u)

  if [ -n "$pids" ]; then
    for pid in $pids; do
      cmd=$(ps -o cmd= -p "$pid" 2>/dev/null || true)
      if [ -z "$cmd" ]; then
        continue # already gone
      fi
      if echo "$cmd" | grep -qE "$REPO_PROC_PATTERN"; then
        echo "kill-e2e-ports: killing pid $pid on port $port ($cmd)"
        kill -9 "$pid" 2>/dev/null || true
      else
        echo "kill-e2e-ports: WARNING pid $pid holds port $port but doesn't look like this repo's dev server ($cmd) - not killing"
      fi
    done
  fi
done

if [ "$ports_only" = 1 ]; then
  exit 0
fi

# Secondary match, keyed on this repo's exact dev-server entrypoints (never
# a blind `pkill next`): `tsx watch` mode doesn't exit when the watched
# script throws on startup (e.g. a transient stale-workspace-build import
# error) — it just idles waiting for a file change, leaving a watcher
# process alive that holds no port at all, so the port-based kill above
# can't find it. Observed empirically while validating this script. Read
# the exact `dev` command from each app's own package.json rather than
# hardcoding it twice, so this stays correct if those scripts ever change.
for app in web api worker; do
  pkg="$ROOT/apps/$app/package.json"
  [ -f "$pkg" ] || continue
  dev_cmd=$(node -e "try{process.stdout.write(require('$pkg').scripts.dev||'')}catch{}" 2>/dev/null)
  [ -n "$dev_cmd" ] || continue
  pids=$(pgrep -f -- "$dev_cmd" 2>/dev/null | sort -u)
  for pid in $pids; do
    echo "kill-e2e-ports: killing pid $pid matching apps/$app dev command '$dev_cmd'"
    kill -9 "$pid" 2>/dev/null || true
  done
done

exit 0
