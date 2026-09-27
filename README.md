# PostgresToEcto

PostgresToEcto turns explicitly selected PostgreSQL tables into readable Ecto schemas and one regenerable baseline migration.

## Setup

Add PostgresToEcto to a development-only dependency in the consumer project:

```elixir
defp deps do
  [{:postgres_to_ecto, "~> 0.1.2", runtime: false}]
end
```

Define one profile for the Repo and tables you want to generate:

```elixir
defmodule MyApp.PostgresToEcto do
  use PostgresToEcto.Generator

  repo MyApp.Repo

  table "customers", module: MyApp.Customer
  table "sales.orders", module: MyApp.Order
end
```

Configure the default profile:

```elixir
config :postgres_to_ecto, generator: MyApp.PostgresToEcto
```

Each selected table must name its Ecto module. Output paths are project-relative and must stay inside the Mix project. Unqualified table names use the Repo's `:migration_default_prefix`, or `public` when it is not configured.

## Migrating from `pg_to_ecto`

The `postgres_to_ecto` `0.1.2` release is a breaking rename with no compatibility aliases. Commit your work, apply and review these mechanical replacements, then run a dry run:

- Change the dependency from `:pg_to_ecto` to `:postgres_to_ecto` and use `~> 0.1.2`.
- Change the formatter import from `:pg_to_ecto` to `:postgres_to_ecto`.
- Change the application configuration key from `:pg_to_ecto` to `:postgres_to_ecto`.
- Change `PgToEcto` module references to `PostgresToEcto`.
- Change `mix pg_to_ecto.generate` to `mix postgres_to_ecto.generate`.
- Change generated `use PgToEcto.Schema` and `use PgToEcto.Migration` lines to their `PostgresToEcto` equivalents.
- Change `@pg_to_ecto_key` to `@postgres_to_ecto_key`.
- Change the managed-key prefix from `pgte1:` to `postgreste1:` and leave the encoded payload unchanged.
- Change project-local paths containing `pg_to_ecto` to `postgres_to_ecto`.

Do not run `--force` merely to cross the rename boundary: force replacement can discard user-owned content in a file that still uses the old marker. Commit your work and review every mechanical replacement before running `mix postgres_to_ecto.generate --dry-run`.

## Generate

From the consumer project:

```bash
mix deps.get
mix postgres_to_ecto.generate --dry-run
mix postgres_to_ecto.generate
```

The dry run introspects the source, renders every output, validates managed files, and prints planned create/update actions without writing. If every output already matches, it prints `No changes required.` Pass a profile explicitly when it is not configured as the default:

```bash
mix postgres_to_ecto.generate MyApp.PostgresToEcto --dry-run
```

Diagnostics are shown by default. Use `--verbose` for a safe context summary containing the profile, Repo, selected-table count, and migration path. Use `--force` only after reviewing the warning. Force can replace an unmanaged output file completely or reset PostgresToEcto-managed regions; user source outside those regions remains intact. Git is the recovery mechanism and PostgresToEcto does not create backups.

The task starts a configured Repo temporarily when it is not already running. PostgresToEcto reads PostgreSQL catalogs only. It does not read application rows, run source migrations, or write to the inspected database.

The programmatic operation is also available:

```elixir
PostgresToEcto.generate(MyApp.PostgresToEcto, dry_run: true)
```

The result reports file actions and structured diagnostics. Warnings identify omitted or ambiguous mappings. Errors block output writes.

## Generated ownership

Generated schema files and the baseline migration are mixed-ownership files. PostgresToEcto owns visible `generated_settings`, `generated_fields`, and `generated_change` regions plus one `postgreste1:` managed key. It updates only those regions and preserves virtual fields, associations, functions, changesets, and custom migration code around them.

A normal regeneration refuses missing, malformed, copied, or mismatched managed keys and unmanaged files. `--force` is the explicit recovery path. Repeated generation is idempotent and unchanged files are not rewritten.

Add the optional formatter import to a consumer's `.formatter.exs`:

```elixir
[
  import_deps: [:ecto, :ecto_sql, :postgres_to_ecto]
]
```

## Capability matrix

| Capability | Status |
| --- | --- |
| Explicit table and module selection | Supported |
| Qualified and unqualified table names | Supported |
| `public` and selected non-public schemas | Supported |
| Ordinary tables and common string, integer, boolean, and identifier types | Supported |
| Nullability, safe literal defaults, primary keys, foreign keys, and referential actions | Supported for the documented scalar-type surface |
| Ordinary and unique indexes | Supported |
| Foreign keys to unselected tables | Partial: local fields remain and a warning is emitted |
| Unmappable ordinary schema fields | Partial: migration identity is preserved and the schema field is omitted with a warning |
| Mixed user/generated source and safe regeneration | Supported |
| Dry run, force recovery, atomic per-file replacement, and no-op generation | Supported |
| Composite keys, UUIDs, decimals, arrays, advanced indexes, checks, and generated columns | Not supported |
| Enums, domains, extensions, views, triggers, grants, and PostgreSQL-native objects | Deferred |
| Historical or incremental migration reconstruction | Not supported |
| Automatic `many_to_many` inference and changeset generation | Deferred |

The migration is a declarative local-development baseline. It is not a reconstruction of production migration history.

## Demo consumer

The nested `demo/` project uses synthetic, disposable PostgreSQL databases and checked-in source fixtures. It never uses company databases or application data.

```bash
cd demo
mix deps.get
mix demo.reset
mix postgres_to_ecto.generate --dry-run
mix postgres_to_ecto.generate
mix test
```

The demo uses `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB`. `POSTGRES_PASSWORD` is required and has no fallback. The default source database is `postgres_to_ecto_demo_test`; the target is its `_target` counterpart. Lifecycle commands refuse database names outside the `postgres_to_ecto*` family. No `.env` file is loaded automatically.

## Development

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```
