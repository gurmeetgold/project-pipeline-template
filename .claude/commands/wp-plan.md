---
description: Plan the next work package only — no code changes
---
Read `docs/PROGRESS.md` and pick the next work package (the `IN_PROGRESS` one, else the first `TODO` whose dependencies are `DONE`).

Read only that WP's section of `docs/BUILD_PLAN.md` and the `docs/ARCHITECTURE.md` sections it names. If it touches tailoring, rendering or evals, read `docs/TRUTH_RULES.md` in full. Use the `scout` subagent for any lookups in the codebase.

Write the plan to `docs/plans/<WP>.md`, at most 30 lines: steps sized for one `implementer` call each, the files each step touches, the test that proves each acceptance criterion, risks, and any ADRs needed. Commit just that file.

Make no other changes to the repository.
