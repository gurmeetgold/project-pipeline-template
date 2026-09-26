---
description: Build the next work package end to end (plan, implement, gate, review, commit)
---
Run the `wp-cycle` skill for the next work package.

Start by reading `docs/PROGRESS.md`. Pick the WP that is `IN_PROGRESS`, or the first `TODO` whose dependencies are all `DONE`. If `docs/plans/<WP>.md` already exists, follow it instead of planning again.

Then implement it to its acceptance criteria, delegating to the `implementer`, `scout`, `gate-runner`, `reviewer` and (for Locked Facts work) `truth-auditor` subagents as the skill describes. Finish by updating `docs/PROGRESS.md`, adding any ADRs, committing and pushing.

Do exactly one work package in this session. When it is DONE and committed, say so and stop — the founder starts a fresh session for the next one.
