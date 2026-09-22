defmodule PgToEcto.SchemaRendererTest do
  use ExUnit.Case, async: true

  alias PgToEcto.SchemaRenderer

  defmodule Customer do
  end

  defmodule Order do
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
