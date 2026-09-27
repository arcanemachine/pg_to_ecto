# Plan

Purpose: this file points agents to the current PostgresToEcto lifecycle state. Keep it light. Detailed active-phase scope and task packets belong under `plans/`; durable process guidance belongs in `AGENTS.md` and `.agents/roles/`.

## Current status

Phases 6–8 are implementation-complete, verified, accepted, and integrated. The original `pg_to_ecto` `0.1.0` release is published and preserved by release commit `6b7eac4` and lightweight tag `v0.1.0`.

Phase 10 (`pg_to_ecto` Retirement and `postgres_to_ecto` Rename) is locally complete. Task 10.1 produced the no-code `pg_to_ecto` `0.1.1` retirement release at local commit `5b7bb22` / tag `v0.1.1`. Task 10.2 produced the direct `postgres_to_ecto` `0.1.2` rename release at local commit `4cd6117` / tag `v0.1.2`. Root, docs, disposable-PostgreSQL, rename-audit, archive, and architecture-acceptance gates passed.

Hex publication and retirement are publicly visible:

- `postgres_to_ecto` `0.1.2` is published with HexDocs and the accepted checksum.
- `pg_to_ecto` `0.1.1` is published with HexDocs.
- `pg_to_ecto` `0.1.0` and `0.1.1` are retired with reason `renamed` and direct users to `postgres_to_ecto`.

The remaining release-integrity gap is GitHub synchronization. The public repository has been renamed to `arcanemachine/postgres_to_ecto`, but public `main` still points to coordination commit `0423a22` and exposes the old `pg_to_ecto` `0.1.0` source. Public tags `v0.1.1` and `v0.1.2` are absent. The local branch contains the accepted commits and tags, but this container has no configured GitHub write authentication.

The tracked files `demo/lib/postgres_to_ecto_demo/customer.ex`, `demo/lib/postgres_to_ecto_demo/order.ex`, and `demo/lib/postgres_to_ecto_demo/invoice.ex` are the accepted renamed canonical outputs. Preserve them as integrated review evidence and only update them through the managed-region contract.

## Current owner

User, for authenticated GitHub synchronization from a credentialed environment.

## Next intended owner

Architect, for credential-free public source/tag verification and final lifecycle closeout after the push succeeds.

## Next intended action

From `/workspace/projects/postgres_to_ecto`, authenticate GitHub, set `origin` to `git@github.com:arcanemachine/postgres_to_ecto.git` or its authenticated HTTPS equivalent, push `main`, and push lightweight tags `v0.1.0`, `v0.1.1`, and `v0.1.2`. Then Architect verifies that public `main`, tags, source links, Hex packages, HexDocs, and retirement messages agree.

## Current gates

- The Phase 10 plan and Architect-direct execution route are approved.
- The user waived separate intermediate acceptance prompts and authorized execution through both local release-ready boundaries.
- Task 10.1 and Task 10.2 are complete, verified, and architecture-accepted.
- Local release commits and lightweight tags `v0.1.1` and `v0.1.2` are complete.
- Both Hex publications and both old-version retirements are publicly verified.
- GitHub synchronization is blocked only by absent write authentication in this container.
- No authority exists for work outside the accepted Phase 10 scope, Wave 2 capability work, or company/non-disposable database access.

## Accepted verification evidence

Task 10.1 (`pg_to_ecto` `0.1.1`) passed root formatting, warnings-as-errors compilation, 64 tests, documentation generation, diff checks, demo formatting/compilation, and 31 disposable-PostgreSQL tests. Runtime source and dependencies are unchanged from `v0.1.0`. The exact inspected archive checksum was `8c3a2845056679da20f9f4639864cc102c4ca8470daf2c502fdbf5b76e01c55c`.

Task 10.2 (`postgres_to_ecto` `0.1.2`) passed root formatting, warnings-as-errors compilation, 65 tests, documentation generation, diff checks, demo formatting/compilation, 31 disposable-PostgreSQL tests, database cleanup, rename audit, and exact archive inspection. The exact archive checksum was `2c0068b3e90f74554eb0e5d6339e5f4f895a9fe7b08effcfe25db60df7f8129f`, matching the public Hex release checksum.

Public Hex verification on 2026-09-27 confirmed:

- `postgres_to_ecto` `0.1.2`, HexDocs present, checksum `2c0068b3e90f74554eb0e5d6339e5f4f895a9fe7b08effcfe25db60df7f8129f`;
- `pg_to_ecto` `0.1.1`, HexDocs present, retired with reason `renamed`;
- `pg_to_ecto` `0.1.0`, HexDocs present, retired with reason `renamed`;
- the public `pg_to_ecto` `0.1.1` package file contents match local tag `v0.1.1`; its published tar checksum differs because archive packaging metadata differs.

## Authoritative pointers

- Project coordination and role guidance: `AGENTS.md`
- Active Phase 10 plan: `plans/phase-10-package-rename/README.md`
- Completed Task 10.1 packet: `plans/phase-10-package-rename/task-01-retirement-patch.md`
- Completed Task 10.2 packet: `plans/phase-10-package-rename/task-02-in-place-rename.md`
- Public replacement package: `https://hex.pm/packages/postgres_to_ecto`
- Public retired package: `https://hex.pm/packages/pg_to_ecto`
- Public source repository: `https://github.com/arcanemachine/postgres_to_ecto`

If this file, the working tree, public state, or user instructions disagree materially, stop and report the conflict.
