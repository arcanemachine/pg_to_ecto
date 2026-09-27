defmodule PostgresToEctoDemo.SourceRepo do
  use Ecto.Repo,
    otp_app: :postgres_to_ecto_demo,
    adapter: Ecto.Adapters.Postgres
end

defmodule PostgresToEctoDemo.TargetRepo do
  use Ecto.Repo,
    otp_app: :postgres_to_ecto_demo,
    adapter: Ecto.Adapters.Postgres
end
