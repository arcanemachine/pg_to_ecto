defmodule PgToEctoDemo.DatabaseTest do
  use ExUnit.Case, async: false

  alias PgToEctoDemo.Database

  setup_all do
    :ok = Database.reset!()
    :ok
  end

  test "source fixture contains the selected and unselected tables" do
    rows =
      rows!(
        :source,
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema IN ('public', 'internal', 'sales')
          AND table_type = 'BASE TABLE'
        ORDER BY table_schema, table_name
        """
      )

    assert ["internal", "audit_events"] in rows
    assert ["public", "customers"] in rows
    assert ["public", "orders"] in rows
    assert ["sales", "invoices"] in rows
  end

  test "source fixture preserves scalar types nullability and safe defaults" do
    rows =
      rows!(
        :source,
        """
        SELECT table_schema, table_name, column_name, is_nullable, column_default, data_type
        FROM information_schema.columns
        WHERE (table_schema, table_name) IN
          (('public', 'customers'), ('public', 'orders'), ('sales', 'invoices'))
        ORDER BY table_schema, table_name, ordinal_position
        """
      )

    assert Enum.any?(rows, fn
             ["public", "customers", "id", "NO", default, "bigint"] ->
               String.starts_with?(default, "nextval(")

             _row ->
               false
           end)

    assert Enum.any?(rows, fn
             ["public", "orders", "id", "NO", default, "bigint"] ->
               String.starts_with?(default, "nextval(")

             _row ->
               false
           end)

    assert column(rows, "public", "customers", "email") == {"NO", nil, "text"}
    assert column(rows, "public", "customers", "active") == {"NO", "true", "boolean"}
    assert column(rows, "public", "customers", "credit_limit") == {"NO", "0", "integer"}
    assert column(rows, "public", "orders", "quantity") == {"NO", "1", "integer"}
    assert column(rows, "public", "orders", "shipped") == {"NO", "false", "boolean"}
    assert column(rows, "sales", "invoices", "code") == {"NO", nil, "text"}
  end

  test "source fixture includes the supported selected and unselected foreign key actions" do
    rows =
      rows!(
        :source,
        """
        SELECT
          conrelid::regclass::text,
          (SELECT attname FROM pg_attribute
           WHERE attrelid = conrelid AND attnum = conkey[1]),
          confrelid::regclass::text,
          CASE confupdtype
            WHEN 'c' THEN 'CASCADE'
            WHEN 'n' THEN 'SET NULL'
            WHEN 'r' THEN 'RESTRICT'
            WHEN 'a' THEN 'NO ACTION'
          END,
          CASE confdeltype
            WHEN 'c' THEN 'CASCADE'
            WHEN 'n' THEN 'SET NULL'
            WHEN 'r' THEN 'RESTRICT'
            WHEN 'a' THEN 'NO ACTION'
          END
        FROM pg_constraint
        WHERE contype = 'f'
          AND conrelid::regclass::text IN ('customers', 'orders')
        ORDER BY conrelid::regclass::text, conkey[1]
        """
      )

    assert ["orders", "customer_id", "customers", "NO ACTION", "CASCADE"] in rows

    assert [
             "orders",
             "delete_restrict_customer_id",
             "customers",
             "CASCADE",
             "RESTRICT"
           ] in rows

    assert [
             "orders",
             "delete_nilify_customer_id",
             "customers",
             "RESTRICT",
             "SET NULL"
           ] in rows

    assert [
             "orders",
             "update_nilify_customer_id",
             "customers",
             "SET NULL",
             "NO ACTION"
           ] in rows

    assert ["orders", "audit_event_id", "internal.audit_events", "NO ACTION", "SET NULL"] in rows
  end

  test "source fixture includes ordinary and unique indexes" do
    rows =
      rows!(
        :source,
        """
        SELECT schemaname, tablename, indexname, indexdef
        FROM pg_indexes
        WHERE schemaname IN ('public', 'internal', 'sales')
        ORDER BY schemaname, tablename, indexname
        """
      )

    assert Enum.any?(rows, fn [schema, table, name, _definition] ->
             {schema, table, name} == {"public", "orders", "orders_customer_id_index"}
           end)

    assert Enum.any?(rows, fn [schema, table, name, definition] ->
             {schema, table, name} == {"public", "customers", "customers_email_index"} and
               String.contains?(definition, "UNIQUE")
           end)

    assert Enum.any?(rows, fn [schema, table, name, definition] ->
             {schema, table, name} == {"public", "orders", "orders_external_ref_index"} and
               String.contains?(definition, "UNIQUE")
           end)

    assert Enum.any?(rows, fn [schema, table, name, _definition] ->
             {schema, table, name} == {"sales", "invoices", "invoices_customer_id_index"}
           end)
  end

  test "profile selects the public and non-public fixtures explicitly" do
    assert Application.get_env(:pg_to_ecto, :generator) == PgToEctoDemo.Profile

    assert {:ok, validated, []} = PgToEcto.Profile.validate(PgToEctoDemo.Profile)

    assert Enum.map(validated.tables, &{&1.schema, &1.table}) == [
             {"public", "customers"},
             {"public", "orders"},
             {"sales", "invoices"}
           ]
  end

  test "target database is available as a clean structural destination" do
    assert [] =
             rows!(
               :target,
               """
               SELECT table_schema, table_name
               FROM information_schema.tables
               WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
               """
             )
  end

  test "requires a non-empty demo password" do
    with_env([{"POSTGRES_PASSWORD", nil}], fn ->
      assert {:error, "POSTGRES_PASSWORD must be set" <> _rest} = Database.settings()
    end)

    with_env([{"POSTGRES_PASSWORD", ""}], fn ->
      assert {:error, "POSTGRES_PASSWORD must be set" <> _rest} = Database.settings()
    end)

    with_env([{"POSTGRES_PASSWORD", "local-demo-password"}], fn ->
      assert {:ok, settings} = Database.settings()
      assert settings.password == "local-demo-password"
    end)
  end

  test "config file requires a non-empty password" do
    with_env([{"POSTGRES_PASSWORD", nil}], fn ->
      assert_raise System.EnvError, &config_password/0
    end)

    with_env([{"POSTGRES_PASSWORD", ""}], fn ->
      assert_raise ArgumentError, ~r/POSTGRES_PASSWORD must be set/, &config_password/0
    end)
  end

  test "config file uses a non-empty password override" do
    with_env([{"POSTGRES_PASSWORD", "config-override-password"}], fn ->
      assert config_password() == "config-override-password"
    end)
  end

  test "derives the default and overridden target database names" do
    with_env([{"POSTGRES_DB", nil}], fn ->
      assert {:ok, settings} = Database.settings()
      assert settings.database == "pg_to_ecto_demo_test"
      assert settings.target_database == "pg_to_ecto_demo_test_target"
    end)

    with_env([{"POSTGRES_DB", "pg_to_ecto_demo_custom"}], fn ->
      assert {:ok, settings} = Database.settings()
      assert settings.database == "pg_to_ecto_demo_custom"
      assert settings.target_database == "pg_to_ecto_demo_custom_target"
    end)
  end

  test "rejects malformed ports before any connection" do
    with_env([{"POSTGRES_PORT", "not-a-port"}], fn ->
      assert {:error, "POSTGRES_PORT must be an integer" <> _rest} = Database.settings()
    end)

    with_env([{"POSTGRES_PORT", "65536"}], fn ->
      assert {:error, "POSTGRES_PORT must be an integer" <> _rest} = Database.settings()
    end)
  end

  test "rejects overlong and unsafe derived target names before connecting" do
    overlong_base = "pg_to_ecto_demo" <> String.duplicate("a", 47)

    with_env([{"POSTGRES_DB", overlong_base}], fn ->
      assert_raise RuntimeError, ~r/short pg_to_ecto_demo/, fn ->
        Database.reset!()
      end
    end)

    with_env([{"POSTGRES_DB", "pg_to_ecto_demo_test!"}], fn ->
      assert_raise RuntimeError, ~r/Names must start with pg_to_ecto_demo/, fn ->
        Database.reset!()
      end
    end)
  end

  test "lifecycle commands reject non-disposable database names before connecting" do
    previous = System.get_env("POSTGRES_DB")
    System.put_env("POSTGRES_DB", "production")

    on_exit(fn ->
      if is_nil(previous) do
        System.delete_env("POSTGRES_DB")
      else
        System.put_env("POSTGRES_DB", previous)
      end
    end)

    assert_raise RuntimeError, ~r/Refusing lifecycle operation/, fn ->
      Database.reset!()
    end
  end

  defp config_password do
    config = Config.Reader.read!(Path.expand("../config/config.exs", __DIR__))

    config
    |> Keyword.fetch!(:pg_to_ecto_demo)
    |> Keyword.fetch!(PgToEctoDemo.SourceRepo)
    |> Keyword.fetch!(:password)
  end

  defp with_env(overrides, function) do
    previous = Map.new(overrides, fn {name, _value} -> {name, System.get_env(name)} end)

    Enum.each(overrides, fn
      {name, nil} -> System.delete_env(name)
      {name, value} -> System.put_env(name, value)
    end)

    try do
      function.()
    after
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end
  end

  defp rows!(role, sql) do
    assert {:ok, %Postgrex.Result{rows: rows}} = Database.query(role, sql)
    rows
  end

  defp column(rows, schema_name, table_name, column_name) do
    assert [[^schema_name, ^table_name, ^column_name, nullable, default, data_type]] =
             Enum.filter(rows, fn [schema, table, column, _nullable, _default, _type] ->
               schema == schema_name and table == table_name and column == column_name
             end)

    {nullable, default, data_type}
  end
end
