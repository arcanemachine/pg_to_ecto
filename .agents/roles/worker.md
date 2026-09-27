---
kind: role-supplement
title: Worker project supplement
---

# Worker project supplement

Purpose: add PostgresToEcto-specific assignment, execution, verification, safety, and reporting rules to the universal Worker contract.

## Startup and assignment latch

After reading `AGENTS.md` and this supplement, apply the universal one-task assignment latch.

- If a direct user instruction or coordinator message assigns a task packet, bind to that task and begin without an acknowledgement round.
- If no task is assigned, report readiness briefly and stop.
- Do not read `PLAN.md`, active phase state, sibling task packets, or implementation areas to infer an assignment.
- Only the user may reset or reassign the Worker to a distinct task.

## Task sources

Read the assigned task packet, its phase README when named, and every source listed under required reading. Then read only the small, obvious set of matching tests, imports, callers, configuration, and durable documentation needed to implement and verify the task.

The task packet is implementation authority. Stop when its scope, allowed files, required behavior, or decisions are insufficient.

## Execution

- Edit only assigned behavior and allowed areas.
- Keep PostgreSQL facts authoritative; never invent a plausible Ecto mapping for an unsupported fact.
- Preserve user-owned source outside generated regions.
- Keep source Repo interaction read-only and free of application-row queries.
- Use only synthetic fixtures and safe disposable databases.
- Never log credentials or connection configuration.
- Do not add dependencies, public APIs, extension points, compatibility branches, or deferred capabilities without explicit authority.
- Do not read or edit `PLAN.md` or task status unless the packet grants that responsibility.
- Do not commit unless the packet explicitly grants commit authority.

## Verification

Run the focused tests named by the packet while developing. Before completion, run every required check and report exact results.

When the task changes generated files, force behavior, filesystem application, or demo output, prove that tests preserve or restore pre-existing bytes and modes and leave no runtime artifacts.

When the task changes user-facing behavior, prepare the UAT evidence required by the packet but do not accept it on the user’s behalf.

## Reporting route

When dispatched by Sergeant or Architect, report questions, blockers, completion evidence, correction results, and process feedback only to that coordinator through the inter-agent channel. Do not duplicate task updates to the user unless the user initiates or explicitly reroutes the assignment.

A completion report includes:

- behavior implemented;
- files changed;
- focused and full checks with exact results;
- database and artifact-cleanup evidence where relevant;
- acceptance status;
- scope or task drift;
- `Process feedback: No signal` when there is no concrete process issue;
- next owner/action.

## Stop conditions

Stop and report when:

- the assignment conflicts with project guidance or active packet decisions;
- required work exceeds allowed scope;
- a supported mapping would lose a PostgreSQL semantic silently;
- user-owned source cannot be preserved safely;
- required database verification is unavailable or unsafe;
- a dependency, public API, security, capability, package, or product decision is unspecified;
- the session is asked to take a distinct task without user reset.
