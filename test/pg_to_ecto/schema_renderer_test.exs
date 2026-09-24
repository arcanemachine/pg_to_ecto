defmodule PgToEcto.SchemaRendererTest do
  use ExUnit.Case, async: true

  alias PgToEcto.SchemaRenderer

  defmodule Customer do
  end

  defmodule Order do
  end

  defmodule Tag do
  end

  describe "render/3" do
    test "renders fields, defaults, selected associations, and reverse cardinality" do
      assert {:ok, rendered} = SchemaRenderer.render(%{options: []}, model())

      customer = Enum.find(rendered.files, &(&1.module == Customer))
      order = Enum.find(rendered.files, &(&1.module == Order))

      assert customer.source =~ "field :active, :boolean, default: true"
      assert customer.source =~ "has_one :order, PgToEcto.SchemaRendererTest.Order"
      assert order.source =~ "field :customer_id, :integer"
      assert order.source =~ "belongs_to :customer, PgToEcto.SchemaRendererTest.Customer"
      assert order.source =~ "define_field: false"
      assert {:ok, _ast} = Sourceror.parse_string(customer.source)
    end

    test "applies sparse field and association overrides and skips automatic associations" do
      [customer, order] = model().tables

      customer =
        Map.put(customer, :overrides, [
          %{kind: :field, name: :display_name, type: :string, options: [source: :name]},
          {:skip_assocs, [:order]},
          %{
            kind: :has_many,
            name: :billing_orders,
            type: Order,
            options: [foreign_key: :billing_customer_id]
          }
        ])

      assert {:ok, rendered} =
               SchemaRenderer.render(%{options: []}, %{tables: [customer, order]})

      customer_source = Enum.find(rendered.files, &(&1.module == Customer)).source
      refute customer_source =~ "has_one :order"
      assert customer_source =~ "field :display_name, :string, source: :name"
      assert customer_source =~ "has_many :billing_orders"
    end

    test "warns for unselected references and unusual source identifiers" do
      [customer, order] = model().tables

      order =
        order
        |> Map.put(:foreign_keys, [
          %{
            source_columns: ["customer_id"],
            target_identity: {"internal", "people"},
            target_columns: ["id"],
            selected_target?: false
          }
        ])
        |> Map.update!(:columns, fn columns ->
          columns ++ [column("legacy-status", :string, %{classification: :none})]
        end)

      assert {:ok, rendered} =
               SchemaRenderer.render(%{options: []}, %{tables: [customer, order]})

      assert Enum.any?(rendered.diagnostics, &(&1.code == :unselected_referenced_table))
      assert Enum.any?(rendered.diagnostics, &(&1.code == :unusual_identifier))
      order_source = Enum.find(rendered.files, &(&1.module == Order)).source
      assert order_source =~ "field :legacy_status, :string, source: :\"legacy-status\""
      refute order_source =~ "belongs_to :customer"
    end

    test "preserves user schema source when force resets managed regions" do
      customer = hd(model().tables)
      assert {:ok, rendered} = SchemaRenderer.render(%{options: []}, %{tables: [customer]})
      file = hd(rendered.files)

      user_source =
        file.source
        |> String.replace_suffix(
          "  end\nend\n",
          "    field :display_name, :string, virtual: true\n    many_to_many :tags, PgToEcto.SchemaRendererTest.Tag, join_through: \"tags\"\n  end\n\n  def changeset(record, attrs), do: {record, attrs}\nend\n"
        )
        |> String.replace("field :active, :boolean", "field :active, :string")

      assert {:error, diagnostics} =
               SchemaRenderer.render(%{options: []}, %{tables: [customer]}, %{
                 file.path => user_source
               })

      assert Enum.any?(diagnostics, &(&1.code == :managed_key_mismatch))

      assert {:ok, forced} =
               SchemaRenderer.render(
                 %{options: []},
                 %{tables: [customer]},
                 %{file.path => user_source},
                 force: true
               )

      forced_source = hd(forced.files).source
      assert forced_source =~ "field :display_name, :string, virtual: true"
      assert forced_source =~ "many_to_many :tags"
      assert forced_source =~ "def changeset(record, attrs)"
      assert Enum.any?(forced.diagnostics, &(&1.code == :force_reset_managed_file))
    end

    test "adds a newly expected settings region without discarding user source" do
      customer = hd(model().tables)
      assert {:ok, rendered} = SchemaRenderer.render(%{options: []}, %{tables: [customer]})
      file = hd(rendered.files)

      user_source =
        file.source
        |> String.replace_suffix(
          "  end\nend\n",
          "    field :display_name, :string, virtual: true\n  end\n\n  def label(record), do: record.name\nend\n"
        )

      updated_customer = %{customer | identity: %{schema: "sales", table: "customers"}}

      assert {:ok, forced} =
               SchemaRenderer.render(
                 %{options: []},
                 %{tables: [updated_customer]},
                 %{file.path => user_source},
                 force: true
               )

      source = hd(forced.files).source
      assert source =~ "generated_settings do"
      assert source =~ "@schema_prefix \"sales\""
      assert source =~ "field :display_name, :string, virtual: true"
      assert source =~ "def label(record)"
      refute Enum.any?(forced.diagnostics, &(&1.code == :force_replaced_unowned_file))
    end

    test "repairs duplicate generated regions without discarding user source" do
      customer = hd(model().tables)
      assert {:ok, rendered} = SchemaRenderer.render(%{options: []}, %{tables: [customer]})
      file = hd(rendered.files)

      user_source =
        file.source
        |> String.replace_suffix(
          "  end\nend\n",
          "    field :display_name, :string, virtual: true\n  end\n\n  def label(record), do: record.name\nend\n"
        )

      {:ok, [{:generated_fields, start, finish}]} =
        PgToEcto.Managed.find_regions(user_source, [:generated_fields])

      generated_region = binary_part(user_source, start, finish - start)

      duplicated_source =
        binary_part(user_source, 0, start) <>
          generated_region <>
          "\n\n" <>
          generated_region <>
          binary_part(user_source, finish, byte_size(user_source) - finish)

      assert {:error, diagnostics} =
               SchemaRenderer.render(%{options: []}, %{tables: [customer]}, %{
                 file.path => duplicated_source
               })

      assert Enum.any?(diagnostics, &(&1.code == :invalid_managed_schema))

      assert {:ok, forced} =
               SchemaRenderer.render(
                 %{options: []},
                 %{tables: [customer]},
                 %{file.path => duplicated_source},
                 force: true
               )

      source = hd(forced.files).source
      assert source =~ "field :display_name, :string, virtual: true"
      assert source =~ "def label(record)"
      assert source |> String.split("generated_fields do") |> length() == 2
      assert Enum.any?(forced.diagnostics, &(&1.code == :force_reset_managed_file))
    end

    test "refuses an unowned file and replaces it only with force" do
      customer = hd(model().tables)
      path = customer.file
      source = "defmodule PgToEcto.SchemaRendererTest.Customer do\n  use Ecto.Schema\nend\n"

      assert {:error, diagnostics} =
               SchemaRenderer.render(%{options: []}, %{tables: [customer]}, %{path => source})

      assert Enum.any?(diagnostics, &(&1.code == :unowned_file))

      assert {:ok, forced} =
               SchemaRenderer.render(%{options: []}, %{tables: [customer]}, %{path => source},
                 force: true
               )

      assert hd(forced.files).source =~ "@pg_to_ecto_key"
      assert Enum.any?(forced.diagnostics, &(&1.code == :force_replaced_unowned_file))
    end

    test "refuses a direct user field collision and a changed managed region" do
      assert {:ok, rendered} =
               SchemaRenderer.render(%{options: []}, %{tables: [model().tables |> hd()]})

      file = hd(rendered.files)

      collision_source =
        String.replace(file.source, "  end\nend\n", "  end\n\n  field :active, :boolean\nend\n")

      assert {:error, collision_diagnostics} =
               SchemaRenderer.render(%{options: []}, %{tables: [model().tables |> hd()]}, %{
                 file.path => collision_source
               })

      assert Enum.any?(collision_diagnostics, &(&1.code == :schema_name_collision))

      changed_source =
        String.replace(file.source, "field :active, :boolean", "field :active, :string")

      assert {:error, changed_diagnostics} =
               SchemaRenderer.render(%{options: []}, %{tables: [model().tables |> hd()]}, %{
                 file.path => changed_source
               })

      assert Enum.any?(changed_diagnostics, &(&1.code == :managed_key_mismatch))
    end
  end

  defp model do
    customer = %{
      identity: %{schema: "public", table: "customers"},
      module: Customer,
      file: "lib/pg_to_ecto/schema_renderer_test/customer.ex",
      primary_key: ["id"],
      columns: [
        column("id", :id, %{classification: :none}, :bigserial),
        column("active", :boolean, %{classification: :safe_literal, value: true}),
        column("name", :string, %{classification: :none})
      ],
      foreign_keys: [],
      indexes: []
    }

    order = %{
      identity: %{schema: "public", table: "orders"},
      module: Order,
      file: "lib/pg_to_ecto/schema_renderer_test/order.ex",
      primary_key: ["id"],
      columns: [
        column("id", :id, %{classification: :none}, :bigserial),
        Map.put(
          column("customer_id", :integer, %{classification: :none}, :bigint),
          :nullable,
          false
        )
      ],
      foreign_keys: [
        %{
          name: "orders_customer_id_fkey",
          source_columns: ["customer_id"],
          target_identity: {"public", "customers"},
          target_columns: ["id"],
          selected_target?: true
        }
      ],
      indexes: [
        %{
          name: "orders_customer_id_index",
          unique?: true,
          columns: ["customer_id"],
          mapping_disposition: :exact
        }
      ]
    }

    %{tables: [customer, order]}
  end

  defp column(name, type, default, migration \\ nil) do
    %{name: name, mapping: %{schema: type, migration: migration || type}, default: default}
  end
end
