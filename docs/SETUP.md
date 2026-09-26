# Setup

Day-to-day operation is in `RUNBOOK.md`. This file lists accounts and keys, and how to work locally if you ever want to.

## Needed to build: nothing

The whole product runs on fake adapters. No API keys are required for Phases A and B. Cloud sessions already provide Node, pnpm, PostgreSQL 16, Redis, Docker and Playwright's Chromium (via the setup script).

## Working locally (optional)

Requirements: Git, Docker Desktop, Node (current LTS), pnpm via `corepack enable`, Claude Code CLI.

```bash
git clone git@github.com:gurmeetgold/Pivot-TailorResume.git pivot && cd pivot
cp .env.example .env
docker compose -f infra/docker-compose.yml up -d
pnpm install && pnpm db:migrate && pnpm db:seed && pnpm dev
```

`claude --teleport` pulls a running cloud session into the local terminal; `claude --cloud "<task>"` pushes a new task the other way.

## Accounts and keys, in the order they are needed

| Item | Needed for | When |
| --- | --- | --- |
| Anthropic API key + model IDs | `eval:quality`, real tailoring | Before beta testing (fakes until then) |
| Stripe test keys | Real checkout in A07/B12 | Before charging |
| Neon/Supabase, Railway/Fly, Vercel | Deployment | Before beta |
| Cloudflare R2 bucket | Prod file storage | Before beta |
| Resend + domain DNS | Email | Before beta (B12) |
| Google OAuth client | "Sign in with Google" | Before beta |
| Brave Search API key | Connection Finder | Phase E |
| Chrome Web Store account | Extension | Phase C |
| Apple Developer + Xcode | Safari extension | Phase C06 |
| Voice provider keys | Voice mode | Phase F |
| PostHog, Sentry | Analytics, errors | Before beta |
| Product name, domain, logo, brand colors | Branding (swap tokens in `packages/ui/themes/pivot.css`) | Anytime |
| Privacy policy, terms, UGC policy, legal review of referral fees | Launch compliance | Before public launch |

## Decisions waiting on you

`docs/PROGRESS.md` → "Needs founder". Two proposed ADRs touch TRUTH_RULES and need a yes or no: **ADR-011** (digit-bearing tokens like "ISO 27001") and **ADR-014** (additions may not use ownership verbs; no bulk-accept in Enforced mode).
