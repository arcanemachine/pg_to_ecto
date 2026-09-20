defmodule PgToEctoDemo.Database do
  @moduledoc """
  Safety-checked lifecycle helpers for the disposable demo databases.

  The module performs no work at load time. Setup and reset are explicit
  commands, and every destructive operation validates both database names
  before connecting to PostgreSQL.
  """

  @default_host "localhost"
  @default_port 5432
  @default_user "postgres"
  @default_database "pg_to_ecto_demo_test"
  @default_password "your_postgres_password"
  @safe_database_pattern ~r/\Apg_to_ecto_demo[a-z0-9_-]*\z/
  @maximum_database_name_length 63

  @type role :: :source | :target
  @type settings :: %{
          host: String.t(),
          port: pos_integer(),
          user: String.t(),
          password: String.t(),
          database: String.t(),
          target_database: String.t()
        }

  @spec setup!() :: :ok
  def setup! do
    with {:ok, settings} <- settings(),
         :ok <- validate_database_names(settings),
         :ok <- ensure_database(settings, settings.database),
         :ok <- ensure_database(settings, settings.target_database),
         :ok <- migrate_source() do
      :ok
    else
      {:error, message} -> raise RuntimeError, message
    end
  end

  @spec reset!() :: :ok
  def reset! do
    with {:ok, settings} <- settings(),
         :ok <- validate_database_names(settings),
         :ok <- drop_database(settings, settings.target_database),
         :ok <- drop_database(settings, settings.database),
         :ok <- ensure_database(settings, settings.database),
         :ok <- ensure_database(settings, settings.target_database),
         :ok <- migrate_source() do
      :ok
    else
      {:error, message} -> raise RuntimeError, message
    end
  end

  @spec drop!() :: :ok
  def drop! do
    with {:ok, settings} <- settings(),
         :ok <- validate_database_names(settings),
         :ok <- drop_database(settings, settings.target_database),
         :ok <- drop_database(settings, settings.database) do
      :ok
    else
      {:error, message} -> raise RuntimeError, message
    end
  end

  @spec settings() :: {:ok, settings()} | {:error, String.t()}
  def settings do
    with {:ok, password} <- required_password(),
         {:ok, port} <- configured_port() do
      database = System.get_env("POSTGRES_DB", @default_database)

      {:ok,
       %{
         host: System.get_env("POSTGRES_HOST", @default_host),
         port: port,
         user: System.get_env("POSTGRES_USER", @default_user),
         password: password,
         database: database,
         target_database: database <> "_target"
       }}
    end
  end

  @spec query(role(), String.t(), list()) :: {:ok, Postgrex.Result.t()} | {:error, term()}
  def query(role, sql, params \\ []) when role in [:source, :target] and is_binary(sql) do
    with {:ok, settings} <- settings(),
         :ok <- validate_database_names(settings),
         {:ok, connection} <- connect(settings, role) do
      try do
        Postgrex.query(connection, sql, params)
      after
        GenServer.stop(connection)
      end
    end
  end

  @spec source_migrations_path() :: String.t()
  def source_migrations_path do
    Path.expand("../../priv/source_repo/migrations", __DIR__)
  end

  defp migrate_source do
    case Ecto.Migrator.with_repo(PgToEctoDemo.SourceRepo, fn repo ->
           if Code.ensure_loaded?(PgToEctoDemo.SourceRepo.Migrations.Wave1Fixture) do
             Ecto.Migrator.up(repo, 1, PgToEctoDemo.SourceRepo.Migrations.Wave1Fixture)
           else
             Ecto.Migrator.run(repo, [source_migrations_path()], :up, all: true)
           end
         end) do
      {:ok, _migrations, _started} ->
        :ok

      {:error, _reason} ->
        {:error,
         "Source migrations failed. Check PostgreSQL connectivity and the checked-in fixture migration."}
    end
  rescue
    _exception ->
      {:error,
       "Source migrations failed. Check PostgreSQL connectivity and the checked-in fixture migration."}
  end

  defp ensure_database(settings, database) do
    case with_maintenance_connection(settings, &database_exists_or_create(&1, database)) do
      {:ok, _result} ->
        :ok

      {:error, _reason} ->
        {
          :error,
          "Could not create database #{database}. Check PostgreSQL connectivity and CREATE DATABASE permission."
        }
    end
  end

  defp database_exists_or_create(connection, database) do
    case Postgrex.query(connection, "SELECT 1 FROM pg_database WHERE datname = $1", [database]) do
      {:ok, %Postgrex.Result{rows: [[1]]}} -> {:ok, :existing}
      {:ok, _result} -> Postgrex.query(connection, ~s(CREATE DATABASE "#{database}"), [])
      {:error, reason} -> {:error, reason}
    end
  end

  defp drop_database(settings, database) do
    result =
      with_maintenance_connection(settings, fn connection ->
        Postgrex.query(connection, ~s|DROP DATABASE IF EXISTS "#{database}" WITH (FORCE)|, [])
      end)

    case result do
      {:ok, _result} ->
        :ok

      {:error, _reason} ->
        {
          :error,
          "Could not drop database #{database}. Check PostgreSQL connectivity and database permissions."
        }
    end
  end

  defp with_maintenance_connection(settings, function) do
    case maintenance_connection(settings) do
      {:ok, connection} ->
        try do
          function.(connection)
        after
          GenServer.stop(connection)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maintenance_connection(settings) do
    connect(settings, "postgres")
  end

  defp connect(settings, :source), do: connect(settings, settings.database)
  defp connect(settings, :target), do: connect(settings, settings.target_database)

  defp connect(settings, database),
    do: Postgrex.start_link(connection_options(settings, database))

  defp connection_options(settings, database) do
    [
      hostname: settings.host,
      port: settings.port,
      username: settings.user,
      password: settings.password,
      database: database,
      pool_size: 1
    ]
  end

  defp validate_database_names(settings) do
    with :ok <- validate_database_name(settings.database),
         :ok <- validate_database_name(settings.target_database) do
      :ok
    end
  end

  defp validate_database_name(database)
       when is_binary(database) and byte_size(database) <= @maximum_database_name_length do
    if Regex.match?(@safe_database_pattern, database) do
      :ok
    else
      {:error,
       "Refusing lifecycle operation for database #{inspect(database)}. " <>
         "Names must start with pg_to_ecto_demo and contain only lowercase letters, digits, _ or -."}
    end
  end

  defp validate_database_name(database) do
    {:error,
     "Refusing lifecycle operation for database #{inspect(database)}. " <>
       "The name must be a short pg_to_ecto_demo* database name."}
  end

  defp required_password do
    case System.get_env("POSTGRES_PASSWORD") do
      password when is_binary(password) and password != "" -> {:ok, password}
      _ -> {:ok, @default_password}
    end
  end

  defp configured_port do
    case Integer.parse(System.get_env("POSTGRES_PORT", Integer.to_string(@default_port))) do
      {port, ""} when port > 0 and port <= 65_535 -> {:ok, port}
      _ -> {:error, "POSTGRES_PORT must be an integer between 1 and 65535."}
    end
  end
end
