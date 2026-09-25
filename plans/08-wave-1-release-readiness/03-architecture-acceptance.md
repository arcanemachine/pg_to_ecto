---
kind: architecture-acceptance-task
role: architect
status: complete
---

# Task 03 — Architecture acceptance

Role: Architect

## Objective

Perform the bounded architecture sanity pass for Wave 1 and `0.1.0` readiness. Decide whether the candidate may proceed to Sergeant closeout, requires correction, or needs a user decision.

This task does not repeat full implementation review and does not authorize tags, Hex publication, or release publication.

## Acceptance disposition

**Accepted.** The bounded review found no product, architecture, dependency, security, capability, packaging, or release blocker. Root and demo verification passed against the clean accepted tree, including disposable PostgreSQL behavior, source-to-target structure, independent constraints and associations, managed-source safety, package contents, dependency posture, and documentation truthfulness. User acceptance is recorded as approved.

Phase 8 remains bounded to release readiness. Tagging, publication, release, and Wave 2 work remain separately gated. Task 04 is ready for Sergeant closeout.

## Required evidence

Read:

- `AGENTS.md`;
- `.agents/roles/architect.md`;
- `PLAN.md`;
- the Phase 8 README;
- Tasks 01–02 and their completion evidence;
- user acceptance disposition;
- canonical generated schemas and baseline;
- package archive evidence;
- directly relevant changed documentation and metadata;
- current working-tree state.

Use the universal Architect acceptance sequence: bounded evidence wave, Thinker findings report, user response, then acceptance decision and state edit.

## Acceptance checks

Check:

- Phase 8 stayed within readiness work and did not add Wave 2 features;
- PostgreSQL remains the source authority;
- source introspection is read-only and privacy-safe;
- canonical model, schema renderer, baseline renderer, and file-application boundaries remain coherent;
- supported mappings preserve claimed semantics and unsupported mappings remain explicit;
- generated-region/key and force contracts preserve user-owned source;
- CLI behavior matches accepted UAT;
- canonical generated output is understandable and useful;
- source-to-target and independent behavior evidence cover every supported Wave 1 claim;
- package contents and dependency posture are suitable for release consideration;
- documentation and changelog describe actual, not aspirational, behavior;
- user acceptance is approved or waived;
- no tag, publication, release, or Wave 2 authority has been implied.

## Decision outcomes

### Accept

If accepted:

- record architecture acceptance in the Phase README and Task 03;
- set Sergeant as current owner;
- set Task 04 to `Ready for owner pickup`;
- recommend the Sergeant closeout handoff to the user using the universal gated handoff question;
- do not perform closeout mechanically from Architect.

### Needs correction

If correction is required:

- state the blocking finding;
- identify whether work returns to Sergeant or the Task 01 Worker;
- preserve user acceptance only when the correction does not materially change the accepted surface;
- require a repeated acceptance gate when it does.

### User decision required

If evidence exposes a product, architecture, package, dependency, security, capability, or release decision, present Structured Decision Q&A and wait.

## Stop conditions

Stop before accepting if:

- any active task remains incomplete;
- user acceptance is pending or failed;
- evidence is stale or contradictory;
- package contents are unverified;
- a supported capability lacks real PostgreSQL evidence;
- the candidate or readiness state is uncommitted without an explicit exception;
- release or publication authority is being conflated with readiness acceptance.
