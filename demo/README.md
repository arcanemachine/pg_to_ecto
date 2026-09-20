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
POSTGRES_PASSWORD=...         # optional; defaults to your_postgres_password
POSTGRES_DB=pg_to_ecto_demo_test  # optional default
```

`POSTGRES_DB` is the disposable source database name. The target database is
always `${POSTGRES_DB}_target`. Lifecycle commands refuse names that do not
start with `pg_to_ecto_demo` and contain only lowercase letters, digits, `_`,
or `-`. The commands never drop or create a database outside that family.

If `POSTGRES_PASSWORD` is unset or empty, the demo uses the placeholder
`your_postgres_password`. Set the variable to override it for a local server.
`.env.example` documents the non-secret variable names. The project does not
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
