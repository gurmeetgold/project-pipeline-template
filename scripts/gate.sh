#!/usr/bin/env bash
# Quiet quality gate. Full logs go to .gate/*.log; stdout shows only PASS/FAIL + error lines.
# Usage: ./scripts/gate.sh            (lint typecheck test build)
#        GATE_EVALS=1 ./scripts/gate.sh   (+ eval:locks, required from WP-B06)
#        GATE_E2E=1 ./scripts/gate.sh     (+ playwright e2e)
set -uo pipefail
mkdir -p .gate
status=0

# DB-backed integration tests (@pivot/db repositories, incl. the cross-tenant
# tests) skip themselves when DATABASE_URL is unset. A skip must never look
# like a pass, so say so up front. Locally: service postgresql start, then
# export DATABASE_URL=postgres://pivot:pivot@127.0.0.1:5432/pivot
if [ -z "${DATABASE_URL:-}" ]; then
  echo "WARN DATABASE_URL is not set — database integration tests will SKIP."
fi

step() {
  local name=$1; shift
  if "$@" >".gate/$name.log" 2>&1; then
    echo "PASS $name"
  else
    echo "FAIL $name  (full log: .gate/$name.log)"
    grep -nE "error|Error|ERR!|FAIL|✗|×|AssertionError|violation" ".gate/$name.log" | grep -v "^.*node_modules" | head -40
    status=1
  fi
}

step run-lock bash scripts/run-lock.test.sh

# One turbo run = parallel + cached; errors-only keeps output small.
step core pnpm exec turbo run lint typecheck test build --output-logs=errors-only
[ "$status" = 0 ] && step sdk-stale pnpm --filter @pivot/sdk generate:check
[ "$status" = 0 ] && [ "${GATE_EVALS:-0}" = 1 ] && step evals pnpm --filter @pivot/evals eval:locks

if [ "$status" = 0 ] && [ "${GATE_E2E:-0}" = 1 ]; then
  # Pre-flight: a prior interrupted run (e.g. this script killed by an
  # external timeout wrapper) can leave `next dev`/`apps/api` orphans bound
  # to the e2e ports. Clear them before Playwright starts its own
  # webServer, so a leaked process never blocks or gets silently reused.
  bash scripts/kill-e2e-ports.sh

  e2e_pid=""
  e2e_pgid=""
  cleanup_e2e() {
    # If gate.sh itself gets SIGTERM/SIGINT (e.g. from an external `timeout`
    # sending a graceful signal before SIGKILL), kill the whole e2e process
    # group so Playwright's own next dev/serve.ts children don't become
    # orphans. A hard SIGKILL of gate.sh can't be trapped — that's what the
    # pre-flight cleanup above and the Playwright globalTeardown are for.
    if [ -n "$e2e_pgid" ]; then
      kill -TERM "-$e2e_pgid" 2>/dev/null || true
    fi
    bash scripts/kill-e2e-ports.sh
  }
  trap cleanup_e2e TERM INT

  # CI=true makes playwright.config.ts's `reuseExistingServer: !process.env.CI`
  # false, so a stale/zombie server is never silently reused instead of a
  # fresh one — matters even with the pre-flight kill above as defense in
  # depth (e.g. if a process lingers briefly after kill -9 before the port
  # is actually released).
  if command -v setsid >/dev/null 2>&1; then
    setsid env CI=true pnpm -w e2e >".gate/e2e.log" 2>&1 &
  else
    env CI=true pnpm -w e2e >".gate/e2e.log" 2>&1 &
  fi
  e2e_pid=$!
  # setsid makes $e2e_pid its own group leader, but reading the pgid with
  # `ps` right away can race setsid() and return the gate's own group, which
  # the watchdog would then kill (ADR-085). Use the pid directly.
  if command -v setsid >/dev/null 2>&1; then
    e2e_pgid=$e2e_pid
  else
    e2e_pgid=""
  fi

  # Watchdog: this sandbox has an observed, unrelated quirk where the
  # Playwright CLI process itself sometimes doesn't exit for many minutes
  # after every test has already printed a pass (its webServer child tree
  # stays alive) — not a reaping bug (ports/processes are already clean by
  # then), just a slow/hung exit. Bound the wait so one flaky exit can't
  # hang the whole gate, and tell an honest pass from a real failure by
  # reading Playwright's own summary line rather than trusting an exit code
  # that a forced kill would otherwise make look like a failure.
  e2e_timeout=${GATE_E2E_TIMEOUT_SECONDS:-600}
  # The TERM trap kills the inner sleep; otherwise stopping the watchdog left
  # `sleep` holding the gate's stdout, so `gate.sh | tail` waited the full
  # timeout even after a pass (ADR-085).
  ( sleep "$e2e_timeout" &
    sleep_pid=$!
    trap 'kill "$sleep_pid" 2>/dev/null; exit 0' TERM
    wait "$sleep_pid" || exit 0
    if [ -n "$e2e_pgid" ]; then
      echo "e2e watchdog: no exit after ${e2e_timeout}s, killing process group $e2e_pgid" >>".gate/e2e.log"
      kill -TERM "-$e2e_pgid" 2>/dev/null || true
    else
      echo "e2e watchdog: no exit after ${e2e_timeout}s, killing pid $e2e_pid" >>".gate/e2e.log"
      kill -TERM "$e2e_pid" 2>/dev/null || true
    fi
  ) >/dev/null 2>&1 &
  watchdog_pid=$!

  if wait "$e2e_pid"; then
    echo "PASS e2e"
  elif grep -qE '^\s*[0-9]+ passed' ".gate/e2e.log" && ! grep -qE '[0-9]+ failed|Timed out|flaky' ".gate/e2e.log"; then
    echo "PASS e2e (process needed a forced exit after tests completed - see ADR-085)"
  else
    echo "FAIL e2e  (full log: .gate/e2e.log)"
    grep -nE "error|Error|ERR!|FAIL|✗|×|AssertionError|violation" ".gate/e2e.log" | grep -v "^.*node_modules" | head -40
    status=1
  fi

  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true
  trap - TERM INT
  bash scripts/kill-e2e-ports.sh
fi

exit $status
