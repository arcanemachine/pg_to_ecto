defmodule PgToEctoDemo.IntrospectionTest do
  use ExUnit.Case, async: false

  alias PgToEctoDemo.Database

  setup_all do
    :ok = Database.reset!()
    {:ok, source_repo} = PgToEctoDemo.SourceRepo.start_link()
    Process.unlink(source_repo)

    on_exit(fn ->
      if Process.alive?(source_repo) do
        Supervisor.stop(source_repo)
      end
    end)

    assert {:ok, profile, []} = PgToEcto.Profile.validate(PgToEctoDemo.Profile)
    assert {:ok, model} = PgToEcto.Introspection.introspect_profile(profile)
    %{model: model}
  end

  test "returns selected ordinary relations with ordered keys and columns", %{model: model} do
    assert is_integer(model.server_version.server_version_num)

    assert Enum.map(model.tables, & &1.identity) == [
             %{schema: "public", table: "customers"},
             %{schema: "public", table: "orders"},
             %{schema: "sales", table: "invoices"}
           ]

    assert Enum.all?(model.tables, &(&1.relation_kind == :table))
    assert Enum.all?(model.tables, &(&1.primary_key == ["id"]))

    assert Enum.map(table(model, %{schema: "public", table: "customers"}).columns, & &1.name) == [
             "id",
             "email",
             "name",
             "active",
             "credit_limit",
             "audit_event_id"
           ]

    assert Enum.map(table(model, %{schema: "public", table: "orders"}).columns, & &1.name) == [
             "id",
             "customer_id",
             "external_ref",
             "quantity",
             "shipped",
             "audit_event_id"
           ]

    assert Enum.map(table(model, %{schema: "sales", table: "invoices"}).columns, & &1.name) == [
             "id",
             "customer_id",
             "code",
             "amount"
           ]
  end

  test "returns column types modifiers nullability and default classifications", %{model: model} do
    customers = table(model, %{schema: "public", table: "customers"})
    orders = table(model, %{schema: "public", table: "orders"})

    assert hd(customers.columns).mapping == %{
             schema: :id,
             migration: :bigserial,
             disposition: :exact
           }

    assert hd(customers.columns).serial_kind == :bigserial
    assert hd(customers.columns).owned_sequence == "public.customers_id_seq"

    assert hd(customers.columns).type.postgres == %{
             oid: 20,
             schema: "pg_catalog",
             name: "int8",
             modifier: -1,
             formatted: "bigint"
           }

    assert Enum.find(customers.columns, &(&1.name == "email")).type.postgres == %{
             oid: 25,
             schema: "pg_catalog",
             name: "text",
             modifier: -1,
             formatted: "text"
           }

    assert Enum.find(customers.columns, &(&1.name == "active")).type.postgres == %{
             oid: 16,
             schema: "pg_catalog",
             name: "bool",
             modifier: -1,
             formatted: "boolean"
           }

    assert Enum.find(customers.columns, &(&1.name == "credit_limit")).type.postgres == %{
             oid: 23,
             schema: "pg_catalog",
             name: "int4",
             modifier: -1,
             formatted: "integer"
           }

    assert Enum.find(customers.columns, &(&1.name == "email")).nullable == false
    assert Enum.find(customers.columns, &(&1.name == "audit_event_id")).nullable == true

    assert Enum.find(customers.columns, &(&1.name == "active")).default == %{
             expression: "true",
             classification: :safe_literal,
             value: true,
             type: :boolean
           }

    assert Enum.find(customers.columns, &(&1.name == "credit_limit")).default == %{
             expression: "0",
             classification: :safe_literal,
             value: 0,
             type: :integer
           }

    assert Enum.find(orders.columns, &(&1.name == "quantity")).default == %{
             expression: "1",
             classification: :safe_literal,
             value: 1,
             type: :integer
           }

    assert Enum.find(orders.columns, &(&1.name == "shipped")).default == %{
             expression: "false",
             classification: :safe_literal,
             value: false,
             type: :boolean
           }
  end

  test "returns selected and unselected foreign key facts", %{model: model} do
    orders = table(model, %{schema: "public", table: "orders"})

    assert [
             %{
               name: "orders_customer_id_fkey",
               source_columns: ["customer_id"],
               target_identity: {"public", "customers"},
               target_columns: ["id"],
               update_action: :no_action,
               delete_action: :cascade,
               mapping_disposition: :exact,
               selected_target?: true
             }
           ] = Enum.filter(orders.foreign_keys, &(&1.name == "orders_customer_id_fkey"))

    assert [
             %{
               name: "orders_audit_event_id_fkey",
               source_columns: ["audit_event_id"],
               target_identity: {"internal", "audit_events"},
               target_columns: ["id"],
               update_action: :no_action,
               delete_action: :set_null,
               mapping_disposition: :omitted_with_warning,
               selected_target?: false
             }
           ] = Enum.filter(orders.foreign_keys, &(&1.name == "orders_audit_event_id_fkey"))
  end

  test "returns ordinary and unique index identities and columns", %{model: model} do
    customers = table(model, %{schema: "public", table: "customers"})
    orders = table(model, %{schema: "public", table: "orders"})
    invoices = table(model, %{schema: "sales", table: "invoices"})

    assert Enum.any?(customers.indexes, fn index ->
             index.source_identity == {"public", "customers"} and
               index.name == "customers_email_index" and index.unique? and
               index.columns == ["email"]
           end)

    assert Enum.any?(orders.indexes, fn index ->
             index.source_identity == {"public", "orders"} and
               index.name == "orders_customer_id_index" and not index.unique? and
               index.columns == ["customer_id"]
           end)

    assert Enum.any?(orders.indexes, fn index ->
             index.name == "orders_external_ref_index" and index.unique? and
               index.columns == ["external_ref"]
           end)

    assert Enum.any?(invoices.indexes, fn index ->
             index.source_identity == {"sales", "invoices"} and
               index.name == "invoices_customer_id_index" and
               index.columns == ["customer_id"]
           end)
  end

  defp table(model, identity), do: Enum.find(model.tables, &(&1.identity == identity))
end
