# Plan

Purpose: this file points agents to the current PostgresToEcto lifecycle state. Keep it light. Detailed active-phase scope and task packets belong under `plans/`; durable process guidance belongs in `AGENTS.md` and `.agents/roles/`.

## Current status

Phases 6–8 are implementation-complete, verified, accepted, and integrated. Phase 9 published the original `pg_to_ecto` `0.1.0` release at commit `6b7eac4` / tag `v0.1.0`.

Phase 10 (`pg_to_ecto` Retirement and `postgres_to_ecto` Rename) is released and closed:

- `pg_to_ecto` `0.1.1` is published with retirement documentation from commit `5b7bb22` / tag `v0.1.1`.
- `postgres_to_ecto` `0.1.2` is published with documentation from commit `4cd6117` / tag `v0.1.2`.
- `pg_to_ecto` versions `0.1.0` and `0.1.1` are retired with reason `renamed` and direct users to `postgres_to_ecto`.
- GitHub repository `arcanemachine/postgres_to_ecto` exposes accepted `main` and lightweight tags `v0.1.0`, `v0.1.1`, and `v0.1.2`.
- Public source metadata, Hex package metadata, HexDocs availability, checksums, source links, and tags have been verified.

The tracked files `demo/lib/postgres_to_ecto_demo/customer.ex`, `demo/lib/postgres_to_ecto_demo/order.ex`, and `demo/lib/postgres_to_ecto_demo/invoice.ex` are the accepted renamed canonical outputs. Preserve them as integrated review evidence and only update them through the managed-region contract.

## Current owner

User, to select the next substantive product direction.

## Next intended action

No active implementation or release task remains. Wave 2 and other deferred capabilities remain inactive until the user promotes specific work.

## Current gates

- Phase 10 plan, implementation, verification, architecture acceptance, release commits, tags, publications, retirements, public verification, and closeout are complete.
- No compatibility aliases or automatic old-format handling were introduced.
- No authority exists for Wave 2 capability work, unrelated scope, or company/non-disposable database access.

## Accepted verification evidence

Task 10.1 (`pg_to_ecto` `0.1.1`) passed root formatting, warnings-as-errors compilation, 64 tests, documentation generation, diff checks, demo formatting/compilation, and 31 disposable-PostgreSQL tests. Runtime source and dependencies are unchanged from `v0.1.0`. The inspected local archive checksum was `8c3a2845056679da20f9f4639864cc102c4ca8470daf2c502fdbf5b76e01c55c`.

Task 10.2 (`postgres_to_ecto` `0.1.2`) passed root formatting, warnings-as-errors compilation, 65 tests, documentation generation, diff checks, demo formatting/compilation, 31 disposable-PostgreSQL tests, database cleanup, rename audit, and exact archive inspection. The archive checksum was `2c0068b3e90f74554eb0e5d6339e5f4f895a9fe7b08effcfe25db60df7f8129f`, matching the public Hex release.

Public verification on 2026-09-27 confirmed:

- GitHub `main` points to closeout commit `f6e07d3` and contains `postgres_to_ecto` `0.1.2` metadata;
- tags `v0.1.0`, `v0.1.1`, and `v0.1.2` point to `6b7eac4`, `5b7bb22`, and `4cd6117` respectively;
- `postgres_to_ecto` `0.1.2` has HexDocs and checksum `2c0068b3e90f74554eb0e5d6339e5f4f895a9fe7b08effcfe25db60df7f8129f`;
- `pg_to_ecto` `0.1.1` has HexDocs and is retired with reason `renamed`;
- `pg_to_ecto` `0.1.0` is retired with the same replacement message;
- the public `pg_to_ecto` `0.1.1` package file contents match local tag `v0.1.1`; its tar checksum differs because archive packaging metadata differs.

## Authoritative pointers

- Project coordination and role guidance: `AGENTS.md`
- Closed Phase 10 plan: `plans/phase-10-package-rename/README.md`
- Completed Task 10.1 packet: `plans/phase-10-package-rename/task-01-retirement-patch.md`
- Completed Task 10.2 packet: `plans/phase-10-package-rename/task-02-in-place-rename.md`
- Public replacement package: `https://hex.pm/packages/postgres_to_ecto`
- Public retired package: `https://hex.pm/packages/pg_to_ecto`
- Public source repository: `https://github.com/arcanemachine/postgres_to_ecto`

If this file, the working tree, public state, or user instructions disagree materially, stop and report the conflict.
