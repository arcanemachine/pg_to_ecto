defmodule PostgresToEcto.CanonicalTest do
  use ExUnit.Case, async: true

  alias PostgresToEcto.Canonical

  describe "normalize_type/1" do
    test "normalizes Wave 1 type identities and direct mappings" do
      assert Canonical.normalize_type(%{
               type_oid: 23,
               type_schema: "pg_catalog",
               type_name: "int4",
               type_modifier: -1,
               formatted_type: "integer"
             }) == %{
               postgres: %{
                 oid: 23,
                 schema: "pg_catalog",
                 name: "int4",
                 modifier: -1,
                 formatted: "integer"
               },
               schema: :integer,
               migration: :integer,
               disposition: :exact
             }

      assert Canonical.normalize_type(%{
               type_oid: 25,
               type_schema: "pg_catalog",
               type_name: "text",
               type_modifier: -1,
               formatted_type: "text"
             }).schema == :string

      assert Canonical.normalize_type(%{
               type_oid: 999,
               type_schema: "custom",
               type_name: "unknown",
               type_modifier: -1,
               formatted_type: "custom.unknown"
             }).disposition == :blocking
    end

    test "keeps type forms with unsupported baseline semantics blocking" do
      for type_name <- ["int2", "varchar", "bpchar"] do
        assert Canonical.normalize_type(%{
                 type_oid: 1,
                 type_schema: "pg_catalog",
                 type_name: type_name,
                 type_modifier: 12,
                 formatted_type: type_name
               }).disposition == :blocking
      end
    end
  end

  describe "normalize_default/1" do
    test "classifies safe literals separately from database expressions" do
      assert Canonical.normalize_default("true") == %{
               expression: "true",
               classification: :safe_literal,
               value: true,
               type: :boolean
             }

      assert Canonical.normalize_default("-12").value == -12
      assert Canonical.normalize_default("'two''words'::text").value == "two'words"

      assert Canonical.normalize_default("nextval('orders_id_seq'::regclass)").classification ==
               :database_expression

      assert Canonical.normalize_default(nil).classification == :none
    end

    test "classifies quoted defaults according to their explicit PostgreSQL cast" do
      assert Canonical.normalize_default("'1'::integer") == %{
               expression: "'1'::integer",
               classification: :safe_literal,
               value: 1,
               type: :integer
             }

      assert Canonical.normalize_default("'true'::boolean").value == true
      assert Canonical.normalize_default("'1'::text").type == :string
      assert Canonical.normalize_default("'1'::uuid").classification == :database_expression

      assert Canonical.normalize_default("'1'::\"custom\".\"integer\"").classification ==
               :database_expression

      assert Canonical.normalize_default("'1'::\"pg_catalog\".\"integer\"").value == 1
    end
  end

  describe "normalize_action/1" do
    test "normalizes PostgreSQL referential action codes" do
      assert Canonical.normalize_action("c") == :cascade
      assert Canonical.normalize_action("n") == :set_null
      assert Canonical.normalize_action("d") == :set_default
      assert Canonical.normalize_action("r") == :restrict
      assert Canonical.normalize_action("a") == :no_action
    end
  end

  describe "assemble/5" do
    test "assembles ordered columns keys foreign keys and indexes" do
      selected = [%{schema: "public", table: "orders"}, %{schema: "public", table: "customers"}]

      model =
        Canonical.assemble(
          %{server_version: "170000", server_version_num: 17_0000},
          [
            %{
              schema: "public",
              table: "orders",
              relation_kind: "r",
              columns: [
                %{
                  name: "id",
                  position: 1,
                  type_name: "int8",
                  type_schema: "pg_catalog",
                  type_oid: 20,
                  type_modifier: -1,
                  formatted_type: "bigint",
                  not_null: true,
                  default_expression: "nextval('orders_id_seq'::regclass)",
                  serial_kind: :bigserial
                },
                %{
                  name: "customer_id",
                  position: 2,
                  type_name: "int8",
                  type_schema: "pg_catalog",
                  type_oid: 20,
                  type_modifier: -1,
                  formatted_type: "bigint",
                  not_null: true,
                  default_expression: nil,
                  serial_kind: nil
                }
              ]
            },
            %{
              schema: "public",
              table: "customers",
              relation_kind: "r",
              columns: [
                %{
                  name: "id",
                  position: 1,
                  type_name: "int8",
                  type_schema: "pg_catalog",
                  type_oid: 20,
                  type_modifier: -1,
                  formatted_type: "bigint",
                  not_null: true,
                  default_expression: "nextval('customers_id_seq'::regclass)",
                  serial_kind: :bigserial
                }
              ]
            }
          ],
          [
            %{
              kind: :primary_key,
              name: "orders_pkey",
              source_identity: {"public", "orders"},
              source_columns: ["id"]
            },
            %{
              kind: :primary_key,
              name: "customers_pkey",
              source_identity: {"public", "customers"},
              source_columns: ["id"]
            },
            %{
              kind: :foreign_key,
              name: "orders_customer_id_fkey",
              source_identity: {"public", "orders"},
              source_columns: ["customer_id"],
              target_identity: {"public", "customers"},
              target_columns: ["id"],
              update_action: "a",
              delete_action: "c"
            }
          ],
          [
            %{
              name: "orders_customer_id_index",
              source_identity: {"public", "orders"},
              unique?: false,
              columns: ["customer_id"],
              expression?: false,
              partial?: false
            }
          ],
          selected
        )

      [orders, customers] = model.tables
      assert Enum.map(orders.columns, & &1.name) == ["id", "customer_id"]
      assert orders.primary_key == ["id"]

      assert hd(orders.columns).mapping == %{
               schema: :id,
               migration: :bigserial,
               disposition: :exact
             }

      assert [%{delete_action: :cascade, mapping_disposition: :exact}] = orders.foreign_keys
      assert [%{name: "orders_customer_id_index", columns: ["customer_id"]}] = orders.indexes
      assert customers.primary_key == ["id"]
    end

    test "requires an active nextval default before mapping a conventional bigserial" do
      model =
        Canonical.assemble(
          %{},
          [
            %{
              schema: "public",
              table: "stale_sequence",
              relation_kind: "r",
              columns: [
                %{
                  name: "id",
                  position: 1,
                  type_name: "int8",
                  type_schema: "pg_catalog",
                  type_oid: 20,
                  type_modifier: -1,
                  formatted_type: "bigint",
                  not_null: true,
                  default_expression: nil,
                  serial_kind: nil,
                  owned_sequence: "public.stale_sequence_id_seq"
                }
              ]
            }
          ],
          [
            %{
              kind: :primary_key,
              name: "stale_sequence_pkey",
              source_identity: {"public", "stale_sequence"},
              source_columns: ["id"]
            }
          ],
          [],
          [%{schema: "public", table: "stale_sequence"}]
        )

      [column] = hd(model.tables).columns
      assert column.owned_sequence == "public.stale_sequence_id_seq"
      assert column.mapping.disposition == :blocking
      refute column.mapping.migration == :bigserial
    end

    test "blocks identity columns without misclassifying them as bigserial" do
      model =
        Canonical.assemble(
          %{},
          [
            %{
              schema: "public",
              table: "identity_table",
              relation_kind: "r",
              columns: [
                %{
                  name: "id",
                  position: 1,
                  type_name: "int8",
                  type_schema: "pg_catalog",
                  type_oid: 20,
                  type_modifier: -1,
                  formatted_type: "bigint",
                  not_null: true,
                  default_expression: nil,
                  serial_kind: :bigserial,
                  identity_kind: "a"
                }
              ]
            }
          ],
          [
            %{
              kind: :primary_key,
              name: "identity_table_pkey",
              source_identity: {"public", "identity_table"},
              source_columns: ["id"]
            }
          ],
          [],
          [%{schema: "public", table: "identity_table"}]
        )

      [column] = hd(model.tables).columns
      assert column.identity == :always
      assert column.identity_code == "a"
      assert column.mapping.disposition == :blocking
      refute column.mapping.migration == :bigserial
    end

    test "retains an unselected foreign key target identity with an omission disposition" do
      model =
        Canonical.assemble(
          %{},
          [
            %{schema: "public", table: "orders", relation_kind: "r", columns: []}
          ],
          [
            %{
              kind: :foreign_key,
              name: "orders_audit_event_id_fkey",
              source_identity: {"public", "orders"},
              source_columns: ["audit_event_id"],
              target_identity: {"internal", "audit_events"},
              target_columns: ["id"],
              update_action: "a",
              delete_action: "n"
            }
          ],
          [],
          [%{schema: "public", table: "orders"}]
        )

      [foreign_key] = hd(model.tables).foreign_keys
      assert foreign_key.target_identity == {"internal", "audit_events"}
      assert foreign_key.mapping_disposition == :omitted_with_warning
      refute foreign_key.selected_target?
    end
  end
end
