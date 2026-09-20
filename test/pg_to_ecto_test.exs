defmodule PgToEctoTest.MigrationRepo do
  def get_dynamic_repo, do: __MODULE__
  def put_dynamic_repo(repo), do: repo
  def config, do: [migration_lock: false, migration_repo: __MODULE__]
  def all(_query, _options), do: []
end

defmodule PgToEctoTest.Customer do
  use Ecto.Schema

  schema "customers" do
    field :name, :string
  end
end

defmodule PgToEctoTest.Widget do
  use Ecto.Schema
  use PgToEcto.Schema

  generated_settings do
    @primary_key false
  end

  schema "widgets" do
    generated_fields do
      field :id, :id, primary_key: true
      field :customer_id, :id

      belongs_to :customer, PgToEctoTest.Customer,
        foreign_key: :customer_id,
        references: :id,
        define_field: false
    end

    field :display_name, :string, virtual: true
  end
end

defmodule PgToEctoTest.Migration do
  use Ecto.Migration
  use PgToEcto.Migration

  def change do
    generated_change do
      create table(:widgets) do
        add :name, :text, null: false
      end
    end
  end
end

defmodule PgToEctoTest do
  use ExUnit.Case, async: true

  test "generated settings and fields compile with associations and user virtual fields" do
    assert PgToEctoTest.Widget.__schema__(:fields) == [:id, :customer_id]
    assert PgToEctoTest.Widget.__schema__(:associations) == [:customer]
    assert PgToEctoTest.Widget.__schema__(:virtual_fields) == [:display_name]
    assert PgToEctoTest.Widget.__schema__(:primary_key) == [:id]
  end

  test "generated migration evaluates through Ecto's runner and queues ordinary commands" do
    assert function_exported?(PgToEctoTest.Migration, :change, 0)

    assert PgToEctoTest.Migration.__migration__() == [
             disable_ddl_transaction: false,
             disable_migration_lock: false
           ]

    {:ok, runner} =
      Ecto.Migration.Runner.start_link({
        self(),
        PgToEctoTest.MigrationRepo,
        [],
        PgToEctoTest.Migration,
        :forward,
        :forward,
        %{level: false, sql: false}
      })

    Ecto.Migration.Runner.metadata(runner, [])
    PgToEctoTest.Migration.change()
    commands = Agent.get(runner, & &1.commands)
    Ecto.Migration.Runner.stop()

    assert [{:create, %Ecto.Migration.Table{name: "widgets"}, _subcommands}] = commands
  end

  test "Ecto orders the numeric Phase 0 migration filename as version one" do
    tmp_dir =
      Path.join(System.tmp_dir!(), "pg_to_ecto_phase0_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    File.write!(Path.join(tmp_dir, "00002_later.exs"), "")
    File.write!(Path.join(tmp_dir, "00001_pg_to_ecto.exs"), "")

    assert [{:down, 1, "pg_to_ecto"}, {:down, 2, "later"}] =
             Ecto.Migrator.migrations(
               PgToEctoTest.MigrationRepo,
               [tmp_dir],
               skip_table_creation: true,
               migration_lock: false
             )
  end

  test "managed keys are stable across formatting and change with semantics or comments" do
    source = "generated_fields do\nfield :name, :string\nend"
    formatted = source |> Code.format_string!() |> IO.iodata_to_binary()

    key = PgToEcto.Managed.key(PgToEctoTest.Widget, %{generated_fields: source})
    formatted_key = PgToEcto.Managed.key(PgToEctoTest.Widget, %{generated_fields: formatted})

    semantic_key =
      PgToEcto.Managed.key(PgToEctoTest.Widget, %{
        generated_fields: "generated_fields do\n  field :count, :integer\nend"
      })

    comment_key =
      PgToEcto.Managed.key(PgToEctoTest.Widget, %{
        generated_fields: "generated_fields do\n  # changed\n  field :name, :string\nend"
      })

    assert key == formatted_key
    refute key == semantic_key
    refute key == comment_key
  end

  test "formatted rendered source validates its embedded key" do
    source = """
    defmodule PgToEctoTest.Rendered do
      use Ecto.Schema
      use PgToEcto.Schema
      @pg_to_ecto_key "pgte1:placeholder"

      generated_settings do
        @primary_key false
      end

      schema "widgets" do
        generated_fields do
          field :name, :string
        end
      end
    end
    """

    formatted = source |> Code.format_string!() |> IO.iodata_to_binary()

    {:ok, key} =
      PgToEcto.Managed.key_for_source(PgToEctoTest.Rendered, formatted, [
        :generated_settings,
        :generated_fields
      ])

    {:ok, rendered} = PgToEcto.Managed.update_key(formatted, key)

    assert PgToEcto.Managed.validate_key(rendered, key) == :ok

    assert {:ok, ^key} =
             PgToEcto.Managed.key_for_source(PgToEctoTest.Rendered, rendered, [
               :generated_settings,
               :generated_fields
             ])
  end

  test "repeated multi-region patches preserve exact user bytes and whitespace" do
    source = """
    defmodule PgToEctoTest.Managed do
      use Ecto.Schema
      use PgToEcto.Schema

      @before_user "before"
      generated_settings do
        @primary_key false
      end

      schema "widgets" do
        generated_fields do
          field :name, :string
        end

        field :display_name, :string, virtual: true
      end

      def user_function, do: @before_user
    end
    """

    {:ok, once} =
      PgToEcto.Managed.patch_regions(source, %{
        generated_settings: "generated_settings do\n  @primary_key false\nend",
        generated_fields:
          "generated_fields do\n  field :name, :string\n  field :count, :integer\nend"
      })

    {:ok, twice} =
      PgToEcto.Managed.patch_regions(once, %{
        generated_settings: "generated_settings do\n  @primary_key false\nend",
        generated_fields:
          "generated_fields do\n  field :name, :string\n  field :count, :integer\nend"
      })

    {:ok, before_regions} =
      PgToEcto.Managed.find_regions(source, [:generated_settings, :generated_fields])

    {:ok, after_regions} =
      PgToEcto.Managed.find_regions(once, [:generated_settings, :generated_fields])

    assert outside_segments(source, before_regions) == outside_segments(once, after_regions)
    assert twice == once
    assert twice =~ "field :display_name, :string, virtual: true"
    assert twice =~ "def user_function, do: @before_user"
    assert {:ok, _ast} = Sourceror.parse_string(twice)
  end

  defp outside_segments(source, regions) do
    boundaries = [{0, 0} | Enum.map(regions, fn {_name, start, finish} -> {start, finish} end)]
    next_boundaries = Enum.drop(boundaries, 1) ++ [{byte_size(source), byte_size(source)}]

    Enum.zip(boundaries, next_boundaries)
    |> Enum.map(fn {{_previous_start, previous_finish}, {next_start, _next_finish}} ->
      binary_part(source, previous_finish, next_start - previous_finish)
    end)
  end

  test "the Phase 0 dependency posture compiles the consumer macros" do
    assert Code.ensure_loaded?(PgToEcto.Schema)
    assert Code.ensure_loaded?(PgToEcto.Migration)
    assert Code.ensure_loaded?(Sourceror)
  end
end
