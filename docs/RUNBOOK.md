# Runbook — how the founder runs the build

Everything happens at **claude.ai/code** (Claude Code on the web). No local machine is needed.

## Once, at the start

1. **Connect GitHub.** claude.ai/code → connect the Claude GitHub App to `gurmeetgold/Pivot-TailorResume`.
2. **Create the cloud environment.** Cloud icon above the message box → environment settings.
   - Network access: **Trusted** (covers npm, GitHub, Docker Hub).
   - Setup script: paste the contents of `scripts/cloud-setup.sh`.
   - Environment variables: leave empty for now. Do **not** put `ANTHROPIC_API_KEY` there — a key in the environment is billed as metered API usage instead of the subscription, and the build runs on fake AI anyway.
3. **Push this pack** to the repo's default branch so every session clones it.

## Each build session (one work package)

1. New session → repository `Pivot-TailorResume`, branch `main`.
2. Set the model: type `/model opus` and then use **plan mode** for a WP that needs design (A01, A03, A05, A06, B04, B05, B06, B08); otherwise `/model sonnet`.
3. Message: `/wp` (or paste `KICKOFF.md`).
4. Watch the first few minutes, then close the tab — the session keeps running and you can check it from the Claude app.
5. When it finishes: open the diff, create the PR, let CI run once, merge.
6. **Start a new session for the next WP.** Don't continue in the old one; `/clear` doesn't exist in cloud sessions and a fresh session is the cheapest way to reset context.

Split runs for the heavier WPs: session 1 is `/wp-plan` on Opus (writes `docs/plans/<WP>.md`, no code), session 2 is `/wp` on Sonnet (executes the plan). This is the Opus-plans/Sonnet-builds pattern, done with two sessions instead of one.

## Unattended runs

Create a routine at **claude.ai/code/routines**:
- Prompt: the contents of `KICKOFF.md`.
- Repository: `Pivot-TailorResume`; environment: the one above.
- Trigger: schedule (minimum interval one hour). Routines run with no approval prompts and count against the daily run allowance.

Start with one scheduled run per night while the build is young, and review the PR each morning before queuing more. Routines run as full sessions, so the same one-WP-per-run rule applies.

## Cost and limits

- Settings → Usage shows the remaining allowance. Check it before queuing parallel work; every session draws on the same pool.
- Subagent models: `scout` and `gate-runner` on Haiku, `implementer` and `reviewer` on Sonnet, `truth-auditor` on Opus. Leave `CLAUDE_CODE_SUBAGENT_MODEL` unset — it overrides all of those.
- GitHub Actions runs only on pull requests to `main`. Don't ask Claude to trigger or re-run workflows; the gate runs in the session.

## Checkpoints where founder review matters

| After | Why |
| --- | --- |
| A01 | Repo shape, boundaries, gate all set for everything after it. |
| A05 | Ports and fakes determine how testable the rest is. |
| B05 | Templates and rendering are what the user actually receives. |
| B06 | The Locked Facts pipeline is the product promise — read `docs/plans/WP-B06.md` before the build session. |
| B09 | First end-to-end loop: import → composer → batch → review → download. |
