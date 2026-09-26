# Plan

Purpose: this file points agents to the current PgToEcto lifecycle state. Keep it light. Detailed active-phase scope and task packets belong under `plans/`; durable process guidance belongs in `AGENTS.md` and `.agents/roles/`.

## Current status

Phase 6 (Managed Regeneration and File Application), Phase 7 (Mix-task UX and Documentation), and Phase 8 (Wave 1 and `0.1.0` Readiness) are implementation-complete, verified, accepted, and integrated.

Phase 9 (`0.1.0` Release) planning is complete and execution-ready under the approved standard coordinated route. Task 9.1 release-document preparation is complete, verified, user-accepted, and architecture-accepted. The local release commit and lightweight tag are complete; user-owned public release actions remain. The approved manual release process consists of final documentation, full verification, exact Hex archive inspection, user and architecture acceptance, a `chore: release v0.1.0` release commit, a lightweight `v0.1.0` tag, and user-owned remote pushes and Hex publication. No GitHub Release or release automation is included.

The accepted Phase 6/7 tree and reset-safe coordination artifacts are committed. Preserve the accepted behavior and do not reset, clean, discard, or overwrite it.

The tracked files `demo/lib/pg_to_ecto_demo/customer.ex`, `demo/lib/pg_to_ecto_demo/order.ex`, and `demo/lib/pg_to_ecto_demo/invoice.ex` are the accepted Phase 8 canonical outputs. Preserve them as integrated review evidence; do not delete or overwrite them outside the generator's managed-region contract.

## Current owner

User, for the public push and Hex publication actions.

## Next intended owner

Sergeant, for post-publication verification after the user reports completion.

## Next intended action

User pushes the release commit and lightweight tag, then publishes `pg_to_ecto` `0.1.0` to Hex. Sergeant must not perform remote actions or access credentials.

## Current gates

- Phase 9 planning and the standard coordinated route are approved.
- Task 9.1 is complete, verified, user-accepted, and architecture-accepted.
- The approved route authorizes the planning handoff commit, routine in-plan dispatch, accepted integration commits, and the local lightweight tag after the plan's acceptance gates.
- User acceptance disposition: approved. Architecture acceptance disposition: approved. Local release commit `6b7eac4` and lightweight tag `v0.1.0` are complete.
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

Phase 9 architecture acceptance revalidated the release candidate on 2026-09-26. Root formatting, warnings-as-errors compilation, 64 tests, and documentation generation passed. Demo formatting, warnings-as-errors compilation, and 31 tests passed against disposable PostgreSQL. `git diff --check` passed. The exact Hex archive contained only the intended library and package files, had checksum `a91e2f8639ca4c5fb083b35ef2af1c5ca2218770d17a8a39fe838911acee55f7`, and was removed after inspection. The public Hex registry did not contain `pg_to_ecto` when rechecked. The working tree was clean before the acceptance-state edits.

These are recovery facts, not substitutes for the remaining local closeout and user-owned public-release gates.

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
