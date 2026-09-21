defmodule PgToEcto.BaselineTest do
  use ExUnit.Case, async: true

  alias PgToEcto.Baseline

  defmodule Repo do
    def config, do: []
  end

  describe "render/3" do
    test "renders deterministic dependency-safe baseline operations" do
      profile = %{repo: Repo, options: [show_generated_key_comment: true]}
      model = wave_one_model()

      assert {:ok, rendered} = Baseline.render(profile, model)
      assert {:ok, repeated} = Baseline.render(profile, model)
      assert rendered.source == repeated.source
      assert rendered.key == repeated.key
      assert {:ok, _ast} = Sourceror.parse_string(rendered.source)
      assert rendered.source =~ "@pg_to_ecto_key \"pgte1:"
      assert rendered.source =~ "generated_change do"

      assert rendered.source =~
               "execute(\"CREATE SCHEMA \\\"sales\\\"\", \"DROP SCHEMA \\\"sales\\\"\")"

      refute rendered.source =~ "CREATE SCHEMA IF NOT EXISTS"
      refute rendered.source =~ "DROP SCHEMA IF EXISTS"
      refute rendered.source =~ "CASCADE\")"
      assert rendered.source =~ "add :active, :boolean, null: false, default: true"
      assert rendered.source =~ "add :email, :text, null: false"
      assert rendered.source =~ "unique_index(:customers, [:email]"
      assert rendered.source =~ "on_delete: :delete_all"

      namespace_position =
        :binary.match(rendered.source, "CREATE SCHEMA \\\"sales\\\"") |> elem(0)

      customers_position = :binary.match(rendered.source, "create table(:customers") |> elem(0)
      orders_position = :binary.match(rendered.source, "create table(:orders") |> elem(0)
      assert namespace_position < customers_position
      assert customers_position < orders_position
    end

    test "renders the supported referential actions for delete and update" do
      assert {:ok, rendered} = Baseline.render(%{repo: Repo, options: []}, wave_one_model())

      assert rendered_column_block(rendered.source, "customer_id") ==
               """
               add :customer_id,
                   references(:customers,
                     type: :bigint,
                     name: "orders_customer_id_fkey",
                     on_delete: :delete_all
                   ),
                   null: false
               """
               |> String.trim()

      assert rendered_column_block(rendered.source, "delete_restrict_customer_id") ==
               """
               add :delete_restrict_customer_id,
                   references(:customers,
                     type: :bigint,
                     name: "orders_delete_restrict_customer_id_fkey",
                     on_delete: :restrict,
                     on_update: :update_all
                   ),
                   null: true
               """
               |> String.trim()

      assert rendered_column_block(rendered.source, "delete_nilify_customer_id") ==
               """
               add :delete_nilify_customer_id,
                   references(:customers,
                     type: :bigint,
                     name: "orders_delete_nilify_customer_id_fkey",
                     on_delete: :nilify_all,
                     on_update: :restrict
                   ),
                   null: true
               """
               |> String.trim()

      assert rendered_column_block(rendered.source, "update_nilify_customer_id") ==
               """
               add :update_nilify_customer_id,
                   references(:customers,
                     type: :bigint,
                     name: "orders_update_nilify_customer_id_fkey",
                     on_update: :nilify_all
                   ),
                   null: true
               """
               |> String.trim()
    end

    test "blocks SET DEFAULT referential actions on delete and update" do
      for action <- [:delete_action, :update_action] do
        foreign_key = Map.put(selected_foreign_key(), action, :set_default)
        model = model_with_orders_foreign_key(foreign_key)

        assert {:error, diagnostics} = Baseline.render(%{repo: Repo, options: []}, model)
        assert Enum.any?(diagnostics, &(&1.code == :unsupported_foreign_key_action))

        action_name =
          case action do
            :delete_action -> "delete"
            :update_action -> "update"
          end

        assert Enum.any?(diagnostics, fn diagnostic ->
                 String.contains?(diagnostic.message, "SET DEFAULT") and
                   String.contains?(diagnostic.message, action_name)
               end)
      end
    end

    test "warns and preserves local columns for foreign keys to unselected tables" do
      model = wave_one_model()
      [orders, customers, invoices] = model.tables
      customers = %{customers | foreign_keys: []}
      orders = %{orders | foreign_keys: [unselected_foreign_key()]}
      model = %{model | tables: [orders, customers, invoices]}

      assert {:ok, rendered} = Baseline.render(%{repo: Repo, options: []}, model)
      assert Enum.any?(rendered.diagnostics, &(&1.code == :unselected_referenced_table))
      assert rendered.source =~ "add :audit_event_id, :bigint, null: true"
      refute rendered.source =~ "references(:audit_events"
    end

    test "preserves user source around the generated region" do
      profile = %{repo: Repo, options: [show_generated_key_comment: true]}
      assert {:ok, initial} = Baseline.render(profile, wave_one_model())

      existing =
        initial.source
        |> String.replace("def change do", "def change do\n    IO.puts(:before_generated)")
        |> String.replace(
          "    end\n  end\nend\n",
          "    end\n    IO.puts(:after_generated)\n  end\nend\n"
        )

      assert {:ok, updated} = Baseline.render(profile, wave_one_model(), existing)
      assert updated.source =~ "IO.puts(:before_generated)"
      assert updated.source =~ "IO.puts(:after_generated)"
      assert updated.source =~ "generated_change do"
      assert updated.key == initial.key
    end
  end

  describe "Ecto migration defaults" do
    test "tracks the reference defaults used for NO ACTION" do
      {:ok, runner} =
        Ecto.Migration.Runner.start_link({
          self(),
          Repo,
          [],
          __MODULE__,
          :forward,
          :up,
          %{level: :info, sql: false}
        })

      Ecto.Migration.Runner.metadata(runner, [])

      try do
        reference = Ecto.Migration.references(:customers)

        assert reference.on_delete == :nothing
        assert reference.on_update == :nothing
      after
        Ecto.Migration.Runner.stop()
      end
    end
  end

  defp rendered_column_block(source, column) do
    lines = String.split(source, "\n")
    header = "        add :#{column},"

    {_before, block} = Enum.split_while(lines, &(&1 != header))
    [first | _rest] = block

    block
    |> Enum.take_while(fn line ->
      line == first or not String.starts_with?(line, "        add ")
    end)
    |> Enum.map_join("\n", fn line ->
      if String.starts_with?(line, "        "),
        do: String.slice(line, 8..-1//1),
        else: line
    end)
    |> String.trim()
  end

  defp wave_one_model do
    %{
      tables: [
        %{
          identity: %{schema: "public", table: "orders"},
          relation_kind: :table,
          primary_key: ["id"],
          columns: [
            column("id", :bigserial, false, :bigserial, nil),
            column("customer_id", :bigint, false, :bigint, nil),
            column("delete_restrict_customer_id", :bigint, true, :bigint, nil),
            column("delete_nilify_customer_id", :bigint, true, :bigint, nil),
            column("update_nilify_customer_id", :bigint, true, :bigint, nil),
            column("active", :boolean, false, :boolean, true),
            column("audit_event_id", :bigint, true, :bigint, nil)
          ],
          foreign_keys: [
            selected_foreign_key(),
            action_foreign_key(
              "orders_delete_restrict_customer_id_fkey",
              "delete_restrict_customer_id",
              :cascade,
              :restrict
            ),
            action_foreign_key(
              "orders_delete_nilify_customer_id_fkey",
              "delete_nilify_customer_id",
              :restrict,
              :set_null
            ),
            action_foreign_key(
              "orders_update_nilify_customer_id_fkey",
              "update_nilify_customer_id",
              :set_null,
              :no_action
            ),
            unselected_foreign_key()
          ],
          indexes: [index("orders_customer_id_index", false, ["customer_id"])]
        },
        %{
          identity: %{schema: "public", table: "customers"},
          relation_kind: :table,
          primary_key: ["id"],
          columns: [
            column("id", :bigserial, false, :bigserial, nil),
            column("email", :text, false, :text, nil)
          ],
          foreign_keys: [],
          indexes: [index("customers_email_index", true, ["email"])]
        },
        %{
          identity: %{schema: "sales", table: "invoices"},
          relation_kind: :table,
          primary_key: ["id"],
          columns: [
            column("id", :bigserial, false, :bigserial, nil),
            column("customer_id", :bigint, false, :bigint, nil)
          ],
          foreign_keys: [selected_foreign_key("invoices_customer_id_fkey")],
          indexes: [index("invoices_customer_id_index", false, ["customer_id"])]
        }
      ]
    }
  end

  defp column(name, migration, nullable, type_name, default) do
    %{
      name: name,
      nullable: nullable,
      mapping: %{migration: migration, disposition: :exact},
      serial_kind: if(migration == :bigserial, do: :bigserial, else: nil),
      type: %{postgres: %{formatted: Atom.to_string(type_name), name: Atom.to_string(type_name)}},
      default: default_value(default)
    }
  end

  defp default_value(nil), do: %{classification: :none, value: nil}
  defp default_value(value), do: %{classification: :safe_literal, value: value}

  defp selected_foreign_key(name \\ "orders_customer_id_fkey") do
    %{
      name: name,
      source_columns: ["customer_id"],
      target_identity: {"public", "customers"},
      target_columns: ["id"],
      update_action: :no_action,
      delete_action: :cascade,
      mapping_disposition: :exact,
      selected_target?: true
    }
  end

  defp action_foreign_key(name, source_column, update_action, delete_action) do
    %{
      name: name,
      source_columns: [source_column],
      target_identity: {"public", "customers"},
      target_columns: ["id"],
      update_action: update_action,
      delete_action: delete_action,
      mapping_disposition: :exact,
      selected_target?: true
    }
  end

  defp model_with_orders_foreign_key(foreign_key) do
    model = wave_one_model()
    [orders, customers, invoices] = model.tables

    %{
      model
      | tables: [
          %{orders | foreign_keys: [foreign_key, unselected_foreign_key()]},
          customers,
          invoices
        ]
    }
  end

  defp unselected_foreign_key do
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
  end

  defp index(name, unique?, columns) do
    %{name: name, unique?: unique?, columns: columns, mapping_disposition: :exact}
  end
end
