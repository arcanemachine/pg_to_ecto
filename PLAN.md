# Plan

Purpose: this file points agents to the current PgToEcto lifecycle state. Keep it light. Detailed active-phase scope and task packets belong under `plans/`; durable process guidance belongs in `AGENTS.md` and `.agents/roles/`.

## Current status

Phase 6 (Managed Regeneration and File Application), Phase 7 (Mix-task UX and Documentation), and Phase 8 (Wave 1 and `0.1.0` Readiness) are implementation-complete, verified, accepted, and integrated.

Phase 9 (`0.1.0` Release) local release commit and lightweight tag are complete at `6b7eac4` / `v0.1.0`; the public `pg_to_ecto` `0.1.0` publication has been reported.

Phase 10 (`pg_to_ecto` Retirement and `postgres_to_ecto` Rename) is locally release-ready under the approved Architect-direct route and intermediate-acceptance waiver. Task 10.1 is complete at release commit `5b7bb22` / tag `v0.1.1`. Task 10.2 is complete, verified, and architecture-accepted; release commit `chore: release v0.1.2` and lightweight tag `v0.1.2` form the renamed-package boundary. The checkout is `/workspace/projects/postgres_to_ecto`. No compatibility aliases or automatic old-format handling are included. User-owned remote repository rename, pushes, package publication, and old-version retirement remain.

The accepted Phase 6/7 tree and reset-safe coordination artifacts are committed. Preserve the accepted behavior and do not reset, clean, discard, or overwrite it.

The tracked files `demo/lib/postgres_to_ecto_demo/customer.ex`, `demo/lib/postgres_to_ecto_demo/order.ex`, and `demo/lib/postgres_to_ecto_demo/invoice.ex` are the renamed accepted canonical outputs. Preserve them as integrated review evidence; do not delete or overwrite them outside the generator's managed-region contract.

## Current owner

User, for the public repository rename, pushes, Hex publications, and Hex retirement actions.

## Next intended owner

Architect, for credential-free post-publication verification after the user reports completing the remote sequence.

## Next intended action

User follows the exact remote sequence in `plans/phase-10-package-rename/README.md`: rename the public repository, update `origin`, push `main` plus tags `v0.1.1` and `v0.1.2`, publish and verify `postgres_to_ecto` `0.1.2`, publish `pg_to_ecto` `0.1.1` from its tag, and retire old versions `0.1.0` and `0.1.1`. Agents do not perform these credential-bearing operations.

## Current gates

- Phase 9 planning and the standard coordinated route were approved; local release commit `6b7eac4` and lightweight tag `v0.1.0` are complete.
- The published status of `pg_to_ecto` `0.1.0` was reported by Sergeant; exact post-publication verification is not yet recorded.
- Phase 10's `pg_to_ecto` `0.1.1` no-code retirement patch, in-place rename, `postgres_to_ecto` `0.1.2` continuation, no-alias posture, and Hex retirement sequence are user-approved.
- The execution-ready plan and two task packets are complete; Architect-direct coordination is approved.
- Task 10.1 is complete, verified, and architecture-accepted. Local release commit `5b7bb22` and lightweight tag `v0.1.1` are complete.
- The local checkout rename to `/workspace/projects/postgres_to_ecto` is complete; the remote URL remains unchanged pending the user-owned repository rename.
- Task 10.2 is complete, verified, and architecture-accepted under the user's separate-intermediate-acceptance waiver. Its local release commit and lightweight tag are complete.
- Both local release boundaries are ready for user-owned remote operations.
- The user approved the complete plan and expressly waived separate intermediate acceptance prompts through both local release-ready states.
- Remote repository rename, Git pushes, Hex publication, package retirement, credential use, and other irreversible remote actions remain user-owned and are not authorized for agents.
- Coordination-document centralization under `/workspace/projects/_plans` remains separate and unapproved for this phase.
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

Task 10.1 acceptance on 2026-09-26 confirmed a documentation-and-metadata-only `pg_to_ecto` `0.1.1` patch. Root formatting, warnings-as-errors compilation, 64 tests, documentation generation, and diff checks passed. Demo formatting, warnings-as-errors compilation, and 31 disposable-PostgreSQL tests passed. Runtime source and dependencies are unchanged from `v0.1.0`. The exact archive contained only intended package files, had checksum `8c3a2845056679da20f9f4639864cc102c4ca8470daf2c502fdbf5b76e01c55c`, and was removed after inspection.

Task 10.2 architecture acceptance on 2026-09-26 confirmed a direct rename with unchanged behavior, dependencies, supported capability, PostgreSQL source authority, and safety posture. Root formatting, warnings-as-errors compilation, 65 tests, documentation generation, and diff checks passed. Demo formatting, warnings-as-errors compilation, 31 disposable-PostgreSQL tests, and database cleanup passed. The rename audit found old identifiers only in migration guidance, immutable history, and migration-proof test literals. The exact `postgres_to_ecto` `0.1.2` archive contained only intended package files, had checksum `2c0068b3e90f74554eb0e5d6339e5f4f895a9fe7b08effcfe25db60df7f8129f`, and was removed after inspection.

These are recovery facts, not substitutes for the remaining user-owned public-release gates.

## Authoritative pointers

- Project coordination and role guidance: `AGENTS.md`
- Approved Phase 9 plan: `plans/phase-9-release/README.md`
- Ready release-documentation task: `plans/phase-9-release/task-01-release-documentation.md`
- Accepted release-candidate documentation: `README.md` and `CHANGELOG.md`
- Active Phase 10 rename and retirement plan: `plans/phase-10-package-rename/README.md`
- Completed Task 10.1 packet: `plans/phase-10-package-rename/task-01-retirement-patch.md`
- Completed Task 10.2 packet: `plans/phase-10-package-rename/task-02-in-place-rename.md`

## Authority boundaries

No current authority exists for:

- discarding or rewriting accepted work;
- work outside the approved Phase 10 plan and route;
- remote tags, Git pushes, Hex publication, release publication, or credential use by an agent;
- Wave 2 or later capability work;
- company-system, company-data, or non-disposable database access.

If this file, the working tree, or user instructions disagree materially, stop and ask the user.
