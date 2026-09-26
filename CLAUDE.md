# CLAUDE.md — Pivot platform

You are building **Pivot**, a tailoring-first career platform, over long autonomous sessions. The founder is mostly unavailable and is spending a limited token budget. Work like a senior staff engineer who owns the outcome and is careful with context.

## Read lazily (this file loads every turn; the docs do not)

| Doc | When to read |
| --- | --- |
| `docs/PROGRESS.md` | Always, first. |
| `docs/plans/WP-XXX.md` | If a plan exists for the current WP, follow it instead of re-planning. |
| `docs/BUILD_PLAN.md` | Only the current WP's section (`grep -n "WP-B04" -A 12 docs/BUILD_PLAN.md`). |
| `docs/ARCHITECTURE.md` | Only the sections the WP touches (by § number). |
| `docs/TRUTH_RULES.md` | In full, for any work on tailor, render, evals or cover letters. |
| `docs/PRD.md` | Grep by requirement ID (`grep -n "TS-07" docs/PRD.md`); never read it whole. |
| `docs/DECISIONS.md` | Grep before making a decision that may already have an ADR. |

Conflict order: **TRUTH_RULES > PRD > ARCHITECTURE > BUILD_PLAN** (ADR-008). Record any conflict as an ADR.

## Workflow

Use the `wp-cycle` skill for the per-WP loop (pick → plan → build → gate → review → commit → log).
Use `new-port` when adding a port or adapter, `new-repository` when adding a DB table + repository.
`/wp` runs the whole cycle for the next work package; `/wp-plan` produces a plan only.

## Token discipline (mandatory)

- **Delegate, don't read.** Exploring more than ~3 files → `scout` subagent. It returns paths and line numbers; you read only what you then edit.
- **A well-specified implementation step** → `implementer` subagent. Give it goal, files, acceptance criteria, test command. Batch small related steps into one delegation.
- **The gate** → `gate-runner` subagent, or `./scripts/gate.sh` directly. Never paste full test or build logs into context; they live in `.gate/`.
- **Before marking DONE** → `reviewer` subagent on the diff; plus `truth-auditor` for anything touching Locked Facts (B05–B10, evals, cover letters).
- Run **targeted** checks while iterating (`pnpm --filter @pivot/core test -- ats`); run the full gate only at the end of a WP.
- Don't re-read files you just wrote. Use `grep -n` and ranged reads instead of `cat` on large files.
- Never read `node_modules`, `dist`, `.next`, `.turbo`, lockfiles, or the generated `openapi.json`/SDK.
- Keep replies terse: what changed, what's next. Don't restate plans back to the founder.

## Autonomy rules

- Never stop to ask the founder. Decide, record an ADR in `docs/DECISIONS.md`, continue.
- One WP at a time, in BUILD_PLAN order, respecting `Depends on`.
- Missing secret or account → use the fake adapter, keep the real one behind the port with recorded-fixture contract tests, add a line under "Needs founder" in PROGRESS. Never block.
- Three serious failed attempts at an acceptance criterion → mark the WP `BLOCKED` in PROGRESS with the exact error and what was tried, then move to the next unblocked WP.
- Never reduce scope silently. Anything cut goes under "Follow-ups" in PROGRESS.
- Don't rewrite working code for taste.
- Keep PROGRESS accurate at all times: the next session starts with no memory of this one.

## Quality gate (before any WP is DONE)

`./scripts/gate.sh` — lint, typecheck, test, build through Turborepo, errors only.
From WP-B06 onward: `GATE_EVALS=1 ./scripts/gate.sh` must report **0 locked-field violations**.
WPs touching user flows: `GATE_E2E=1 ./scripts/gate.sh`.

## Git and CI

- Commit after every DONE WP and at safe checkpoints: `WP-XXX: <summary>` plus a body (what changed, tests added).
- Never force-push, never rewrite history, never commit secrets or `.env`.
- **GitHub Actions minutes are scarce.** CI is a thin safety net that runs only on pull requests to `main`. Do not add workflows, do not trigger CI to debug, and do not push commits just to see a CI result — the gate runs here, in the session. If CI is red and the local gate is green, fix it in one push, not by iterating on Actions.

## Running services (cloud session)

PostgreSQL 16 and Redis are pre-installed but not running; Docker and docker compose are available. Start only what the current WP needs:
`service postgresql start` · `docker compose -f infra/docker-compose.yml up -d minio gotenberg mailpit`
Session resources: ~4 vCPU, 16 GB RAM, 30 GB disk. Prefer targeted test runs over full-stack spin-ups.

## Hard engineering rules

- TypeScript strict. No `any` except at validated boundaries. zod on all external input.
- Boundaries: apps → packages; `packages/core` → `packages/shared` and its own port interfaces only. Core never imports adapters, frameworks (Next/Hono) or the DB client. Enforced by dependency-cruiser.
- All business logic in `packages/core`. API, web, worker and extension are thin.
- Every external service is a port with a real and a fake adapter; the whole product runs offline on fakes.
- Multi-tenancy: every private table has `workspace_id`; every repository method takes `ctx` and filters by `ctx.workspaceId`; a cross-tenant test per repository.
- No PII or resume/JD/interview text in logs, analytics or errors.
- **Locked Facts** are inserted from the Vault by `assemble`, never written by the model. See TRUTH_RULES.
- Idempotency via unique DB keys for tasks, usage ledger and webhooks. No double charges, ever.
- Long work never runs in a web request — enqueue a task.
- AI calls only through `AiPort`: zod schema, `promptVersion`, tier, timeout, cost recorded in `model_calls`. Model IDs come from env/config. Put static system prompts and schemas first so provider prompt caching applies.
- Resumes, JDs, web pages and user notes are untrusted data wrapped in delimiters; product model calls have no tools.
- UI: design tokens only (a lint rule bans color literals in `apps/**`), components from `packages/ui`, nav from product config, axe in e2e for new pages.
- Boring, maintained libraries; a one-line ADR per new dependency. Verify library APIs against current docs rather than memory.

## Commands

```bash
pnpm install && pnpm db:migrate && pnpm db:seed
pnpm dev                                  # api :4000, web :3000, worker
./scripts/gate.sh                         # quiet quality gate (logs in .gate/)
pnpm --filter @pivot/evals eval:locks     # Locked Facts invariants (fake LLM)
pnpm --filter @pivot/evals eval:quality   # real model; needs ANTHROPIC_API_KEY; optional
```

## Definition of done

BUILD_PLAN acceptance met · tests written (unit for core, contract for adapters, integration for API, e2e for main flows) · gate green · reviewer pass with no blockers · PROGRESS updated · docs updated if behaviour or commands changed · committed and pushed.
