# Plan

Purpose: this file points agents to the current PgToEcto lifecycle state. Keep it light. Detailed active-phase scope and task packets belong under `plans/`; durable process guidance belongs in `AGENTS.md` and `.agents/roles/`.

## Current status

Phase 6 (Managed Regeneration and File Application), Phase 7 (Mix-task UX and Documentation), and Phase 8 (Wave 1 and `0.1.0` Readiness) are implementation-complete, verified, accepted, and integrated.

Phase 9 (`0.1.0` Release) local release commit and lightweight tag are complete at `6b7eac4` / `v0.1.0`; the public `pg_to_ecto` `0.1.0` publication has been reported.

Phase 10 (`pg_to_ecto` Retirement and `postgres_to_ecto` Rename) planning is complete and execution-ready. The phase first prepares a no-code `pg_to_ecto` `0.1.1` retirement release, then renames the existing project in place and releases `postgres_to_ecto` `0.1.2`. Version history continues in one repository; no compatibility aliases or automatic old-format handling are included. After the replacement is public and verified, the user publishes the old retirement patch and retires both old Hex versions with reason `renamed`.

The accepted Phase 6/7 tree and reset-safe coordination artifacts are committed. Preserve the accepted behavior and do not reset, clean, discard, or overwrite it.

The tracked files `demo/lib/pg_to_ecto_demo/customer.ex`, `demo/lib/pg_to_ecto_demo/order.ex`, and `demo/lib/pg_to_ecto_demo/invoice.ex` are the accepted Phase 8 canonical outputs. Preserve them as integrated review evidence; do not delete or overwrite them outside the generator's managed-region contract.

## Current owner

Architect, for direct Phase 10 execution coordination.

## Next intended owner

A fresh Worker, for Task 10.1 (`pg_to_ecto` `0.1.1` retirement-patch preparation).

## Next intended action

Architect commits the reset-safe planning handoff and dispatches Task 10.1 to a fresh Worker. Architect then reviews, corrects, verifies, and sequences the approved tasks without per-task approval. The only planned user-facing execution gates are acceptance of each exact publishable release candidate and the final user-owned remote operations.

## Current gates

- Phase 9 planning and the standard coordinated route were approved; local release commit `6b7eac4` and lightweight tag `v0.1.0` are complete.
- The published status of `pg_to_ecto` `0.1.0` was reported by Sergeant; exact post-publication verification is not yet recorded.
- Phase 10's `pg_to_ecto` `0.1.1` no-code retirement patch, in-place rename, `postgres_to_ecto` `0.1.2` continuation, no-alias posture, and Hex retirement sequence are user-approved.
- The execution-ready plan and two task packets are complete; Architect-direct coordination is approved.
- The selected route authorizes the reset-safe planning handoff commit and ordinary in-plan dispatch, review, correction, verification, local release commits, and lightweight tags after their stated acceptance gates.
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

These are recovery facts, not substitutes for the remaining local closeout and user-owned public-release gates.

## Authoritative pointers

- Project coordination and role guidance: `AGENTS.md`
- Approved Phase 9 plan: `plans/phase-9-release/README.md`
- Ready release-documentation task: `plans/phase-9-release/task-01-release-documentation.md`
- Accepted release-candidate documentation: `README.md` and `CHANGELOG.md`
- Active Phase 10 rename and retirement plan: `plans/phase-10-package-rename/README.md`
- Ready Task 10.1 packet: `plans/phase-10-package-rename/task-01-retirement-patch.md`
- Blocked Task 10.2 packet: `plans/phase-10-package-rename/task-02-in-place-rename.md`

## Authority boundaries

No current authority exists for:

- discarding or rewriting accepted work;
- work outside the approved Phase 9 plan and route;
- remote tags, Git pushes, Hex publication, release publication, or credential use by an agent;
- Wave 2 or later capability work;
- company-system, company-data, or non-disposable database access.

If this file, the working tree, or user instructions disagree materially, stop and ask the user.
