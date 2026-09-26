---
name: new-port
description: Checklist for adding a port (interface in core) with its fake adapter, real adapter and shared contract test suite. Use whenever a new external service or a new port method is introduced.
---
# New port

1. Interface in `packages/core/src/<module>/ports.ts` (or `core/src/ports/<name>.ts` if cross-module). Types via zod where data crosses the boundary. No vendor types in the interface.
2. Contract suite in `packages/adapters/src/<name>/contract.ts`: `export function run<Name>Contract(make: () => Promise<Port>)` covering happy path, errors mapped to `AppError` codes, idempotency where relevant, timeouts.
3. Fake: `packages/adapters/src/<name>-fake` — deterministic, in-memory, fixture-driven; passes the contract.
4. Real: `packages/adapters/src/<name>-<vendor>` — official SDK, timeouts, retries with jitter; runs the contract only when its env credentials exist (`describe.skipIf(!process.env.X)`). Add recorded fixtures for request/response mapping tests that always run.
5. Env selection in each app's `src/container.ts` (`<NAME>_PROVIDER=fake|<vendor>`), default `fake`; document the var in `.env.example`.
6. No secrets → leave real adapter behind the flag and add a "Needs founder" line in PROGRESS.
7. One-line ADR if a new dependency was added.
