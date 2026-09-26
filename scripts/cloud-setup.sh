#!/bin/bash
# Paste the contents of this file into the "Setup script" field of your Claude Code
# cloud environment (claude.ai/code → cloud icon → environment → Setup script).
# It runs as root before Claude starts, must exit 0, and must finish in ~5 minutes.
# Its result is cached, so later sessions start with everything already on disk.

corepack enable || true
corepack prepare pnpm@latest --activate || true

# Pre-pull the service images the project uses, so no session waits on a download.
docker pull pgvector/pgvector:pg16 &
docker pull minio/minio:latest &
docker pull gotenberg/gotenberg:8 &
docker pull axllent/mailpit:latest &
wait

# Playwright browsers for e2e (large; better cached than installed per session).
npx --yes playwright install --with-deps chromium || true

exit 0
