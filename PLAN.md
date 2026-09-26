# Plan

Purpose: this file points agents to the current PgToEcto lifecycle state. Keep it light. Detailed active-phase scope and task packets belong under `plans/`; durable process guidance belongs in `AGENTS.md` and `.agents/roles/`.

## Current status

Phase 6 (Managed Regeneration and File Application), Phase 7 (Mix-task UX and Documentation), and Phase 8 (Wave 1 and `0.1.0` Readiness) are implementation-complete, verified, accepted, and integrated.

Phase 9 (`0.1.0` Release) planning is complete and execution-ready under the approved standard coordinated route. Task 9.1 release-document preparation is in progress under Sergeant coordination. The approved manual release process consists of final documentation, full verification, exact Hex archive inspection, user and architecture acceptance, a `chore: release v0.1.0` release commit, a lightweight `v0.1.0` tag, and user-owned remote pushes and Hex publication. No GitHub Release or release automation is included.

The accepted Phase 6/7 tree and reset-safe coordination artifacts are committed. Preserve the accepted behavior and do not reset, clean, discard, or overwrite it.

The tracked files `demo/lib/pg_to_ecto_demo/customer.ex`, `demo/lib/pg_to_ecto_demo/order.ex`, and `demo/lib/pg_to_ecto_demo/invoice.ex` are the accepted Phase 8 canonical outputs. Preserve them as integrated review evidence; do not delete or overwrite them outside the generator's managed-region contract.

## Current owner

Worker, for Task 9.1 release-document preparation under Sergeant coordination.

## Next intended owner

Sergeant, for Task 9.1 review and deterministic verification after the Worker reports completion.

## Next intended action

Worker completes `plans/phase-9-release/task-01-release-documentation.md` and reports evidence to Sergeant. The approved route authorizes routine in-plan sequencing and integration commits without another confirmation round.

## Current gates

- Phase 9 planning and the standard coordinated route are approved.
- Task 9.1 is in progress with the dispatched Worker; Sergeant owns review and sequencing.
- The approved route authorizes the planning handoff commit, routine in-plan dispatch, accepted integration commits, and the local lightweight tag after the plan's acceptance gates.
- User acceptance and architecture acceptance remain required at the points defined by the phase plan.
- Git pushes, Hex publication, release publication, credential use, and other irreversible remote actions remain user-owned and are not authorized for agents.
- Wave 2 or later capability work is not activated.

## Accepted verification evidence

The Phase 8 accepted tree passed:

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

During Phase 9 planning, `mix hex.build` successfully built the configured `0.1.0` package and the generated archive was removed. The public Hex registry did not contain `pg_to_ecto` at the time checked. Both facts must be revalidated during execution.

These are recovery facts, not substitutes for the Phase 9 release gates.

## Authoritative pointers

- Project coordination and role guidance: `AGENTS.md`
- Approved Phase 9 plan: `plans/phase-9-release/README.md`
- Ready release-documentation task: `plans/phase-9-release/task-01-release-documentation.md`
- Accepted release-candidate documentation: `README.md` and `CHANGELOG.md`

## Authority boundaries

No current authority exists for:

- discarding or rewriting accepted work;
- work outside the approved Phase 9 plan and route;
- remote tags, Git pushes, Hex publication, release publication, or credential use by an agent;
- Wave 2 or later capability work;
- company-system, company-data, or non-disposable database access.

If this file, the working tree, or user instructions disagree materially, stop and ask the user.
