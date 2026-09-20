import Config

base_database = System.get_env("POSTGRES_DB", "pg_to_ecto_demo_test")

nonempty_env = fn name, default ->
  case System.get_env(name) do
    value when is_binary(value) and value != "" -> value
    _ -> default
  end
end

password = nonempty_env.("POSTGRES_PASSWORD", "your_postgres_password")

port =
  case Integer.parse(System.get_env("POSTGRES_PORT", "5432")) do
    {port, ""} when port > 0 and port <= 65_535 -> port
    _ -> raise ArgumentError, "POSTGRES_PORT must be an integer between 1 and 65535."
  end

common_repo_config = [
  adapter: Ecto.Adapters.Postgres,
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: port,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: password,
  pool_size: 2
]

config :pg_to_ecto, generator: PgToEctoDemo.Profile

config :pg_to_ecto_demo,
  ecto_repos: [PgToEctoDemo.SourceRepo, PgToEctoDemo.TargetRepo]

config :pg_to_ecto_demo,
       PgToEctoDemo.SourceRepo,
       Keyword.merge(common_repo_config,
         database: base_database,
         priv: "priv/repo"
       )

config :pg_to_ecto_demo,
       PgToEctoDemo.TargetRepo,
       Keyword.merge(common_repo_config,
         database: base_database <> "_target",
         priv: "priv/target_repo"
       )
