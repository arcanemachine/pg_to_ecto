# Plan

Purpose: this file points agents to the current PgToEcto lifecycle state. Keep it light. Detailed active-phase scope and task packets belong under `plans/`; durable process guidance belongs in `AGENTS.md` and `.agents/roles/`.

## Current status

Phase 6 (Managed Regeneration and File Application) and Phase 7 (Mix-task UX and Documentation) are implementation-complete, verified, accepted, and integrated. The user explicitly accepted the Phase 7 CLI behavior, including Mix-native ANSI colors and the green `No changes required.` successful no-op message.

The accepted Phase 6/7 tree and reset-safe coordination artifacts are committed. Preserve the accepted behavior and do not reset, clean, discard, or overwrite it.

The tracked files `demo/lib/pg_to_ecto_demo/customer.ex`, `demo/lib/pg_to_ecto_demo/order.ex`, and `demo/lib/pg_to_ecto_demo/invoice.ex` are the accepted Phase 8 canonical outputs. Preserve them as integrated review evidence; do not delete or overwrite them outside the generator’s managed-region contract.

Phase 8 (Wave 1 and `0.1.0` Readiness) is closed. User acceptance and bounded architecture acceptance are complete, and the `0.1.0` readiness candidate is accepted for release consideration. Release, publication, and tagging remain separately gated.

## Current owner

Architect, for next-direction review.

## Next intended owner

Architect, for direction review before any future capability work.

## Next intended action

Architect reviews the next substantive candidate and its gate. No Wave 2 work is activated automatically. Do not tag, publish, or release.

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

## Durable coordination pointers

- Project coordination and role guidance: `AGENTS.md`
- Accepted release-candidate documentation: `CHANGELOG.md`
- Closed Phase 8 evidence: preserved in the accepted tree, verification history, and commit history

## Authority boundaries

No current authority exists for:

- discarding or rewriting accepted work;
- commits beyond the accepted integration and separately authorized task work;
- tags, Hex publication, release publication, or version release actions;
- Wave 2 or later capability work;
- company-system, company-data, or non-disposable database access.

If this file, the working tree, or user instructions disagree materially, stop and ask the user.
