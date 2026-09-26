---
name: wp-cycle
description: The build loop for Pivot. Take the run lock, then chain work packages (plan, build, gate, review, land on claude/trunk) until a real stop condition, then release the lock. Use at the start of every build run.
---
# WP cycle

Checkpoint WPs: **A05, B05, B06, B09**. Phase boundary: stop after **B13** — never start Phase C.
You can only push branches starting with `claude/`. The trunk is `claude/trunk` (the repo default branch). Never push to `main`. Land work with `./scripts/land.sh`.

0. **Lock.** `./scripts/run-lock.sh acquire`. If it prints LOCKED → another run is working: end the session immediately, change nothing.
0b. **Land pending work first.** If any WP in PROGRESS is `LAND_PENDING`, handle those before anything else, one at a time: branch `claude/<wp>-land` from latest `origin/claude/trunk`; `git merge origin/<the branch named in its row>`. Resolve conflicts: `pnpm-lock.yaml` → take the trunk version, then `pnpm install` to regenerate; `pnpm-workspace.yaml` / `docs/*` → keep both sides; code → merge so both sides keep working. Then `./scripts/gate.sh`, `reviewer` on the merge diff, fix blockers, set the WP `DONE` in PROGRESS, `./scripts/land.sh <wp>`. Never rebuild a LAND_PENDING WP from scratch. Founder-approved checkpoints land like normal WPs.
1. **Pick.** From latest `origin/claude/trunk`, read `docs/PROGRESS.md`. Current WP = `IN_PROGRESS` with no open branch owner, else first `TODO` whose `Depends on` are all `DONE`. None eligible, or B13 DONE → step 8.
2. **Plan.** Follow `docs/plans/<WP>.md` if present; else read only that WP's BUILD_PLAN section (TRUTH_RULES in full for tailoring/render/evals) and write a plan of at most 30 lines there.
3. **Build** on branch `claude/<wp>` from latest `origin/claude/trunk`. Delegate steps to `implementer`, lookups to `scout`. Commit and push the branch at safe points. Run `./scripts/run-lock.sh beat` every ~30 minutes of work.
4. **Gate.** `./scripts/gate.sh` via `gate-runner` (`GATE_EVALS=1` from B06, `GATE_E2E=1` for user-flow WPs). Fix failures. If the gate prints a WARN that DATABASE_URL is unset or DB tests were skipped, that is a **failure**: run `bash scripts/session-start.sh`, confirm `psql "$DATABASE_URL" -c 'select 1'` works, and re-run the gate.
5. **Review.** `reviewer`; plus `truth-auditor` for B05–B10/evals. Fix every blocker, re-gate.
6. **Land.**
   - **Normal WP:** set it `DONE` in PROGRESS (1–3 line summary + session-log row), add ADRs, commit, then `./scripts/land.sh <wp>`. On CONFLICT: resolve, re-gate, commit, run it again. On TIMEOUT twice: mark BLOCKED with the reason, go to step 8.
   - **Checkpoint WP:** push `claude/<wp>`. Then from a fresh branch off `origin/claude/trunk`, set the WP `IN_REVIEW` in PROGRESS and add under "Needs founder": `merge claude/<wp>`. `./scripts/land.sh <wp>-review`. Go to step 8.
7. **Continue** at step 1 in this same session. Stop only for: a checkpoint, a WP BLOCKED after 3 serious attempts, nothing eligible, the phase boundary, or context large enough that another full WP risks an untidy cutoff (finish the current WP first).
8. **Release.** `./scripts/run-lock.sh release`. Report what landed and what's next.

Decisions: never ask the founder. Only two things wait for the founder — changes to TRUTH_RULES itself, and business calls (pricing, branding, legal wording). Write those as "Proposed" ADRs under "Needs founder" and continue with work that doesn't depend on them. Everything else: decide, write an "Accepted" ADR, continue.

**Founder alerts.** Send the founder a push notification (use your notification tool) whenever you: stop at a checkpoint WP (message: "ACTION NEEDED: <WP> ready for review on claude/<wp>"), add anything under "Needs founder" (message: "ACTION NEEDED: <one-line item>"), or mark a WP BLOCKED (message: "BLOCKED: <WP> — <reason>"). Also start your final report with the same "ACTION NEEDED:" line.

**Chaining.** After step 8 releases the lock: if you stopped only because your context was getting large (not a checkpoint, not BLOCKED, not nothing-eligible, not the phase boundary) and you landed at least one WP this session, run `./scripts/next-run.sh` so the next run starts immediately. Never run it in any other case.
