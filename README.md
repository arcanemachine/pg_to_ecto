# PgToEcto

PgToEcto turns selected PostgreSQL database tables into safe, readable Ecto code for Elixir projects.

> Project status: pre-alpha; under active development. Not suitable for use yet.
>
> This status will be updated as the project progresses.

## Current implementation

Phase 0 established the compile-time ownership primitives:

- `PgToEcto.Schema.generated_settings/1` and `generated_fields/1`;
- `PgToEcto.Migration.generated_change/1`;
- deterministic `pgte1:` keys over normalized generated regions and comments;
- exact Sourceror region replacement that preserves user-owned source.

Phase 1 adds literal generator profiles with one Repo, explicit table/module
selection, qualified table-name normalization, output validation, migration
basename validation, diagnostics, and `PgToEcto.generate/2` validation plumbing.
The public operation currently validates a profile and returns an empty result;
database introspection, renderers, file writing, and the generation Mix task
remain later phases.

Phase 2 adds a nested consumer under `demo/` with explicit source and target
Repos, a checked-in synthetic Wave 1 PostgreSQL migration, disposable database
lifecycle guards, and serialized structural conformance tests. The fixture
covers ordinary tables, a selected non-public table, scalar types, defaults,
nullability, foreign keys and delete actions, indexes, and an unselected
referenced table. It contains no company data or credentials.

## Development

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

To exercise the disposable demo, see [`demo/README.md`](demo/README.md). The
demo uses an optional `POSTGRES_PASSWORD` override, defaults to the clearly disposable
`pg_to_ecto_demo_test` source database, derives a `_target` database, and
refuses lifecycle operations for names outside the `pg_to_ecto_demo*` family.
The demo uses the placeholder `your_postgres_password` when
`POSTGRES_PASSWORD` is unset or empty; an environment value overrides it.
It does not implement PostgreSQL introspection or generated schema/migration
rendering yet.
