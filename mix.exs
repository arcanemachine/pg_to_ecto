defmodule PgToEcto.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :pg_to_ecto,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "PgToEcto",
      description: "Phase 0 source-management macros for generated Ecto regions.",
      source_url: "https://github.com/nicholas-moen/pg_to_ecto",
      homepage_url: "https://github.com/nicholas-moen/pg_to_ecto",
      docs: [main: "readme", extras: ["README.md", "CHANGELOG.md"]],
      package: package(),
      test_coverage: [tool: ExUnit]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ecto, "~> 3.13"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.22"},
      {:sourceror, "~> 1.12", runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/nicholas-moen/pg_to_ecto"},
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
