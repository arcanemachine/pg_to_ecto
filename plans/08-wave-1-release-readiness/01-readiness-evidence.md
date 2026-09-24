---
kind: worker-task
role: worker
status: in-progress
---

# Task 01 — Build the Wave 1 readiness candidate and evidence

Role: Worker

## Objective

Prepare a complete `0.1.0` readiness candidate from the accepted Wave 1 implementation. Generate reviewable canonical demo output, verify real PostgreSQL behavior and filesystem safety, inspect the Hex archive, reconcile authorized release-facing documentation, and report exact evidence to Sergeant.

This task prepares readiness evidence. It does not accept the product, commit, tag, publish, release, or begin Wave 2.

## Required reading

Read:

- `AGENTS.md`;
- `.agents/roles/worker.md`;
- `plans/08-wave-1-release-readiness/README.md`;
- `README.md`;
- `demo/README.md`;
- `mix.exs`;
- `demo/mix.exs`;
- the generator profile, generated-source ownership modules, Mix task, file application code, and directly matching tests needed for this assignment.

Do not read sibling task packets. Do not read deferred capability material unless this packet names it.

For Ecto/PostgreSQL behavior already implemented, use installed dependency documentation/source and existing project tests as the first evidence source. Stop before introducing a new dependency or mapping mechanism.

## Allowed areas

The task may change, when necessary for verified readiness:

- canonical generated demo schema files;
- the existing demo baseline migration only through the generator’s managed region contract;
- root and demo tests directly needed to prove readiness or correct an in-scope defect;
- root/demo README content, capability wording, package metadata, formatter metadata, `.env.example`, and `CHANGELOG.md`;
- root generator, renderer, Mix-task, diagnostics, file-application, or managed-source code only for a concrete Phase 8 blocker within accepted Wave 1 behavior.

Do not modify `PLAN.md`, phase/task statuses, role guidance, or coordination state. Report state needs to Sergeant.

## Required work

### 1. Preflight

- Confirm the working tree contains the committed accepted Phase 6/7 baseline expected by `PLAN.md`.
- Confirm `POSTGRES_PASSWORD` is set without printing its value.
- Confirm the configured source database and derived target database satisfy the disposable naming guard.
- Confirm no unrelated generated output or runtime artifacts are present.
- Stop if the tree is unexpectedly dirty, accepted work is uncommitted, or state conflicts.

### 2. Canonical output

- Reset/setup only the approved disposable demo databases.
- Run normal generation from `demo/`.
- Preserve the generated Customer, Order, and Invoice schemas as canonical review candidates.
- Confirm the baseline migration matches generated source facts and retains user-owned code outside `generated_change`.
- Inspect generated modules for readable fields, prefixes, associations, ownership regions, and managed keys.
- Run dry generation again and require `No changes required.` with no file modifications.

Do not use force to hide an unexpected mismatch.

### 3. Safety demonstrations

Using isolated temporary copies or deterministic byte/mode restoration:

- demonstrate refusal of an unmanaged output without force;
- demonstrate managed-key mismatch or malformed-key refusal;
- demonstrate force preflight naming the exact replacement/reset action before writes;
- demonstrate force recovery preserving user-owned source outside managed regions;
- demonstrate a filesystem write failure reports the error without falsely claiming completion;
- verify cleanup leaves no temporary artifacts or changes to pre-existing user-owned output.

### 4. PostgreSQL conformance and behavior

Run current source-to-target comparison and independent checks for the supported Wave 1 surface, including:

- ordinary tables in `public` and `sales`;
- IDs and supported string/text, integer, boolean, and implemented numeric behavior;
- nullability and safe literal defaults;
- selected foreign keys and configured referential actions;
- ordinary and unique indexes;
- omitted unselected-table foreign keys and associations with actionable warnings;
- generated schema compilation, reflection, inserts, loads, and association preloads.

Confirm introspection performs catalog reads only and does not write to or query application rows from the source database.

### 5. Package archive

Build the Hex archive using the current package tooling. Record its complete file list and verify:

- required root `lib`, metadata, README, changelog, license, formatter export, and package documentation are present as configured;
- `demo/`, `test/`, fixtures, database configurations, credentials, runtime files, build artifacts, and generated temporary data are absent;
- package metadata names the correct package, version candidate, license, links, and description;
- archive construction does not publish anything.

Remove the locally built archive after evidence collection unless Sergeant requests retaining it for review.

### 6. Documentation reconciliation

Update only statements proven by current evidence. Ensure:

- setup and Mix-task commands are accurate;
- required environment variables and safe database rules are clear;
- generated ownership and force behavior match implementation;
- capability statuses distinguish supported, partial, warning-only, blocking, and deferred behavior honestly;
- the baseline is described as a local-development declaration, not reconstructed production history;
- `CHANGELOG.md` describes the `0.1.0` candidate without claiming publication or release;
- no documentation claims a deferred feature.

### 7. Verification

Run:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix help pg_to_ecto.generate
```

Under `demo/`, run:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix pg_to_ecto.generate --dry-run
```

Also run `git diff --check` and inspect `git status --short`. Confirm only intentional readiness-candidate files remain.

## Completion report

Report to Sergeant through the established inter-agent route:

- files changed;
- generated schema and baseline summary;
- exact root/demo command results;
- source-to-target and independent behavior results;
- safety demonstration results;
- Hex archive file list and exclusions;
- documentation/package changes;
- remaining warnings, blockers, or risks;
- user-acceptance evidence prepared;
- acceptance status: `pending`;
- process feedback, or `Process feedback: No signal`;
- recommended next action: Sergeant Task 02 review.

## Stop conditions

Stop and report without broadening scope if:

- the accepted baseline is absent or uncommitted;
- a supported mapping fails real PostgreSQL verification;
- a generated file cannot preserve user-owned source safely;
- the source Repo would be written or application rows queried;
- package contents include excluded material that cannot be fixed within current metadata;
- a new dependency, public API, capability, security posture, or product decision is required;
- documentation truth requires a scope decision rather than a factual correction;
- credentials are unavailable or a database name is unsafe;
- commit, tag, publication, release, or Wave 2 work appears necessary.
