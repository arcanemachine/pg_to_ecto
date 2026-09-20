defmodule PgToEctoDemo.SourceRepo do
  use Ecto.Repo,
    otp_app: :pg_to_ecto_demo,
    adapter: Ecto.Adapters.Postgres
end

defmodule PgToEctoDemo.TargetRepo do
  use Ecto.Repo,
    otp_app: :pg_to_ecto_demo,
    adapter: Ecto.Adapters.Postgres
end
