defmodule PostgresToEcto.ManagedTest do
  use ExUnit.Case, async: true

  alias PostgresToEcto.Managed

  defmodule Owner do
  end

  test "accepts only valid versioned digest keys" do
    key = Managed.key(Owner, %{generated_fields: "generated_fields do\nend"})

    assert Managed.valid_key?(key)
    refute Managed.valid_key?("pgte2:unknown")
    refute Managed.valid_key?("postgreste1:not-a-digest")
  end

  test "rejects duplicate and malformed embedded keys" do
    source = """
    defmodule PostgresToEcto.ManagedTest.Owner do
      use Ecto.Schema
      @postgres_to_ecto_key "postgreste1:bad"
      @postgres_to_ecto_key "pgte2:bad"
    end
    """

    assert Managed.extract_key(source) == {:error, :invalid_key}
  end

  test "removes a malformed attribute before inserting a recovered key" do
    key = Managed.key(Owner, %{generated_fields: "generated_fields do\nend"})

    source = """
    defmodule PostgresToEcto.ManagedTest.Owner do
      use Ecto.Schema
      @postgres_to_ecto_key :bad
      generated_fields do
      end
    end
    """

    assert {:ok, updated} = Managed.update_key(source, key)
    assert Managed.extract_key(updated) == {:ok, key}
    refute updated =~ "@postgres_to_ecto_key :bad"
  end

  test "removes malformed attributes alongside a valid key line" do
    key = Managed.key(Owner, %{generated_fields: "generated_fields do\nend"})

    source = """
    defmodule PostgresToEcto.ManagedTest.Owner do
      use Ecto.Schema
      @postgres_to_ecto_key "#{key}"
      @postgres_to_ecto_key :bad
      generated_fields do
      end
    end
    """

    assert {:ok, updated} = Managed.update_key(source, key)
    assert Managed.extract_key(updated) == {:ok, key}
    refute updated =~ "@postgres_to_ecto_key :bad"
  end

  test "updates a malformed key without leaving duplicate attributes" do
    key = Managed.key(Owner, %{generated_fields: "generated_fields do\nend"})

    source = """
    defmodule PostgresToEcto.ManagedTest.Owner do
      use Ecto.Schema
      @postgres_to_ecto_key "pgte2:bad"
      @postgres_to_ecto_key "postgreste1:bad"
      generated_fields do
      end
    end
    """

    assert {:ok, updated} = Managed.update_key(source, key)
    assert Managed.extract_key(updated) == {:ok, key}
    assert updated =~ "  @postgres_to_ecto_key"
    refute updated =~ "pgte2:bad"
  end

  test "mechanically renames an old managed source without changing user source" do
    source = """
    defmodule PostgresToEcto.ManagedTest.Renamed do
      use Ecto.Schema
      use PostgresToEcto.Schema

      @user_before "preserve-before"
      @postgres_to_ecto_key "postgreste1:placeholder"

      generated_fields do
        field :name, :string
      end

      field :display_name, :string, virtual: true

      def user_function(record), do: {record, @user_before}
    end
    """

    {:ok, new_key} = Managed.key_for_source(__MODULE__.Renamed, source, [:generated_fields])
    {:ok, new_source} = Managed.update_key(source, new_key)

    old_source =
      new_source
      |> String.replace("PostgresToEcto.Schema", "PgToEcto.Schema")
      |> String.replace("@postgres_to_ecto_key", "@pg_to_ecto_key")
      |> String.replace("postgreste1:", "pgte1:")

    old_key = String.replace(new_key, "postgreste1:", "pgte1:")
    assert String.starts_with?(old_key, "pgte1:")
    assert {:ok, _ast} = Sourceror.parse_string(old_source)
    refute Managed.valid_key?(old_key)
    assert Managed.extract_key(old_source) == :missing

    renamed_source =
      old_source
      |> String.replace("PgToEcto.Schema", "PostgresToEcto.Schema")
      |> String.replace("@pg_to_ecto_key", "@postgres_to_ecto_key")
      |> String.replace("pgte1:", "postgreste1:")

    assert {:ok, _ast} = Sourceror.parse_string(renamed_source)
    assert Managed.validate_key(renamed_source, new_key) == :ok
    assert renamed_source =~ "@user_before \"preserve-before\""
    assert renamed_source =~ "field :display_name, :string, virtual: true"
    assert renamed_source =~ "def user_function(record), do: {record, @user_before}"

    {:ok, old_regions} = Managed.find_regions(old_source, [:generated_fields])
    {:ok, new_regions} = Managed.find_regions(renamed_source, [:generated_fields])

    assert user_source_segments(old_source, old_regions) ==
             user_source_segments(renamed_source, new_regions)
  end

  defp user_source_segments(source, regions) do
    normalized_source =
      source
      |> String.replace(~r/^\s*use\s+(?:PgToEcto|PostgresToEcto)\.Schema\s*\n/m, "")
      |> String.replace(~r/^\s*@(?:pg_to_ecto|postgres_to_ecto)_key\s+[^\n]+\n/m, "")

    {:ok, normalized_regions} =
      Managed.find_regions(normalized_source, Enum.map(regions, &elem(&1, 0)))

    outside_regions(normalized_source, normalized_regions)
  end

  defp outside_regions(source, regions) do
    regions = Enum.map(regions, fn {_name, start, finish} -> {start, finish} end)

    {segments, offset} =
      Enum.reduce(regions, {[], 0}, fn {start, finish}, {segments, offset} ->
        {[binary_part(source, offset, start - offset) | segments], finish}
      end)

    Enum.reverse([binary_part(source, offset, byte_size(source) - offset) | segments])
  end
end
