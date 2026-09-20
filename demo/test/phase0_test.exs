defmodule PgToEctoDemo.Phase0Test do
  use ExUnit.Case, async: true

  test "consumer schema macros compile and preserve virtual fields" do
    assert PgToEctoDemo.Widget.__schema__(:fields) == [:id, :name]
    assert PgToEctoDemo.Widget.__schema__(:virtual_fields) == [:display_name]
  end

  test "consumer migration module compiles" do
    assert Code.ensure_loaded?(PgToEctoDemo.Repo.Migrations.Phase0)
    assert function_exported?(PgToEctoDemo.Repo.Migrations.Phase0, :change, 0)
  end
end
