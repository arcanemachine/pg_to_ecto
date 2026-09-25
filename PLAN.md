# Plan

Purpose: this file points agents to the current PgToEcto lifecycle state. Keep it light. Detailed active-phase scope and task packets belong under `plans/`; durable process guidance belongs in `AGENTS.md` and `.agents/roles/`.

## Current status

Phase 6 (Managed Regeneration and File Application) and Phase 7 (Mix-task UX and Documentation) are implementation-complete, verified, accepted, and integrated. The user explicitly accepted the Phase 7 CLI behavior, including Mix-native ANSI colors and the green `No changes required.` successful no-op message.

The accepted Phase 6/7 tree and reset-safe coordination artifacts are committed. Preserve the accepted behavior and do not reset, clean, discard, or overwrite it.

The tracked files `demo/lib/pg_to_ecto_demo/customer.ex`, `demo/lib/pg_to_ecto_demo/order.ex`, and `demo/lib/pg_to_ecto_demo/invoice.ex` are the accepted Phase 8 canonical outputs. Preserve them as integrated review evidence; do not delete or overwrite them outside the generator’s managed-region contract.

Phase 8 (Wave 1 and `0.1.0` Readiness) has passed bounded architecture acceptance. Tasks 01–03 are complete, and the accepted readiness candidate is ready for Sergeant closeout.

## Current owner

Sergeant, for Phase 8 Task 04 closeout.

## Next intended owner

Architect, for direction review after Phase 8 closeout.

## Next intended action

Sergeant picks up `plans/08-wave-1-release-readiness/04-closeout.md` for closeout. Do not tag, publish, release, or begin Wave 2.

## Accepted verification evidence

The current accepted tree has passed:

- root format check;
- root warnings-as-errors compilation;
- root test suite with 64 tests;
- focused Mix-task suite with 7 tests;
- Mix-task discovery;
- demo format check;
- demo warnings-as-errors compilation;
- demo test suite with 31 tests against disposable PostgreSQL;
- deterministic demo output byte/mode restoration;
- diff check and post-test artifact cleanup.

These counts are recovery evidence, not a substitute for inspecting the current tree after reset.

## Active coordination pointers

- Project coordination and role guidance: `AGENTS.md`
- Phase 8 plan: `plans/08-wave-1-release-readiness/README.md`
- Phase 8 Worker task: `plans/08-wave-1-release-readiness/01-readiness-evidence.md`
- Phase 8 Sergeant review and user acceptance: `plans/08-wave-1-release-readiness/02-review-and-user-acceptance.md`
- Phase 8 Architect acceptance: `plans/08-wave-1-release-readiness/03-architecture-acceptance.md`
- Phase 8 Sergeant closeout: `plans/08-wave-1-release-readiness/04-closeout.md`

## Authority boundaries

No current authority exists for:

- discarding or rewriting accepted work;
- commits beyond the accepted integration and separately authorized task work;
- tags, Hex publication, release publication, or version release actions;
- Wave 2 or later capability work;
- company-system, company-data, or non-disposable database access.

If this file, the Phase 8 README, task packets, working tree, or user instructions disagree materially, stop and ask the user.
