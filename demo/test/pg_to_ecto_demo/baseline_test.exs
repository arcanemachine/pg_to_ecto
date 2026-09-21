defmodule PgToEctoDemo.BaselineTest do
  use ExUnit.Case, async: false

  alias PgToEctoDemo.Database

  setup_all do
    :ok = Database.reset!()
    {:ok, source_repo} = PgToEctoDemo.SourceRepo.start_link()
    Process.unlink(source_repo)

    on_exit(fn ->
      if Process.alive?(source_repo), do: Supervisor.stop(source_repo)
    end)

    assert {:ok, profile, []} = PgToEcto.Profile.validate(PgToEctoDemo.Profile)

    assert {:ok, source_model} =
             PgToEcto.Introspection.introspect(PgToEctoDemo.SourceRepo, profile.tables)

    assert {:ok, rendered} = PgToEcto.Baseline.render(profile, source_model)
    migration_path = Path.expand("priv/repo/migrations", File.cwd!())
    migration_file = Path.join(migration_path, "00001_pg_to_ecto.exs")
    assert {:ok, artifact} = File.read(migration_file)
    assert artifact == rendered.source

    assert {:ok, result} = PgToEcto.generate(PgToEctoDemo.Profile)
    assert Enum.any?(result.diagnostics, &(&1.code == :unselected_referenced_table))

    assert {:ok, [1], []} =
             Ecto.Migrator.with_repo(PgToEctoDemo.TargetRepo, fn repo ->
               Ecto.Migrator.run(repo, [migration_path], :up, all: true)
             end)

    {:ok, target_repo} = PgToEctoDemo.TargetRepo.start_link()
    Process.unlink(target_repo)

    on_exit(fn ->
      if Process.alive?(target_repo), do: Supervisor.stop(target_repo)
    end)

    assert {:ok, target_model} =
             PgToEcto.Introspection.introspect(PgToEctoDemo.TargetRepo, profile.tables)

    %{source_model: source_model, target_model: target_model}
  end

  test "generated baseline preserves supported source structure", %{
    source_model: source,
    target_model: target
  } do
    assert normalize_model(source) == normalize_model(target)
  end

  test "database defaults are applied independently of catalog comparison" do
    email = unique_value("default")

    assert {:ok, %Postgrex.Result{rows: [[id, true, 0]]}} =
             Database.query(
               :target,
               "INSERT INTO customers (email, name) VALUES ($1, $2) RETURNING id, active, credit_limit",
               [email, "Default test"]
             )

    assert {:ok, _result} = Database.query(:target, "DELETE FROM customers WHERE id = $1", [id])
  end

  test "not-null constraints reject missing required values" do
    assert {:error, %Postgrex.Error{postgres: %{code: :not_null_violation}}} =
             Database.query(:target, "INSERT INTO customers (email) VALUES ($1)", [
               unique_value("not-null")
             ])
  end

  test "unique indexes reject duplicate values" do
    email = unique_value("unique")

    assert {:ok, %Postgrex.Result{rows: [[id]]}} =
             Database.query(
               :target,
               "INSERT INTO customers (email, name) VALUES ($1, $2) RETURNING id",
               [email, "Unique test"]
             )

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             Database.query(:target, "INSERT INTO customers (email, name) VALUES ($1, $2)", [
               email,
               "Duplicate test"
             ])

    assert {:ok, _result} = Database.query(:target, "DELETE FROM customers WHERE id = $1", [id])
  end

  describe "referential actions" do
    test "rejects missing targets and cascades configured deletes" do
      missing_customer_id = System.unique_integer([:positive]) + 100_000_000

      assert {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} =
               Database.query(
                 :target,
                 "INSERT INTO orders (customer_id, external_ref) VALUES ($1, $2)",
                 [missing_customer_id, unique_value("missing-fk")]
               )

      customer_id = insert_customer("cascade")
      order_id = insert_order(customer_id)

      assert {:ok, _result} =
               Database.query(:target, "DELETE FROM customers WHERE id = $1", [customer_id])

      assert {:ok, %Postgrex.Result{rows: [[0]]}} =
               Database.query(:target, "SELECT count(*) FROM orders WHERE id = $1", [order_id])
    end

    test "applies each delete action independently" do
      anchor_id = insert_customer("delete-anchor")
      cascade_id = insert_customer("delete-cascade")
      restrict_id = insert_customer("delete-restrict")
      nilify_id = insert_customer("delete-nilify")
      no_action_id = insert_customer("delete-no-action")

      cascade_order_id = insert_order(cascade_id)
      restrict_order_id = insert_order(anchor_id, delete_restrict_customer_id: restrict_id)
      nilify_order_id = insert_order(anchor_id, delete_nilify_customer_id: nilify_id)
      no_action_order_id = insert_order(anchor_id, update_nilify_customer_id: no_action_id)

      assert {:ok, _result} =
               Database.query(:target, "DELETE FROM customers WHERE id = $1", [cascade_id])

      assert {:ok, %Postgrex.Result{rows: [[0]]}} =
               Database.query(:target, "SELECT count(*) FROM orders WHERE id = $1", [
                 cascade_order_id
               ])

      assert_foreign_key_violation("DELETE FROM customers WHERE id = $1", [restrict_id])
      assert_order_exists(restrict_order_id)

      assert {:ok, _result} =
               Database.query(:target, "DELETE FROM customers WHERE id = $1", [nilify_id])

      assert {:ok, %Postgrex.Result{rows: [[nil]]}} =
               Database.query(
                 :target,
                 "SELECT delete_nilify_customer_id FROM orders WHERE id = $1",
                 [nilify_order_id]
               )

      assert_foreign_key_violation("DELETE FROM customers WHERE id = $1", [no_action_id])
      assert_order_exists(no_action_order_id)
    end

    test "applies each update action independently" do
      no_action_id = insert_customer("update-no-action")
      cascade_parent_id = insert_customer("update-cascade")
      restrict_id = insert_customer("update-restrict")
      nilify_id = insert_customer("update-nilify")
      anchor_id = insert_customer("update-anchor")

      insert_order(no_action_id)
      cascade_order_id = insert_order(anchor_id, delete_restrict_customer_id: cascade_parent_id)
      restrict_order_id = insert_order(anchor_id, delete_nilify_customer_id: restrict_id)
      nilify_order_id = insert_order(anchor_id, update_nilify_customer_id: nilify_id)

      assert_foreign_key_violation("UPDATE customers SET id = $1 WHERE id = $2", [
        new_id(),
        no_action_id
      ])

      cascade_new_id = new_id()
      assert {:ok, _result} = update_customer_id(cascade_parent_id, cascade_new_id)

      assert {:ok, %Postgrex.Result{rows: [[^cascade_new_id]]}} =
               Database.query(
                 :target,
                 "SELECT delete_restrict_customer_id FROM orders WHERE id = $1",
                 [cascade_order_id]
               )

      assert_foreign_key_violation("UPDATE customers SET id = $1 WHERE id = $2", [
        new_id(),
        restrict_id
      ])

      assert_order_exists(restrict_order_id)

      nilify_new_id = new_id()
      assert {:ok, _result} = update_customer_id(nilify_id, nilify_new_id)

      assert {:ok, %Postgrex.Result{rows: [[nil]]}} =
               Database.query(
                 :target,
                 "SELECT update_nilify_customer_id FROM orders WHERE id = $1",
                 [nilify_order_id]
               )
    end
  end

  defp normalize_model(model) do
    Enum.map(model.tables, fn table ->
      %{
        identity: table.identity,
        columns:
          Enum.map(table.columns, fn column ->
            {column.name, column.type.postgres.name, column.nullable,
             column.default.classification, column.default.value}
          end),
        primary_key: table.primary_key,
        foreign_keys:
          table.foreign_keys
          |> Enum.filter(& &1.selected_target?)
          |> Enum.map(fn foreign_key ->
            {foreign_key.name, foreign_key.source_columns, foreign_key.target_identity,
             foreign_key.target_columns, foreign_key.update_action, foreign_key.delete_action}
          end),
        indexes:
          Enum.map(table.indexes, fn index ->
            {index.name, index.unique?, index.columns, index.mapping_disposition}
          end)
      }
    end)
  end

  defp insert_customer(prefix) do
    assert {:ok, %Postgrex.Result{rows: [[id]]}} =
             Database.query(
               :target,
               "INSERT INTO customers (email, name) VALUES ($1, $2) RETURNING id",
               [unique_value(prefix), prefix]
             )

    id
  end

  defp insert_order(customer_id, options \\ []) do
    assert {:ok, %Postgrex.Result{rows: [[id]]}} =
             Database.query(
               :target,
               """
               INSERT INTO orders (
                 customer_id,
                 external_ref,
                 delete_restrict_customer_id,
                 delete_nilify_customer_id,
                 update_nilify_customer_id
               ) VALUES ($1, $2, $3, $4, $5)
               RETURNING id
               """,
               [
                 customer_id,
                 unique_value("action-order"),
                 Keyword.get(options, :delete_restrict_customer_id),
                 Keyword.get(options, :delete_nilify_customer_id),
                 Keyword.get(options, :update_nilify_customer_id)
               ]
             )

    id
  end

  defp update_customer_id(old_id, new_id),
    do: Database.query(:target, "UPDATE customers SET id = $1 WHERE id = $2", [new_id, old_id])

  defp assert_foreign_key_violation(sql, params) do
    assert {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} =
             Database.query(:target, sql, params)
  end

  defp assert_order_exists(order_id) do
    assert {:ok, %Postgrex.Result{rows: [[1]]}} =
             Database.query(:target, "SELECT count(*) FROM orders WHERE id = $1", [order_id])
  end

  defp new_id, do: System.unique_integer([:positive]) + 200_000_000

  defp unique_value(prefix),
    do: prefix <> "_" <> Integer.to_string(System.unique_integer([:positive]))
end
