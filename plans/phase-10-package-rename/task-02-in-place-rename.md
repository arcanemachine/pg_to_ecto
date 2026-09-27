# Task 10.2: Rename the Project to `postgres_to_ecto` `0.1.2`

## Status

Blocked until Task 10.1 is accepted, committed as `chore: release v0.1.1`, tagged `v0.1.1`, and the coordinator renames the local checkout root to `/workspace/projects/postgres_to_ecto`.

## Owner

Fresh Worker

## Coordinator and reporting route

Architect is the coordinator under the approved direct route and owns dispatch, review, corrections, verification, acceptance presentation, integration, and sequencing. Report questions, blockers, completion evidence, and process feedback only to Architect unless the user explicitly reroutes the task.

## Objective

Mechanically rename the accepted Wave 1 project from `pg_to_ecto`/`PgToEcto` to `postgres_to_ecto`/`PostgresToEcto`, continue the version sequence at `0.1.2`, and preserve all established behavior, dependencies, capability boundaries, database safety, generated-source ownership, and diagnostics.

This task creates a direct breaking rename. It must not add compatibility aliases, recognize old task/config/module names, or silently migrate old generated consumer files.

## Required reading

After dispatch from `/workspace/projects/postgres_to_ecto`, read only:

1. `AGENTS.md` — project safety, verification, release, and source-control rules.
2. `plans/phase-10-package-rename/README.md` — approved scope, rename matrix, sequencing, gates, and stop conditions.
3. This task packet.
4. `mix.exs` — package/application/version/dependency/source metadata.
5. `README.md` and `CHANGELOG.md` — public behavior, accepted capability claims, old retirement release, and migration surface.
6. `.formatter.exs` and `demo/.formatter.exs` — package formatter import/export surfaces.
7. `lib/`, `test/`, and `demo/` files containing a literal match for `PgToEcto`, `pg_to_ecto`, `PG_TO_ECTO`, or `pgte1:` — exact rename targets.
8. `.agents/roles/*.md` only where a literal old project name appears — project identity guidance that must follow the rename.

Do not read or edit `PLAN.md`. Do not read unrelated historical plans or coordination repositories.

## Allowed areas

- `AGENTS.md`
- `.agents/roles/architect.md`
- `.agents/roles/sergeant.md`
- `.agents/roles/worker.md`
- `.formatter.exs`
- `.gitignore`
- `mix.exs`
- `mix.lock` only if Mix deterministically changes project metadata without dependency-version changes
- `README.md`
- `CHANGELOG.md`
- `lib/**`
- `test/**`
- `demo/**`

File and directory renames within these areas are allowed and required where their names contain the old project namespace.

Do not edit:

- `PLAN.md`;
- `plans/**`;
- `.git/**`;
- coordination content under `/workspace/projects/_plans`;
- files outside `/workspace/projects/postgres_to_ecto`.

The coordinator, not the Worker, owns project-root rename, lifecycle-state edits, commits, tags, remote URLs, pushes, publication, and retirement.

## Exact rename contract

Apply these namespace changes wherever they identify this project rather than immutable history or explicit migration guidance:

| Old | New |
| --- | --- |
| `pg_to_ecto` | `postgres_to_ecto` |
| `PgToEcto` | `PostgresToEcto` |
| `PG_TO_ECTO` | `POSTGRES_TO_ECTO` |
| `mix pg_to_ecto.generate` | `mix postgres_to_ecto.generate` |
| `Mix.Tasks.PgToEcto.Generate` | `Mix.Tasks.PostgresToEcto.Generate` |
| `@pg_to_ecto_key` | `@postgres_to_ecto_key` |
| `pgte1:` | `postgreste1:` |
| `.pg_to_ecto_...tmp` | `.postgres_to_ecto_...tmp` |
| `pg_to_ecto_demo...` | `postgres_to_ecto_demo...` |
| `PgToEctoDemo` | `PostgresToEctoDemo` |

Historical references to old published versions remain only in changelog history and explicit migration/retirement prose. Do not globally replace those facts into false history.

## Required implementation changes

### Package and project metadata

- Set `app: :postgres_to_ecto` and version `0.1.2`.
- Set project name to `PostgresToEcto`.
- Restore an active-product description using the accepted behavior statement rather than the old retirement description.
- Update source/homepage/package links to `https://github.com/arcanemachine/postgres_to_ecto`.
- Keep the Elixir requirement, dependencies, runtime flags, license, package file list, docs configuration, and coverage settings otherwise unchanged.
- Ensure `.formatter.exs` exports/imports and consumer examples use `:postgres_to_ecto`.

### Library and Mix task

- Rename `lib/pg_to_ecto.ex` to `lib/postgres_to_ecto.ex`.
- Rename `lib/pg_to_ecto/` to `lib/postgres_to_ecto/`.
- Rename every public and internal `PgToEcto` module to the corresponding `PostgresToEcto` module.
- Rename `lib/mix/tasks/pg_to_ecto.generate.ex` to `lib/mix/tasks/postgres_to_ecto.generate.ex` and rename the task module/CLI command.
- Update diagnostics, logs, generated comments, moduledocs, typespec references, examples, and task output to the new project name.
- Remove no behavior and add no compatibility wrapper.

### Managed source

- Rename the marker attribute to `@postgres_to_ecto_key`.
- Rename the key prefix to `postgreste1:` while retaining the same digest size and payload algorithm.
- Rename generated helper function names such as `__pg_to_ecto_key__/0` mechanically to the new namespace.
- Rename generated comments, `use` anchors, temporary-file prefixes, regexes, templates, and fixtures.
- Do not recognize `@pg_to_ecto_key`, `pgte1:`, `PgToEcto.Schema`, or `PgToEcto.Migration` as valid new-format inputs.
- Add tests proving that a valid old generated source becomes valid new generated source after the documented mechanical text replacements and that user-owned source outside managed regions remains byte-identical.
- Preserve normal malformed/missing/mismatched-key blocking, dry-run, force recovery, idempotency, atomic writes, and symlink rejection for the new format.

### Tests

- Rename `test/pg_to_ecto_test.exs`, `test/pg_to_ecto/`, and the Mix task test path to the new namespace.
- Rename test modules, aliases, fixtures, temporary paths, assertions, and diagnostic strings.
- Preserve all existing behavior coverage.
- Add only the narrow migration-documentation evidence described above; do not introduce automatic compatibility behavior.

### Demo

- Rename the demo OTP app and module namespace to `:postgres_to_ecto_demo` / `PostgresToEctoDemo`.
- Rename `demo/lib/pg_to_ecto_demo/` and `demo/test/pg_to_ecto_demo/` to corresponding new paths.
- Rename the default disposable database family from `pg_to_ecto_demo...` to `postgres_to_ecto_demo...` and retain the same character/length/name-safety guards.
- Rename profile configuration from `:pg_to_ecto` to `:postgres_to_ecto`.
- Rename generated schema/migration files, modules, `use` lines, managed markers, comments, and canonical fixture expectations.
- Preserve real PostgreSQL coverage, source read-only behavior, target application, cleanup, byte/mode restoration, and credential rules.

### Public documentation and migration guide

Convert the old retirement README into the active `PostgresToEcto` `0.1.2` README. Keep the accepted Wave 1 behavior and capability matrix unchanged except for project identifiers and version.

Add a concise migration section that tells existing users to change:

- dependency `:pg_to_ecto` to `:postgres_to_ecto` and requirement to `~> 0.1.2`;
- formatter import `:pg_to_ecto` to `:postgres_to_ecto`;
- application config key `:pg_to_ecto` to `:postgres_to_ecto`;
- `PgToEcto` module references to `PostgresToEcto`;
- `mix pg_to_ecto.generate` to `mix postgres_to_ecto.generate`;
- generated `use PgToEcto.Schema` / `use PgToEcto.Migration` lines to `PostgresToEcto`;
- marker attribute `@pg_to_ecto_key` to `@postgres_to_ecto_key`;
- key prefix `pgte1:` to `postgreste1:` while leaving the encoded payload unchanged;
- any project-local paths containing `pg_to_ecto` to the new spelling.

State plainly that no compatibility aliases exist. Warn users not to run `--force` merely to cross the rename boundary because force replacement can discard user-owned content in a file still using the old marker. Direct them to commit their work and apply/review the mechanical replacements before a dry run.

Add `0.1.2` above `0.1.1` in `CHANGELOG.md`, recording the package/module/task/config/path/marker rename and no behavior/dependency expansion. Keep both earlier entries unchanged.

### Project guidance

Rename the project identity in `AGENTS.md` and the matching role supplements. Preserve all safety, verification, lifecycle, source-control, release, and ownership rules. Historical references may remain only when they identify the old published package or migration path.

## Explicit non-goals

- No new PostgreSQL/Ecto feature support.
- No dependency or supported-runtime change.
- No compatibility aliases or automatic old-format conversion.
- No refactoring unrelated to literal rename requirements.
- No release automation or GitHub Release.
- No coordination-document migration.
- No commit, tag, remote rename, push, Hex publication, Hex retirement, or credentials.

## Required verification

Run focused tests while editing, then from `/workspace/projects/postgres_to_ecto` run:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix docs
git diff --check
```

From `demo/`, with only documented disposable PostgreSQL settings and a required non-empty `POSTGRES_PASSWORD`:

```text
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Run a bounded rename audit across tracked source, tests, demo, package metadata, and public/process documentation. Classify every surviving old-name match; only immutable historical release facts and explicit migration/retirement guidance are allowed.

Build `postgres_to_ecto-0.1.2.tar` without publishing. Record package metadata, dependencies, runtime flags, complete file list, checksum, source/homepage links, README/changelog content, and confirmation that old compatibility code, tests, demo, plans, credentials, and build output are absent. Remove the archive and generated `doc/` directory afterward.

Confirm the working tree contains only intended tracked changes and no runtime artifacts.

## Stop conditions

Stop and report if:

- a rename requires behavior, dependency, runtime, capability, security, or database-policy changes;
- old-name compatibility code appears necessary;
- old generated files cannot be migrated by the documented mechanical edits without force replacement or user-owned-source loss;
- the intended source URL or Hex package name conflicts with real public state;
- a required file falls outside allowed areas;
- root or demo verification fails or warns;
- canonical output changes beyond the namespace rename;
- the archive contains unintended files or the wrong namespace;
- another session changes an allowed file during the task;
- credentials or irreversible remote actions would be required.

## Completion report

Report to the coordinator:

- renamed files and directories;
- changed public/package/config/task/marker/demo surfaces;
- migration-guide summary;
- focused, root, docs, demo, diff, rename-audit, archive, and artifact-cleanliness outcomes;
- archive metadata, full file list, and checksum;
- confirmation that behavior/dependencies/capability claims did not change;
- confirmation that no compatibility aliases remain;
- process feedback or `none`.

Do not commit, tag, rename the remote, push, publish, retire, use credentials, or message the user directly unless explicitly rerouted.
