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
end
