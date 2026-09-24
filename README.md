# PgToEcto

PgToEcto turns explicitly selected PostgreSQL tables into readable Ecto schemas and one regenerable baseline migration.

> Project status: pre-release; the Wave 1 surface is implemented and still under active development.

## Setup

Add PgToEcto to a development-only dependency in the consumer project:

```elixir
defp deps do
  [{:pg_to_ecto, "~> 0.1.0", runtime: false}]
end
```

Define one profile for the Repo and tables you want to generate:

```elixir
defmodule MyApp.PgToEcto do
  use PgToEcto.Generator

  repo MyApp.Repo

  table "customers", module: MyApp.Customer
  table "sales.orders", module: MyApp.Order
end
```

Configure the default profile:

```elixir
config :pg_to_ecto, generator: MyApp.PgToEcto
```

Each selected table must name its Ecto module. Output paths are project-relative and must stay inside the Mix project. Unqualified table names use the Repo's `:migration_default_prefix`, or `public` when it is not configured.

## Generate

From the consumer project:

```bash
mix deps.get
mix pg_to_ecto.generate --dry-run
mix pg_to_ecto.generate
```

The dry run introspects the source, renders every output, validates managed files, and prints planned create/update actions without writing. If every output already matches, it prints `No changes required.` Pass a profile explicitly when it is not configured as the default:

```bash
mix pg_to_ecto.generate MyApp.PgToEcto --dry-run
```

Diagnostics are shown by default. Use `--verbose` for a safe context summary containing the profile, Repo, selected-table count, and migration path. Use `--force` only after reviewing the warning. Force can replace an unmanaged output file completely or reset PgToEcto-managed regions; user source outside those regions remains intact. Git is the recovery mechanism and PgToEcto does not create backups.

The task starts a configured Repo temporarily when it is not already running. PgToEcto reads PostgreSQL catalogs only. It does not read application rows, run source migrations, or write to the inspected database.

The programmatic operation is also available:

```elixir
PgToEcto.generate(MyApp.PgToEcto, dry_run: true)
```

The result reports file actions and structured diagnostics. Warnings identify omitted or ambiguous mappings. Errors block output writes.

## Generated ownership

Generated schema files and the baseline migration are mixed-ownership files. PgToEcto owns visible `generated_settings`, `generated_fields`, and `generated_change` regions plus one `pgte1:` managed key. It updates only those regions and preserves virtual fields, associations, functions, changesets, and custom migration code around them.

A normal regeneration refuses missing, malformed, copied, or mismatched managed keys and unmanaged files. `--force` is the explicit recovery path. Repeated generation is idempotent and unchanged files are not rewritten.

Add the optional formatter import to a consumer's `.formatter.exs`:

```elixir
[
  import_deps: [:ecto, :ecto_sql, :pg_to_ecto]
]
```

## Capability matrix

| Capability | Status |
| --- | --- |
| Explicit table and module selection | Supported |
| Qualified and unqualified table names | Supported |
| `public` and selected non-public schemas | Supported |
| Ordinary tables and common string, integer, boolean, and identifier types | Supported |
| Nullability, safe literal defaults, primary keys, foreign keys, and referential actions | Supported for the verified Wave 1 surface |
| Ordinary and unique indexes | Supported |
| Foreign keys to unselected tables | Partial: local fields remain and a warning is emitted |
| Unmappable ordinary schema fields | Partial: migration identity is preserved and the schema field is omitted with a warning |
| Mixed user/generated source and safe regeneration | Supported |
| Dry run, force recovery, atomic per-file replacement, and no-op generation | Supported |
| Composite keys, UUIDs, decimals, arrays, advanced indexes, checks, and generated columns | Deferred to Wave 2 |
| Enums, domains, extensions, views, triggers, grants, and PostgreSQL-native objects | Deferred |
| Historical or incremental migration reconstruction | Not part of the initial product |
| Automatic `many_to_many` inference and changeset generation | Deferred |

The migration is a declarative local-development baseline. It is not a reconstruction of production migration history.

## Demo consumer

The nested [`demo/`](demo/) project uses synthetic, disposable PostgreSQL databases and checked-in source fixtures. It never uses company databases or application data.

```bash
cd demo
mix deps.get
mix demo.reset
mix pg_to_ecto.generate --dry-run
mix pg_to_ecto.generate
mix test
```

The demo uses `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`. `POSTGRES_PASSWORD` is required and has no fallback. The default source database is `pg_to_ecto_demo_test`; the target is its `_target` counterpart. Lifecycle commands refuse database names outside the `pg_to_ecto*` family. No `.env` file is loaded automatically.

## Development

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

This documentation describes the verified Wave 1 behavior. Release readiness, publication, version tagging, and the final initial-release changelog remain separately gated.
