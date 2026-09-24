# Agent Guide

Purpose: this file is the normal starting point for agents working in PgToEcto. It defines the project-local coordination model and points each active role to its supplement. Follow the universal role contract first; this file adds only PgToEcto-specific recovery, routing, safety, verification, and artifact rules.

## Project direction

PgToEcto is an Elixir development tool that projects explicitly selected PostgreSQL tables into readable Ecto schemas and one regenerable baseline migration. PostgreSQL remains the source authority. Generated output must preserve supported semantics, report loss or ambiguity plainly, and never overwrite user-owned source silently.

The core pipeline is:

```text
explicit generator profile
  -> read-only PostgreSQL catalog introspection
  -> canonical in-memory model
  -> sparse overrides
  -> generated schemas + baseline migration + diagnostics
```

Keep the implementation direct. Do not add plugin systems, public mapping registries, persistent snapshots, incremental migration history, multi-Repo task orchestration, or PostgreSQL-native features outside the active plan.

## Normal startup

1. Read this file before other project files.
2. Determine the assigned generic role from the active Pi role or direct user assignment.
3. If the role is unclear, stop and ask the user to assign Architect, Sergeant, or Worker.
4. Read only the matching project supplement:
   - Architect: `.agents/roles/architect.md`
   - Sergeant: `.agents/roles/sergeant.md`
   - Worker: `.agents/roles/worker.md`
5. Follow that supplement’s recovery or assignment instructions.

Do not read another role’s supplement merely because it exists.

## Planning and state model

`PLAN.md` is the lightweight source of truth for current lifecycle state. It names:

- the active or prepared phase;
- current owner;
- current gate;
- exact next action;
- authoritative phase and task artifacts.

Detailed executable phase guidance lives under `plans/<phase-name>/`. A phase README owns phase scope, decisions, acceptance, task order, and lifecycle status. Each task packet has exactly one role owner.

Do not infer authority from directory existence. Read only the active phase or task named by `PLAN.md`, direct user instruction, or an authorized handoff.

Keep `PLAN.md` and the active phase README aligned whenever ownership, task status, user acceptance, architecture acceptance, closeout, or the next action changes.

## Single-current-owner coordination

PgToEcto uses the same single-current-owner lifecycle that works in Practorium:

- Architect owns product and architecture decisions, executable planning, architecture acceptance, and successor direction.
- Sergeant owns execution coordination, Worker dispatch, review, corrections, deterministic verification, user-acceptance presentation, integration, and closeout.
- Worker owns one explicitly assigned implementation task and reports only through the established coordinator unless the user directly assigns or reroutes it.

Planning completion and execution pickup are separate facts. A completed plan names its execution owner and is marked `Ready for owner pickup` or `Not started`. The user starts, engages, or directly assigns that role to complete the pickup. An inter-agent message may confirm durable state, but it does not replace it.

The outgoing owner aligns and, when authorized, commits durable state before ending its session. Once durable ownership is correct, that session may be reset; the next role recovers from files rather than conversation or mailbox history.

## Sergeant dispatch protocol

Sergeant is the normal dispatcher for implementation work.

Before dispatching a task, Sergeant must:

1. have user or workflow authority for the phase and route;
2. read the phase README and current task packet;
3. confirm the task is ready and no earlier task or gate blocks it;
4. establish that the target Worker is fresh and unassigned;
5. update `PLAN.md`, the phase README, and task status to `in-progress`;
6. commit the coordination transition first when the task requires a clean-tree preflight and commit authority exists;
7. send the Worker the authoritative packet path and reporting route.

Do not request routine acknowledgement. An eligible Worker binds and begins on dispatch. Same-task corrections return to the original Worker when available. A distinct task requires a fresh Worker.

After accepting a Worker task, Sergeant updates state and dispatches the next ready task without another user confirmation when the approved phase route authorizes routine sequencing. Stop at user acceptance, architecture acceptance, commit, release, dependency, security, or other explicit gates.

## Worker assignment discipline

A Worker session owns at most one task unless the user explicitly resets or reassigns it. Startup and availability checks are not assignments.

Workers:

- read only their assigned packet and required sources;
- do not read or edit `PLAN.md` unless the packet explicitly grants that responsibility;
- keep within allowed files and scope;
- send questions, blockers, completion evidence, and process feedback to the dispatcher;
- do not contact the user about the task unless the user initiates or explicitly reroutes communication;
- do not commit unless the packet grants commit authority.

Research subagents do not own implementation tasks.

## User-facing acceptance

New or materially changed CLI, generated-source, documentation, or database behavior requires explicit user acceptance or user-initiated waiver before the phase advances through its acceptance gate.

The owning task must prepare a concise runnable UAT with:

- exact working directory;
- prerequisites and safe environment variables;
- exact commands;
- visible expected results;
- cleanup or restoration behavior.

Run an initial agent-driven trial before presenting UAT. Automated tests prepare the gate but do not replace user approval. Preserve accepted behavior with deterministic tests so unchanged behavior is not repeatedly sent back to the user.

## PostgreSQL and credential safety

- Use only synthetic fixtures and clearly disposable PgToEcto demo/test databases.
- Require `POSTGRES_PASSWORD`; do not commit a password fallback.
- Never print connection URLs, passwords, or credentials.
- Never access company databases, services, schemas, data, or credentials.
- The generator performs read-only catalog introspection and never writes to the inspected source database.
- Destructive demo lifecycle commands must reject names outside the documented disposable naming convention.
- Tests that generate, force, overwrite, or corrupt files must use ignored temporary paths or restore every pre-existing output byte and file mode deterministically.

## Verification

Use focused checks during implementation. Before accepting a task, run the verification named by its packet.

The normal root gate is:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

The normal demo gate is the same set under `demo/`, with a configured disposable PostgreSQL source/target pair. Check `git diff --check` and confirm that verification leaves no generated runtime artifacts or unrelated changes.

Report skipped checks and blockers honestly. Compiler, formatter, logger, database, and filesystem warnings may not be ignored.

## Source control

Treat commits as lifecycle boundaries, not incidental cleanup.

- Obtain commit authority from the active plan, workflow, task, or user.
- Stage only current accepted work.
- Do not commit failing checks, generated runtime data, unrelated files, or behavior awaiting required user acceptance.
- Use Conventional Commits-style subjects.
- Do not bypass hooks or checks without explicit permission.
- Do not leave a completed, verified, accepted phase uncommitted when the approved route grants Sergeant integration responsibility.

## Documentation and path style

Use project-root-relative paths in project documentation, plans, reports, handoffs, and commit messages. Keep durable documentation professional and free of transient session names, mailbox details, temporary commit hashes, or conversation-only rationale.

Place:

- current state and pointers in `PLAN.md`;
- active execution guidance under `plans/`;
- public setup and behavior in `README.md` and `demo/README.md`;
- package release notes in `CHANGELOG.md` only when the active plan authorizes finalization.

## Project stop conditions

Stop and return to the appropriate owner when:

- `PLAN.md`, active task state, working-tree state, or recent accepted evidence conflict materially;
- a task requires an unapproved product, architecture, dependency, runtime, public API, security, capability, or packaging decision;
- a fresh eligible Worker is unavailable;
- required user acceptance is missing or failed;
- database work would use an unsafe name or non-synthetic data;
- generated output or tests overwrite user-owned source or leave artifacts;
- commit, tag, publication, release, or closeout authority is unclear.
