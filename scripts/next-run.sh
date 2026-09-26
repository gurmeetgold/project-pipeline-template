#!/usr/bin/env bash
# Start the next build run immediately via the routine's API trigger.
set -uo pipefail
if [ -z "${ROUTINE_FIRE_URL:-}" ] || [ -z "${ROUTINE_TOKEN:-}" ]; then echo "NO ROUTINE CREDS"; exit 0; fi
code=$(curl -s -o /tmp/fire.out -w '%{http_code}' -X POST "$ROUTINE_FIRE_URL" \
  -H "Authorization: Bearer $ROUTINE_TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
  -H "Content-Type: application/json" \
  -d '{"text":"Chained run: continue the build per the wp-cycle skill."}')
echo "FIRE $code"
[ "$code" -lt 300 ] || head -c 300 /tmp/fire.out
