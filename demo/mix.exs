defmodule PostgresToEctoDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :postgres_to_ecto_demo,
      version: "0.1.0",
      elixir: "~> 1.17",
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:ecto, "~> 3.13"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.22"},
      {:postgres_to_ecto, path: "..", runtime: false}
    ]
  end

  defp aliases do
    [
      "demo.setup": ["run -e PostgresToEctoDemo.Database.setup!"],
      "demo.reset": ["run -e PostgresToEctoDemo.Database.reset!"],
      "demo.drop": ["run -e PostgresToEctoDemo.Database.drop!"]
    ]
  end
end
