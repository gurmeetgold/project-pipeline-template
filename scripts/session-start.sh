#!/usr/bin/env bash
# Runs at the start of every Claude Code session (see .claude/settings.json).
# Keeps cloud sessions ready without re-installing when nothing changed.
set -u
cd "$(dirname "$0")/.."

# Only do the heavy work in cloud sessions.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

# Dependencies (no-op when the store is already warm).
if [ -f pnpm-lock.yaml ]; then
  corepack enable >/dev/null 2>&1 || true
  pnpm install --frozen-lockfile >/dev/null 2>&1 || pnpm install >/dev/null 2>&1 || true
fi

# Postgres is pre-installed in cloud sessions but not running.
service postgresql start >/dev/null 2>&1 || true

# Ensure the pivot role + database exist so DB tests never silently skip.
as_pg() { if [ "$(id -u)" = "0" ]; then su postgres -c "$1"; else sudo -n -u postgres sh -c "$1"; fi; }
as_pg "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='pivot'\" | grep -q 1 || psql -c \"CREATE ROLE pivot LOGIN PASSWORD 'pivot' CREATEDB\"" >/dev/null 2>&1 || true
as_pg "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='pivot'\" | grep -q 1 || createdb -O pivot pivot" >/dev/null 2>&1 || true

exit 0
