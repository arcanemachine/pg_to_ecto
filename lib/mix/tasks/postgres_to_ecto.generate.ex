defmodule Mix.Tasks.PostgresToEcto.Generate do
  @shortdoc "Generate Ecto schemas and a baseline migration from PostgreSQL"
  @moduledoc """
  Generates PostgresToEcto-managed schemas and a baseline migration.

  The task reads the configured default profile unless a profile module is
  passed as an argument or with `--profile`.
  """

  use Mix.Task

  alias PostgresToEcto.{Diagnostic, Profile, Result}

  @switches [
    dry_run: :boolean,
    force: :boolean,
    verbose: :boolean,
    profile: :string,
    help: :boolean
  ]
  @aliases [d: :dry_run, f: :force, h: :help, p: :profile, v: :verbose]

  @impl Mix.Task
  def run(args) do
    {options, arguments, invalid} =
      OptionParser.parse(args, switches: @switches, aliases: @aliases)

    cond do
      options[:help] -> print_help()
      invalid != [] -> invalid_options(invalid)
      length(arguments) > 1 -> Mix.raise("Expected at most one profile module.")
      true -> run_generation(options, arguments)
    end
  end

  defp run_generation(options, arguments) do
    Mix.Task.run("app.start")

    with {:ok, profile_module} <- profile_module(arguments, options),
         {:ok, profile, _profile_diagnostics} <- Profile.validate(profile_module) do
      print_verbose_context(profile, options)

      case generate_task_result(profile, profile_module, options) do
        {:ok, result} ->
          if Keyword.get(options, :force, false) and not Keyword.get(options, :dry_run, false) do
            print_changes(result.files, false)
          else
            print_result(result, options)
          end

          if has_errors?(result.diagnostics),
            do: Mix.raise("PostgresToEcto generation failed."),
            else: :ok

        {:error, %Result{} = result} ->
          print_diagnostics(result.diagnostics, options)
          Mix.raise("PostgresToEcto generation failed.")

        {:error, diagnostic} ->
          print_diagnostics([diagnostic], options)
          Mix.raise("PostgresToEcto could not start the configured Repo.")
      end
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        print_diagnostics(diagnostics, options)
        Mix.raise("PostgresToEcto could not load the generator profile.")

      {:error, diagnostic} ->
        print_diagnostics([diagnostic], options)
        Mix.raise("PostgresToEcto could not start the configured Repo.")
    end
  end

  defp profile_module(arguments, options) do
    configured = Keyword.get(options, :profile)
    positional = List.first(arguments)

    cond do
      configured && positional ->
        {:error,
         [
           diagnostic(
             :error,
             :duplicate_profile,
             "Pass a profile module either as an argument or with --profile, not both."
           )
         ]}

      configured ->
        parse_module(configured)

      positional ->
        parse_module(positional)

      true ->
        case Profile.load(nil) do
          {:ok, raw_profile} -> {:ok, raw_profile.module}
          {:error, diagnostics} -> {:error, diagnostics}
        end
    end
  end

  defp parse_module(value) when is_binary(value) do
    value = String.trim_leading(value, "Elixir.")
    parts = String.split(value, ".", trim: true)

    if parts != [] and Enum.all?(parts, &Regex.match?(~r/^[A-Z][A-Za-z0-9_]*$/, &1)) do
      {:ok, Module.concat(parts)}
    else
      {:error,
       [
         diagnostic(
           :error,
           :invalid_profile,
           "Profile module #{inspect(value)} must be a qualified module name such as MyApp.PostgresToEcto."
         )
       ]}
    end
  end

  defp parse_module(_value),
    do:
      {:error,
       [diagnostic(:error, :invalid_profile, "Profile module must be a qualified module name.")]}

  defp generate_task_result(profile, profile_module, options) do
    if Keyword.get(options, :force, false) and not Keyword.get(options, :dry_run, false) do
      preflight_options = Keyword.put(options, :dry_run, true)

      force_generation(
        fn -> generate_with_repo(profile, profile_module, preflight_options) end,
        fn -> generate_with_repo(profile, profile_module, options) end,
        preflight_options
      )
    else
      generate_with_repo(profile, profile_module, options)
    end
  end

  @doc false
  def force_generation(preflight_fun, write_fun, preflight_options)
      when is_function(preflight_fun, 0) and is_function(write_fun, 0) do
    case preflight_fun.() do
      {:ok, preflight} ->
        print_result(preflight, preflight_options)

        if has_errors?(preflight.diagnostics),
          do: {:error, preflight},
          else: write_fun.()

      {:error, %Result{} = preflight} ->
        {:error, preflight}

      {:error, diagnostic} ->
        {:error, diagnostic}
    end
  end

  defp generate_with_repo(profile, profile_module, options) do
    generation_options = [
      dry_run: Keyword.get(options, :dry_run, false),
      force: Keyword.get(options, :force, false)
    ]

    with_repo(profile.repo, fn ->
      PostgresToEcto.generate(profile_module, generation_options)
    end)
  end

  defp with_repo(repo, function) do
    if repo_running?(repo) do
      function.()
    else
      start_temporary_repo(repo, function)
    end
  end

  defp repo_running?(repo) do
    repo in Ecto.Repo.all_running()
  rescue
    _ -> false
  end

  defp start_temporary_repo(repo, function) do
    if function_exported?(repo, :start_link, 0) do
      case repo.start_link() do
        {:ok, pid} ->
          try do
            function.()
          after
            if Process.alive?(pid), do: Supervisor.stop(pid)
          end

        {:error, {:already_started, _pid}} ->
          function.()

        {:error, reason} ->
          {:error,
           diagnostic(
             :error,
             :repo_unavailable,
             "The configured Repo #{inspect(repo)} could not be started: #{inspect(reason)}."
           )}
      end
    else
      function.()
    end
  end

  defp print_result(%Result{files: files, diagnostics: diagnostics}, options) do
    print_diagnostics(diagnostics, options)
    print_changes(files, Keyword.get(options, :dry_run, false))
  end

  defp print_changes(files, dry_run?) do
    changed_files = Enum.reject(files, &(&1.action == :unchanged))

    if changed_files == [] do
      Mix.shell().info([:green, "No changes required.", :reset])
    else
      Enum.each(changed_files, fn %{path: path, action: action} ->
        {label, color} = action_label(action, dry_run?)
        Mix.shell().info([color, label, :reset, " ", path])
      end)
    end
  end

  defp print_verbose_context(profile, options) do
    if Keyword.get(options, :verbose, false) do
      IO.puts("verbose: profile #{inspect(profile.module)}")
      IO.puts("verbose: Repo #{inspect(profile.repo)}")
      IO.puts("verbose: selected tables #{length(profile.tables)}")
      IO.puts("verbose: migration file #{profile.migration_file}")
    end
  end

  defp print_diagnostics(diagnostics, options) do
    if Keyword.get(options, :verbose, false) or diagnostics != [] do
      Enum.each(diagnostics, &print_diagnostic/1)
    end
  end

  defp print_diagnostic(%Diagnostic{severity: :warning, message: message}) do
    Mix.shell().info([:yellow, "warning: ", :reset, message])
  end

  defp print_diagnostic(%Diagnostic{severity: :error, message: message}) do
    Mix.shell().error(["error: ", message])
  end

  defp print_diagnostic(%Diagnostic{severity: severity, message: message}) do
    Mix.shell().info(["#{severity}: ", message])
  end

  defp action_label(:create, true), do: {"would create", :green}
  defp action_label(:update, true), do: {"would update", :yellow}
  defp action_label(:blocked, true), do: {"would block", :red}
  defp action_label(:create, false), do: {"created", :green}
  defp action_label(:update, false), do: {"updated", :yellow}
  defp action_label(:blocked, false), do: {"blocked", :red}

  defp print_help do
    IO.puts("""
    mix postgres_to_ecto.generate [PROFILE] [options]

    Options:
      --profile MODULE  Use MODULE instead of the configured default profile
      --dry-run         Render and summarize changes without writing files
      --force           Replace unmanaged files or reset managed regions
      --verbose         Print safe profile, Repo, table-count, and migration context
      -h, --help        Show this help
    """)
  end

  defp invalid_options(invalid) do
    names = Enum.map_join(invalid, ", ", fn {name, value} -> "#{name}=#{inspect(value)}" end)
    Mix.raise("Invalid option(s): #{names}")
  end

  defp has_errors?(diagnostics), do: Enum.any?(diagnostics, &(&1.severity == :error))

  defp diagnostic(severity, code, message),
    do: %Diagnostic{severity: severity, code: code, message: message}
end
