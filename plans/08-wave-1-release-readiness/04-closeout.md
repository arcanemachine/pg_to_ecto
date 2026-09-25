---
kind: sergeant-closeout-task
role: sergeant
status: in-progress
---

# Task 04 — Phase closeout

Role: Sergeant

## Objective

Close Phase 8 after architecture acceptance. Reconcile durable documentation and state, remove spent phase scaffolding when appropriate, preserve the next product direction, and leave release actions behind explicit gates.

## Prerequisites

Do not begin until:

- Task 03 records architecture acceptance;
- `PLAN.md` names Sergeant as current owner;
- Task 04 is `Ready for owner pickup`;
- the accepted candidate and state are committed unless the user explicitly authorized an exception.

## Required work

1. Read architecture acceptance findings and confirm every closeout correction is resolved.
2. Re-run only the final deterministic checks required by acceptance or subsequent corrections.
3. Reconcile README, demo documentation, capability status, package metadata, changelog, and any durable project direction changed by Phase 8.
4. Confirm the working tree contains no temporary archives, generated runtime files, database artifacts, credentials, or unrelated changes.
5. Record Phase 8 as closed in `PLAN.md`.
6. Remove the completed Phase 8 plan directory by default after durable results and acceptance are preserved, unless the user explicitly asks to retain it or unresolved work still depends on it.
7. Preserve the next substantive candidate and its owner/gate. Do not leave direction implicit and do not activate Wave 2 automatically.
8. Commit closeout state when commit authority exists.

## Release boundary

`0.1.0` readiness acceptance means the package is ready for release consideration. It does not authorize:

- a version tag;
- Hex publication;
- GitHub or other release publication;
- remote pushes;
- Wave 2 implementation.

Preserve these as explicit user gates in the closed-state report.

## Completion report

Report:

- Phase 8 closure status;
- accepted readiness evidence;
- final verification;
- files and scaffolding removed or retained;
- commit status;
- next substantive candidate and owner;
- exact remaining release/publication gates.

If no next capability has been promoted, set Architect as next owner for direction review rather than inventing or dispatching Wave 2 scope.
