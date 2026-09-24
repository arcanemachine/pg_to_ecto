defmodule PgToEcto.FileApplicationTest do
  use ExUnit.Case, async: false

  alias PgToEcto.FileApplication

  setup do
    directory = Path.join("test", "tmp_file_application_#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    {:ok, directory: directory}
  end

  test "plans create, update, and unchanged actions", %{directory: directory} do
    create_path = Path.join(directory, "create.ex")
    update_path = Path.join(directory, "update.ex")
    unchanged_path = Path.join(directory, "unchanged.ex")

    File.write!(update_path, "old\n")
    File.write!(unchanged_path, "same\n")

    artifacts = [
      %{path: create_path, source: "new\n"},
      %{path: update_path, source: "new\n"},
      %{path: unchanged_path, source: "same\n"}
    ]

    assert {:ok, changes} = FileApplication.plan(artifacts)
    assert Enum.map(changes, & &1.action) == [:create, :update, :unchanged]
  end

  test "writes changed files through a temporary sibling", %{directory: directory} do
    path = Path.join(directory, "nested/output.ex")
    artifacts = [%{path: path, source: "generated\n"}]

    assert {:ok, [%{action: :create}]} = FileApplication.plan(artifacts)
    assert :ok = FileApplication.write(artifacts, [%{path: path, action: :create}])
    assert File.read!(path) == "generated\n"
    refute Enum.any?(File.ls!(directory), &String.contains?(&1, ".pg_to_ecto_"))
  end

  test "refuses symlinked output files", %{directory: directory} do
    target = Path.join(directory, "target.ex")
    path = Path.join(directory, "link.ex")
    File.write!(target, "outside\n")
    File.ln_s!(target, path)

    assert {:error, diagnostics} = FileApplication.plan([%{path: path, source: "new\n"}])
    assert Enum.any?(diagnostics, &(&1.code == :unsafe_file_path))
    assert File.read!(target) == "outside\n"
  end
end
