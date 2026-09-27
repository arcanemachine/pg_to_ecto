# Task 10.1: Prepare `pg_to_ecto` `0.1.1` Retirement Patch

## Status

Ready for dispatch after the approved Architect-direct planning handoff is committed.

## Owner

Worker

## Coordinator and reporting route

Architect is the coordinator under the approved direct route and owns dispatch, review, corrections, verification, acceptance presentation, integration, and sequencing. Report questions, blockers, completion evidence, and process feedback only to Architect unless the user explicitly reroutes the task.

## Objective

Prepare a no-code `pg_to_ecto` `0.1.1` patch whose package metadata, README, HexDocs landing content, and changelog clearly state that the project has been renamed to `postgres_to_ecto` and that the replacement release is `0.1.2`.

The old package remains behaviorally identical to `0.1.0`. This task does not perform the implementation rename, publish anything, retire anything, access credentials, or alter runtime source.

## Required reading

Read only:

1. `AGENTS.md` — project safety, verification, documentation, source-control, and release rules.
2. `plans/phase-10-package-rename/README.md` — approved two-release sequence, scope, gates, and authority boundaries.
3. `mix.exs` — current version, description, dependencies, docs, source links, and package file list.
4. `README.md` — current public documentation and accepted Wave 1 claims.
5. `CHANGELOG.md` — immutable `0.1.0` release entry and required placement for `0.1.1`.

Do not read `PLAN.md`; lifecycle coordination belongs to the coordinator and Architect.

## Allowed files

- `mix.exs`
- `README.md`
- `CHANGELOG.md`

No other file may be edited. Do not rename files or directories in this task.

## Required changes

### `mix.exs`

- Change the package version from `0.1.0` to `0.1.1`.
- Change the description to a concise retirement message that names `postgres_to_ecto` as the replacement.
- Keep the application name `:pg_to_ecto`.
- Keep the existing source/homepage links for the old package release.
- Keep every dependency, runtime flag, Elixir requirement, docs setting, license, package file, and build setting unchanged.

### `README.md`

Add a prominent retirement notice immediately after the title and before normal installation or usage guidance. It must:

- state that `pg_to_ecto` has been renamed to `postgres_to_ecto`;
- direct users to install `postgres_to_ecto` `~> 0.1.2`;
- identify the rename as a breaking package/module/task/configuration change with no compatibility aliases;
- tell users not to begin new integrations with `pg_to_ecto`;
- state that existing `pg_to_ecto` behavior remains available only as the historical old package while users migrate;
- link to the replacement Hex package and HexDocs using their final public names;
- remain accurate when rendered as the default HexDocs page after publication.

Do not mechanically rename the rest of the old README. The old package documentation must continue to describe its actual `PgToEcto` `0.1.1` code accurately. Do not advertise new behavior or claim that the replacement is already public in wording that would be false before the coordinated publication sequence completes; phrase the destination as the replacement release prepared by this phase.

### `CHANGELOG.md`

Insert `## [0.1.1] - YYYY-MM-DD` above `0.1.0`, using the actual date supplied by the coordinator. Include a concise `Changed` or `Deprecated` section that records:

- the package has been renamed to `postgres_to_ecto`;
- users should migrate to `postgres_to_ecto` `0.1.2`;
- this patch changes documentation and release metadata only;
- runtime behavior and dependencies are unchanged;
- no compatibility aliases are provided by the replacement.

Do not modify the published `0.1.0` heading or any byte in its entry.

## Explicit non-goals

- No changes under `lib/`, `test/`, `demo/`, `.agents/`, or `plans/`.
- No application/package rename yet.
- No runtime, dependency, generated-output, task, configuration, capability, or safety change.
- No compatibility code or deprecation warnings in runtime code.
- No Git commit, tag, push, Hex publication, Hex retirement, repository rename, or credential use.

## Focused verification

Run from `/workspace/projects/pg_to_ecto`:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix docs
git diff --check
```

Treat every warning as a failure. Remove generated `doc/` output after inspection.

Build the candidate with `mix hex.build` and report, without publishing:

- package/app name;
- version;
- description;
- dependencies and runtime flags;
- source/homepage links;
- complete file list;
- package checksum;
- confirmation that the README and changelog in the archive contain the retirement guidance;
- confirmation that runtime source in the archive is unchanged from `v0.1.0`.

Remove `pg_to_ecto-0.1.1.tar` after recording the evidence.

Confirm the final working tree contains changes only to the three allowed files and no generated artifacts.

## Stop conditions

Stop and report if:

- the actual release date is unavailable;
- accurate retirement wording requires a runtime or dependency change;
- the replacement package name or target version differs from `postgres_to_ecto` `0.1.2`;
- the published `0.1.0` changelog entry would need alteration;
- any required check fails or warns for a reason outside allowed files;
- the archive metadata or contents differ from the allowed no-code release;
- another session changes an allowed file during the task;
- credentials, publication, retirement, or remote repository changes would be required.

## Completion report

Report to the coordinator:

- changed files;
- final retirement wording and changelog structure in summary;
- focused check outcomes and warning status;
- archive metadata, full file list, and checksum;
- proof that runtime source and dependencies are unchanged;
- confirmation that only allowed files changed and no artifacts remain;
- process feedback or `none`.

Do not commit, tag, push, publish, retire, or message the user directly unless explicitly rerouted.
