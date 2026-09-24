---
kind: sergeant-review-task
role: sergeant
status: pending
---

# Task 02 — Review, verification, and user acceptance

Role: Sergeant

## Objective

Review Task 01, coordinate corrections, independently verify the readiness candidate, present a concise user acceptance trial, record its exact disposition, and advance accepted evidence to Architect architecture acceptance.

Do not publish, tag, release, begin Wave 2, or infer user acceptance from automated checks.

## Required reading

Read:

- `AGENTS.md`;
- `.agents/roles/sergeant.md`;
- `PLAN.md`;
- the Phase 8 README;
- Task 01 and its completion report;
- changed implementation, tests, generated output, package metadata, and documentation required for review.

## Review requirements

Confirm:

- Task 01 stayed within Wave 1 and Phase 8 scope;
- canonical generated schemas and baseline are readable, deterministic, and ownership-safe;
- source introspection is read-only and excludes application rows;
- every supported claim has real PostgreSQL evidence;
- warnings and errors are actionable and terminal output matches accepted colors/wording;
- force and malformed/unowned-file behavior preserves user-owned source;
- tests restore temporary output bytes and modes and leave no artifacts;
- package archive inclusions and exclusions are correct;
- README, demo documentation, capability matrix, metadata, and changelog match verified behavior;
- no company system/data, credential, tag, publication, release, or Wave 2 scope is present.

Return substantive corrections to the Task 01 Worker when available. Review correction evidence and rerun affected checks.

## Independent verification

Run current root and demo gates, task discovery, diff checks, artifact cleanup checks, package archive inspection, and the narrow safety demonstrations needed to validate Worker claims. Do not rely solely on the Worker report.

Record exact command results and any environment-bound limitations.

## User acceptance trial

Present only the runnable user-facing trial, not internal test details. Include:

- working directory;
- `POSTGRES_PASSWORD` and disposable database prerequisites without requesting the password value;
- setup/reset command and its destructive boundary;
- normal generation and expected colored actions;
- dry run and expected green `No changes required.`;
- representative warning output;
- generated schema and baseline paths to inspect;
- a safe managed-key refusal/force recovery demonstration using isolated or restored files;
- package archive listing command and expected exclusions;
- cleanup/restoration command or evidence.

The trial must cover the nine acceptance items in the Phase README. Keep steps concise and explain what a pass means.

Record the user disposition exactly:

- `approved`;
- `waived by user`;
- `failed` with concrete feedback;
- `pending`.

If feedback requests a correction, route it before repeating the affected acceptance surface.

## State and commit handling

Task 02 may update `PLAN.md`, the Phase README, and task statuses. Do not implement substantive fixes directly.

If user acceptance is approved or waived, all required checks pass, and integration commit authority exists:

1. stage only Phase 8 readiness-candidate files;
2. commit the coherent candidate using a durable Conventional Commits message;
3. update Task 02 to complete, Task 03 to `Ready for owner pickup`, and Architect as current owner;
4. commit the state transition if it is not included coherently in the candidate commit;
5. report that Architect may be started from a clean session.

If commit authority does not exist, stop after recording acceptance and request that exact authority. Do not advance to architecture acceptance with an uncommitted candidate unless the user explicitly directs that exception.

## Completion

Task 02 is complete when:

- Task 01 and corrections are accepted;
- independent verification passes;
- user acceptance is approved or waived;
- package and documentation evidence are complete;
- the accepted candidate and readiness state are committed when authorized;
- Architect is the current owner and Task 03 is ready for pickup.
