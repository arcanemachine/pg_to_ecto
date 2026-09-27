import Config

base_database = System.get_env("POSTGRES_DB", "postgres_to_ecto_demo_test")

password = System.fetch_env!("POSTGRES_PASSWORD")
if password == "", do: raise(ArgumentError, "POSTGRES_PASSWORD must be set to a non-empty value.")

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

config :postgres_to_ecto, generator: PostgresToEctoDemo.Profile

config :postgres_to_ecto_demo,
  ecto_repos: [PostgresToEctoDemo.SourceRepo, PostgresToEctoDemo.TargetRepo]

config :postgres_to_ecto_demo,
       PostgresToEctoDemo.SourceRepo,
       Keyword.merge(common_repo_config,
         database: base_database,
         priv: "priv/repo"
       )

config :postgres_to_ecto_demo,
       PostgresToEctoDemo.TargetRepo,
       Keyword.merge(common_repo_config,
         database: base_database <> "_target",
         priv: "priv/target_repo"
       )
