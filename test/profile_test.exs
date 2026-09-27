defmodule PostgresToEctoProfileTest.Repo do
  def config do
    [
      migration_default_prefix: "tenant",
      priv: Application.get_env(:postgres_to_ecto_profile_test, :priv, "priv/repo")
    ]
  end
end

defmodule PostgresToEctoProfileTest.Order do
end

defmodule PostgresToEctoProfileTest.Invoice do
end

defmodule PostgresToEctoProfileTest.Customer do
end

defmodule PostgresToEctoProfileTest.OrderDuplicate do
end

defmodule PostgresToEctoProfileTest.OrderedProfile do
  use PostgresToEcto.Generator, show_generated_key_comment: false

  repo(PostgresToEctoProfileTest.Repo)

  table("first", module: PostgresToEctoProfileTest.Order)
  table("sales.second", module: PostgresToEctoProfileTest.Invoice)
end

defmodule PostgresToEctoProfileTest.DuplicateProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)

  table("orders", module: PostgresToEctoProfileTest.Order)
  table("tenant.orders", module: PostgresToEctoProfileTest.OrderDuplicate)
  table("customers", module: PostgresToEctoProfileTest.Order)
end

defmodule PostgresToEctoProfileTest.InvalidNameProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)

  table("", module: PostgresToEctoProfileTest.Order)
  table("too.many.parts", module: PostgresToEctoProfileTest.Invoice)
end

defmodule PostgresToEctoProfileTest.InvalidPathProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)

  table("orders", module: PostgresToEctoProfileTest.Order, file: "../outside/order.ex")
  table("invoices", module: PostgresToEctoProfileTest.Invoice, file: "/tmp/invoice.ex")
end

defmodule PostgresToEctoProfileTest.MissingRepoProfile do
  use PostgresToEcto.Generator

  table("orders", module: PostgresToEctoProfileTest.Order)
end

defmodule PostgresToEctoProfileTest.EmptySelectionProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)
end

defmodule PostgresToEctoProfileTest.RaisingRepo do
  def config, do: raise("broken Repo config")
end

defmodule PostgresToEctoProfileTest.RaisingRepoProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.RaisingRepo)
  table("orders", module: PostgresToEctoProfileTest.Order)
end

defmodule PostgresToEctoProfileTest.DuplicateMigrationProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)
  migration_basename("00001_first.exs")
  migration_basename("00002_second.exs")
  table("orders", module: PostgresToEctoProfileTest.Order)
end

defmodule PostgresToEctoProfileTest.InvalidMigrationProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)
  migration_basename("invalid.exs")
  table("orders", module: PostgresToEctoProfileTest.Order)
end

defmodule PostgresToEctoProfileTest.MigrationProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)
  table("orders", module: PostgresToEctoProfileTest.Order)
end

defmodule PostgresToEctoProfileTest.QuotedNameProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)
  table("legacy-orders", module: PostgresToEctoProfileTest.Order)
  table("\"sales.orders\"", module: PostgresToEctoProfileTest.Invoice)
  table("\"sales\".\"orders\"", module: PostgresToEctoProfileTest.Customer)
end

defmodule PostgresToEctoProfileTest.CustomMigrationProfile do
  use PostgresToEcto.Generator

  repo(PostgresToEctoProfileTest.Repo)
  migration_basename("00002_custom.exs")
  table("orders", module: PostgresToEctoProfileTest.Order)
end

defmodule PostgresToEctoProfileTest do
  use ExUnit.Case, async: false

  alias PostgresToEcto.{Diagnostic, Profile}

  test "preserves declaration order and normalizes unqualified table names" do
    profile = Profile.load(PostgresToEctoProfileTest.OrderedProfile)

    assert {:ok, raw_profile} = profile
    assert Enum.map(raw_profile.tables, & &1.name) == ["first", "sales.second"]

    assert {:ok, validated, []} = Profile.validate(PostgresToEctoProfileTest.OrderedProfile)

    assert Enum.map(validated.tables, &{&1.schema, &1.table}) == [
             {"tenant", "first"},
             {"sales", "second"}
           ]

    assert validated.options == [show_generated_key_comment: false]
  end

  test "reports duplicate table and module declarations" do
    assert {:error, %PostgresToEcto.Result{diagnostics: diagnostics}} =
             PostgresToEcto.generate(PostgresToEctoProfileTest.DuplicateProfile, dry_run: true)

    assert Enum.any?(diagnostics, &match?(%Diagnostic{code: :duplicate_table_declaration}, &1))
    assert Enum.any?(diagnostics, &match?(%Diagnostic{code: :duplicate_module_declaration}, &1))
  end

  test "reports malformed table qualification" do
    assert {:error, %PostgresToEcto.Result{diagnostics: diagnostics}} =
             PostgresToEcto.generate(PostgresToEctoProfileTest.InvalidNameProfile, dry_run: true)

    assert_error(diagnostics, :invalid_table_name, "nonempty")
    assert Enum.count(diagnostics, &(&1.code == :invalid_table_name)) == 2
  end

  test "accepts ordinary and quoted PostgreSQL identifier text" do
    assert {:ok, validated, []} = Profile.validate(PostgresToEctoProfileTest.QuotedNameProfile)

    assert Enum.map(validated.tables, &{&1.schema, &1.table}) == [
             {"tenant", "legacy-orders"},
             {"tenant", "sales.orders"},
             {"sales", "orders"}
           ]
  end

  test "rejects absolute and escaping schema output paths" do
    assert {:error, %PostgresToEcto.Result{diagnostics: diagnostics}} =
             PostgresToEcto.generate(PostgresToEctoProfileTest.InvalidPathProfile, dry_run: true)

    assert Enum.count(diagnostics, &(&1.code == :invalid_output_path)) == 2
  end

  test "requires an explicit profile in the public API" do
    assert {:error, %PostgresToEcto.Result{diagnostics: diagnostics}} =
             PostgresToEcto.generate(nil, dry_run: true)

    assert_error(diagnostics, :invalid_profile, "explicit generator profile")
  end

  test "loads the configured default profile through the internal loader" do
    previous = Application.get_env(:postgres_to_ecto, :generator)
    Application.put_env(:postgres_to_ecto, :generator, PostgresToEctoProfileTest.OrderedProfile)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:postgres_to_ecto, :generator)
      else
        Application.put_env(:postgres_to_ecto, :generator, previous)
      end
    end)

    assert {:ok, raw_profile} = Profile.load(nil)
    assert raw_profile.module == PostgresToEctoProfileTest.OrderedProfile
  end

  test "reports missing default profile configuration internally" do
    previous = Application.get_env(:postgres_to_ecto, :generator)
    Application.delete_env(:postgres_to_ecto, :generator)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:postgres_to_ecto, :generator)
      else
        Application.put_env(:postgres_to_ecto, :generator, previous)
      end
    end)

    assert {:error, diagnostics} = Profile.load(nil)
    assert_error(diagnostics, :missing_profile, "config :postgres_to_ecto")
  end

  test "accepts a custom migration basename" do
    assert {:ok, validated, []} =
             Profile.validate(PostgresToEctoProfileTest.CustomMigrationProfile)

    assert validated.migration_filename == "00002_custom.exs"
  end

  test "reports invalid and duplicate migration basenames" do
    assert {:error, invalid_diagnostics} =
             PostgresToEcto.Profile.validate(PostgresToEctoProfileTest.InvalidMigrationProfile)

    assert_error(invalid_diagnostics, :invalid_migration_filename, "must match")

    assert {:error, duplicate_diagnostics} =
             PostgresToEcto.Profile.validate(PostgresToEctoProfileTest.DuplicateMigrationProfile)

    assert_error(duplicate_diagnostics, :duplicate_migration_filename, "only one")
  end

  test "reports missing Repo and empty table selection" do
    assert {:error, missing_repo_diagnostics} =
             PostgresToEcto.Profile.validate(PostgresToEctoProfileTest.MissingRepoProfile)

    assert_error(missing_repo_diagnostics, :missing_repo, "one Repo")

    assert {:error, missing_tables_diagnostics} =
             PostgresToEcto.Profile.validate(PostgresToEctoProfileTest.EmptySelectionProfile)

    assert_error(missing_tables_diagnostics, :missing_tables, "at least one table")
  end

  test "reports Repo configuration errors" do
    assert {:error, diagnostics} =
             PostgresToEcto.Profile.validate(PostgresToEctoProfileTest.RaisingRepoProfile)

    assert_error(diagnostics, :repo_config_error, "broken Repo config")
  end

  test "reports malformed generation options without raising" do
    assert {:error, %PostgresToEcto.Result{diagnostics: diagnostics}} =
             PostgresToEcto.generate(PostgresToEctoProfileTest.OrderedProfile, [:not_a_keyword])

    assert_error(diagnostics, :invalid_generation_option, "keyword list")
  end

  test "reports migration version collisions" do
    relative_path = "test/tmp_postgres_to_ecto_migrations_#{System.unique_integer([:positive])}"
    absolute_path = Path.join(File.cwd!(), relative_path)
    migration_directory = Path.join(absolute_path, "migrations")
    File.mkdir_p!(migration_directory)
    File.write!(Path.join(migration_directory, "1_existing.exs"), "")

    Application.put_env(:postgres_to_ecto_profile_test, :priv, relative_path)

    on_exit(fn ->
      Application.delete_env(:postgres_to_ecto_profile_test, :priv)
      File.rm_rf!(absolute_path)
    end)

    assert {:error, %PostgresToEcto.Result{diagnostics: diagnostics}} =
             PostgresToEcto.generate(PostgresToEctoProfileTest.MigrationProfile, dry_run: true)

    assert Enum.any?(diagnostics, &match?(%Diagnostic{code: :migration_version_conflict}, &1))
  end

  test "accepts dry-run and force options without writing files" do
    profile_path = Path.join(File.cwd!(), "lib/postgres_to_ecto_profile_test/order.ex")
    refute File.exists?(profile_path)

    assert {:error,
            %PostgresToEcto.Result{
              files: [],
              diagnostics: diagnostics
            }} =
             PostgresToEcto.generate(PostgresToEctoProfileTest.OrderedProfile,
               dry_run: true,
               force: true
             )

    assert Enum.any?(diagnostics, &(&1.code == :repo_unavailable))
    refute File.exists?(profile_path)
  end

  defp assert_error(diagnostics, code, message_fragment) do
    assert Enum.any?(diagnostics, fn
             %Diagnostic{severity: :error, code: ^code, message: message} ->
               String.contains?(message, message_fragment)

             _diagnostic ->
               false
           end)
  end
end
