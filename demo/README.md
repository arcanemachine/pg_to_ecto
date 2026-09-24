# PgToEcto demo consumer

The demo is a nested Ecto consumer with a disposable PostgreSQL source fixture.
The source database is built from the checked-in migration at
`priv/source_repo/migrations/0001_wave1_fixture.exs`.

## Configuration

Set these environment variables before running database commands:

```text
POSTGRES_HOST=localhost       # optional, defaults to localhost
POSTGRES_PORT=5432            # optional, defaults to 5432
POSTGRES_USER=postgres        # optional, defaults to postgres
POSTGRES_PASSWORD=...         # required; no default is used
POSTGRES_DB=pg_to_ecto_demo_test  # optional default
```

`POSTGRES_DB` is the disposable source database name. The target database is
always `${POSTGRES_DB}_target`. Lifecycle commands refuse names that do not
start with `pg_to_ecto_demo` and contain only lowercase letters, digits, `_`,
or `-`. The commands never drop or create a database outside that family.

`POSTGRES_PASSWORD` must be set to a non-empty value before database commands
run. `.env.example` documents the required variable names. The project does not
load `.env` files automatically.

## Database lifecycle

From this directory:

```bash
mix deps.get
mix demo.reset
mix test
```

`mix demo.reset` drops and recreates both disposable databases, then applies
the checked-in source migration. To create missing databases without dropping
existing fixture data, use `mix demo.setup`. To remove only the disposable
source and target databases, use `mix demo.drop`.

The same operations are available without aliases:

```bash
mix run -e 'PgToEctoDemo.Database.setup!()'
mix run -e 'PgToEctoDemo.Database.reset!()'
mix run -e 'PgToEctoDemo.Database.drop!()'
```

The source fixture contains selected `customers`, `orders`, and
`sales.invoices` tables, plus an unselected `internal.audit_events` table.
It also covers common scalar types, nullability, safe literal defaults,
foreign keys with delete actions, ordinary and unique indexes, and a
non-`public` namespace.

## Generation

After `mix demo.reset`, run the generator against the disposable source Repo:

```bash
mix pg_to_ecto.generate --dry-run
mix pg_to_ecto.generate
```

The dry run reports schema and migration changes without writing. Normal
execution updates the managed schema regions and the baseline migration. Use
`--force` only to replace an unmanaged output file or reset a changed managed
region after reviewing its warning. User code outside generated regions is
preserved. `mix test` exercises source introspection, baseline application to
the clean target database, generated schema compilation, and representative
Ecto/PostgreSQL behavior.

The generator performs read-only catalog introspection against the source Repo;
it does not query application rows or run DDL there. The lifecycle aliases above
are the only demo commands that drop databases, and their disposable-name
checks must pass before any destructive operation.
