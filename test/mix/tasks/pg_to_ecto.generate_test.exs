defmodule Mix.Tasks.PgToEcto.GenerateTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.PgToEcto.Generate

  defmodule VerboseRepo do
    def config, do: []
  end

  defmodule VerboseProfile do
    use PgToEcto.Generator

    repo(VerboseRepo)
    table("widgets", module: VerboseWidget)
  end

  defmodule VerboseWidget do
  end

  setup do
    Mix.Task.clear()
    previous = Application.get_env(:pg_to_ecto, :generator)
    Application.delete_env(:pg_to_ecto, :generator)

    on_exit(fn ->
      Mix.Task.clear()

      if is_nil(previous) do
        Application.delete_env(:pg_to_ecto, :generator)
      else
        Application.put_env(:pg_to_ecto, :generator, previous)
      end
    end)

    :ok
  end

  test "shows task help without starting the application" do
    output = capture_io(fn -> assert :ok = Generate.run(["--help"]) end)

    assert output =~ "mix pg_to_ecto.generate [PROFILE]"
    assert output =~ "--dry-run"
    assert output =~ "--force"
  end

  test "reports missing profile configuration with guidance" do
    output =
      capture_io(:stderr, fn ->
        assert_raise Mix.Error, ~r/could not load the generator profile/, fn ->
          Generate.run([])
        end
      end)

    assert output =~ "No PgToEcto generator profile is configured"
    assert output =~ "config :pg_to_ecto, generator: MyApp.PgToEcto"
  end

  test "force write failures do not claim planned updates during preflight" do
    change = %PgToEcto.FileChange{path: "lib/widget.ex", action: :update}

    warning = %PgToEcto.Diagnostic{
      severity: :warning,
      code: :force_reset,
      message: "force reset lib/widget.ex"
    }

    error = %PgToEcto.Diagnostic{
      severity: :error,
      code: :file_write_error,
      message: "write failed"
    }

    output =
      capture_io(fn ->
        assert {:error, %PgToEcto.Result{diagnostics: [^error]}} =
                 Generate.force_generation(
                   fn -> {:ok, %PgToEcto.Result{files: [change], diagnostics: [warning]}} end,
                   fn -> {:error, %PgToEcto.Result{files: [change], diagnostics: [error]}} end,
                   dry_run: true
                 )
      end)

    assert output =~ "would update lib/widget.ex"
    refute output =~ "updated lib/widget.ex"

    assert output =~ "force reset lib/widget.ex"
    refute output =~ "write failed"
  end

  test "force errors do not claim planned files were written" do
    output =
      capture_generation_error(["--force", "Mix.Tasks.PgToEcto.GenerateTest.VerboseProfile"])

    assert output =~ "not running"
    refute output =~ "updated "
  end

  test "reports when no files require changes" do
    output =
      capture_io(fn ->
        assert {:ok, %PgToEcto.Result{}} =
                 Generate.force_generation(
                   fn ->
                     {:ok,
                      %PgToEcto.Result{
                        files: [%PgToEcto.FileChange{path: "lib/widget.ex", action: :unchanged}],
                        diagnostics: []
                      }}
                   end,
                   fn -> {:ok, %PgToEcto.Result{files: [], diagnostics: []}} end,
                   dry_run: true
                 )
      end)

    assert output == "No changes required.\n"
  end

  test "prints safe context only in verbose mode" do
    normal = capture_generation_error(["Mix.Tasks.PgToEcto.GenerateTest.VerboseProfile"])
    Mix.Task.clear()

    verbose =
      capture_generation_error([
        "--verbose",
        "Mix.Tasks.PgToEcto.GenerateTest.VerboseProfile"
      ])

    refute normal =~ "verbose:"
    assert verbose =~ "verbose: profile Mix.Tasks.PgToEcto.GenerateTest.VerboseProfile"
    assert verbose =~ "verbose: Repo Mix.Tasks.PgToEcto.GenerateTest.VerboseRepo"
    assert verbose =~ "verbose: selected tables 1"
    refute verbose =~ "password"
  end

  test "rejects an invalid profile module before generation" do
    assert_raise Mix.Error, ~r/could not load the generator profile/, fn ->
      capture_io(fn -> Generate.run(["not-a-module"]) end)
    end
  end

  defp capture_generation_error(arguments) do
    parent = self()

    stderr =
      capture_io(:stderr, fn ->
        stdout =
          capture_io(fn ->
            assert_raise Mix.Error, ~r/generation failed/, fn ->
              Generate.run(arguments)
            end
          end)

        send(parent, {:captured_stdout, stdout})
      end)

    receive do
      {:captured_stdout, stdout} -> stdout <> stderr
    end
  end
end
