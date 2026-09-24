---
kind: phase-readme
title: Wave 1 and 0.1.0 Readiness
---

# Phase 8 — Wave 1 and `0.1.0` Readiness

Planning status: Complete and execution-ready  
Execution owner: Sergeant  
Execution status: Blocked on accepted-tree commit authority and explicit Phase 8 activation  
Route: Sergeant-coordinated phase with one fresh Worker for readiness evidence

## Purpose

Establish whether the implemented Wave 1 product is ready for `0.1.0` release consideration.

Phase 6 and Phase 7 provide the implemented generation, regeneration, CLI, diagnostics, safety, demo, and documentation surface. Phase 8 does not add a new capability wave. It turns the existing implementation into a complete, reviewable release-readiness candidate by producing canonical demo output, verifying the package archive and real PostgreSQL behavior, reconciling release-facing documentation, and presenting the full user acceptance surface.

```text
accepted Wave 1 implementation
  -> exact-tree verification and package inspection
  -> canonical generated output and safety demonstrations
  -> user acceptance
  -> architecture acceptance
  -> closeout or correction
```

## Why this is a separate phase

Release readiness spans generated schemas, the baseline migration, Mix-task behavior, real source-to-target PostgreSQL evidence, filesystem safety, package contents, documentation, user acceptance, architecture acceptance, and release boundaries. Automated tests alone cannot establish that the generated code and operator workflow are understandable or acceptable. Keeping this work separate prevents release preparation from silently expanding Wave 1 or granting publication authority.

## Current prerequisites

Phase 8 may not activate until:

1. the accepted Phase 6/7 implementation and reset-safe planning artifacts are committed with explicit authority;
2. the user explicitly authorizes Phase 8 activation and Task 01 dispatch;
3. Sergeant confirms one fresh Worker is available;
4. the source and target database names satisfy the disposable demo convention;
5. `POSTGRES_PASSWORD` is available without exposing it in logs or messages.

## Accepted input behavior

Phase 8 treats these behaviors as accepted inputs, not redesign opportunities:

- explicit profile, Repo, table, module, and optional file selection;
- one regenerable baseline migration;
- read-only PostgreSQL catalog introspection;
- mixed user/generated ownership and managed-key safety;
- force preflight and recovery semantics;
- Mix-task flags and safe verbose context;
- Mix-native output colors and successful no-op wording;
- actionable mapping, association, and unselected-reference diagnostics;
- required password and disposable database guards.

If evidence shows a defect, route a correction. Do not redesign accepted behavior merely because Phase 8 reviews it.

## Phase scope

Phase 8 includes:

- exact-tree root and demo verification;
- canonical demo schemas and baseline generation for review;
- proof that no-op regeneration stays clean;
- a safe synthetic regeneration demonstration after a fixture change;
- managed-key mismatch refusal and explicit force recovery;
- source-to-target structural conformance;
- independent PostgreSQL default, nullability, uniqueness, foreign-key, referential-action, schema reflection, insert/load, and preload checks;
- Hex archive construction and content inspection;
- README, demo documentation, package metadata, capability matrix, and Changelog reconciliation with verified behavior;
- a concise user acceptance trial;
- architecture acceptance and closeout.

## Explicit non-goals

Do not:

- add Wave 2 types, composite keys, checks, advanced indexes, arrays, generated columns, or other parity work;
- add PostgreSQL enums, domains, views, triggers, extensions, grants, or other native-object support;
- reconstruct historical or incremental migrations;
- add dependencies, plugins, registries, persistent snapshots, multi-Repo task orchestration, or new public APIs;
- publish to Hex, create a version tag, create a release, or change remote state;
- use company systems, data, schemas, services, or credentials;
- weaken the existing disposable-database or source-read-only contracts.

## Canonical demo output

Task 01 generates one canonical set of demo schema modules and confirms the checked-in baseline matches the source fixture. The files remain review candidates until user acceptance and integration authority are complete.

Tests that exercise destructive or malformed-output cases must continue to use ignored temporary paths or restore all pre-existing bytes and file modes. Ordinary verification must leave the working tree free of incidental generated artifacts except the deliberate canonical review candidates named by Task 01.

## Verification strategy

Required root evidence:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Required demo evidence:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix pg_to_ecto.generate --dry-run
```

Also require:

- `mix help pg_to_ecto.generate` task discovery;
- source and target database lifecycle evidence under safe disposable names;
- generator source-read-only evidence;
- generated schema compilation and reflection;
- source-to-target normalized catalog comparison;
- independent constraint/default/association behavior;
- no-op generation and working-tree cleanliness;
- unowned, malformed-key, mismatch, and force behavior;
- `git diff --check`;
- Hex archive content inspection.

Record exact commands and results. Do not report skipped checks as passing.

## User acceptance gate

User acceptance is required. The trial must state the working directory, prerequisites, exact commands, visible expected results, and cleanup.

The user must be able to inspect:

1. `demo/lib/pg_to_ecto_demo/profile.ex`;
2. generated Customer, Order, and Invoice schemas;
3. `demo/priv/repo/migrations/00001_pg_to_ecto.exs`, including user-owned code around `generated_change`;
4. normal, dry-run, verbose, warning, error, color, and no-change CLI output;
5. regeneration after a synthetic source fixture change;
6. managed-key refusal and force recovery while user-owned source survives;
7. representative unselected-reference and association-ambiguity warnings;
8. source-to-target conformance and independent behavior results;
9. the final Hex archive file list.

The recorded disposition must be `approved`, `waived by user`, `failed`, or `pending`. A failed trial returns to correction; tests do not override it.

## Architecture acceptance

After Sergeant review and user acceptance, Architect performs a bounded sanity pass covering:

- Wave 1 scope and explicit non-goals;
- PostgreSQL source authority and read-only behavior;
- canonical model and renderer boundaries;
- user/generated ownership and force safety;
- supported capability evidence and diagnostic honesty;
- package contents and dependency posture;
- documentation truthfulness;
- user acceptance disposition;
- release, publication, and Wave 2 boundaries.

Architecture acceptance does not publish or tag the package.

## Task sequence

| Task | Role | Status | Packet | Next |
| --- | --- | --- | --- | --- |
| 01 | Worker | pending | `01-readiness-evidence.md` | Sergeant reviews evidence and corrections |
| 02 | Sergeant | pending | `02-review-and-user-acceptance.md` | Architect acceptance if user approves |
| 03 | Architect | pending | `03-architecture-acceptance.md` | Sergeant closeout if accepted |
| 04 | Sergeant | pending | `04-closeout.md` | Phase closed; release actions remain separately gated |

Status values: `pending`, `in-progress`, `complete`, `blocked`, `needs-work`, `needs-review`.

## Dispatch and ownership

Sergeant is the execution owner and dispatcher. Before Task 01 dispatch, Sergeant must update this table, the Task 01 packet, and `PLAN.md` to `in-progress`, then confirm the target Worker is fresh and unassigned. If a clean-tree preflight is required, commit the authorized coordination transition first.

Task 01 corrections return to its original Worker when available. Task 02 is Sergeant-owned and may not be delegated as a Worker implementation task. Task 03 requires Architect/user acceptance handling. Task 04 returns to Sergeant only after architecture acceptance.

## Completion criteria

Phase 8 is complete when:

- Task 01 readiness evidence and any corrections are accepted by Sergeant;
- every Wave 1 supported claim has current PostgreSQL evidence;
- canonical generated output is readable and accepted;
- package contents are correct and clean;
- documentation describes actual behavior;
- root and demo gates pass;
- user acceptance is approved or explicitly waived;
- Architect accepts readiness and authorizes closeout;
- Sergeant reconciles durable state and removes or explicitly retains phase scaffolding;
- release publication remains separately gated.

## Stop conditions

Stop and return to the correct owner if:

- accepted Phase 6/7 behavior regresses;
- generated output loses a material PostgreSQL semantic silently;
- tests or generation alter user-owned source or leave unintended artifacts;
- package contents include demo, tests, fixtures, credentials, or runtime data;
- documentation claims unsupported behavior;
- a new dependency, public API, runtime, security posture, capability, or product decision becomes necessary;
- safe disposable PostgreSQL verification is unavailable;
- user acceptance fails or remains pending;
- commit, tag, publication, release, or Wave 2 authority is unclear.
