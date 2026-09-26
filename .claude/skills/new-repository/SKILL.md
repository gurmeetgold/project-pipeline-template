---
name: new-repository
description: Checklist for adding a Drizzle table and repository that implements a core repository port, including the mandatory cross-tenant isolation test. Use for every new private table.
---
# New repository

1. Schema in `packages/db/src/schema/<module>.ts`: snake_case plural table, `id text` with the module's ULID prefix, `created_at/updated_at timestamptz`, `workspace_id` + index for private tables; insert-only for `*_versions`.
2. `pnpm --filter @pivot/db drizzle-kit generate` → review SQL → commit migration. Never hand-edit an applied migration.
3. Repository in `packages/db/src/repos/<name>.ts` implementing the core port; every method takes `ctx` and filters by `ctx.workspaceId` via the base helper.
4. Integration tests (real Postgres): CRUD happy path + **cross-tenant test**: create in workspace A, attempt read/update/delete/list from workspace B → not found / empty, nothing modified.
5. Shared (non-workspace) tables (company hub, analysis cache) must contain no workspace data — add a test asserting the column set.
