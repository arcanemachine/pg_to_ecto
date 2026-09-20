defmodule PgToEcto.IntrospectionTest do
  use ExUnit.Case, async: true

  alias PgToEcto.Introspection

  describe "introspect/2" do
    test "reports an unavailable configured Repo without starting one" do
      assert {:error, {:repo_unavailable, __MODULE__.UnavailableRepo}} =
               Introspection.introspect(__MODULE__.UnavailableRepo, [])
    end
  end

  describe "resolve_table/2" do
    test "resolves qualified and unqualified selections without search path state" do
      assert {:ok, %{schema: "tenant", table: "orders"}} =
               Introspection.resolve_table("orders", "tenant")

      assert {:ok, %{schema: "public", table: "orders"}} =
               Introspection.resolve_table("orders", "public")

      assert {:ok, %{schema: "public", table: "orders"}} =
               Introspection.resolve_table("orders", nil)

      assert {:ok, %{schema: "sales", table: "orders"}} =
               Introspection.resolve_table("sales.orders", "tenant")
    end
  end

  describe "normalize_catalog_result/1" do
    test "normalizes catalog result rows into predictable keys" do
      result = %Postgrex.Result{
        columns: ["schema", "table", "position", "identity_kind", "owned_sequence"],
        rows: [["public", "orders", 1, "", "public.orders_id_seq"]]
      }

      assert Introspection.normalize_catalog_result(result) == [
               %{
                 schema: "public",
                 table: "orders",
                 position: 1,
                 identity_kind: "",
                 owned_sequence: "public.orders_id_seq"
               }
             ]
    end
  end
end
